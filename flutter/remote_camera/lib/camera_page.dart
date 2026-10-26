import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'addresses.dart';
import 'app_model.dart';
import 'camera_server.dart';
import 'camera_settings_page.dart';
import 'frame_encoder.dart';
import 'l10n.dart';
import 'mjpeg.dart';
import 'native_bridge.dart';
import 'phone_pose.dart';
import 'widgets.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key, required this.model});

  final AppModel model;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  late final CameraServer _server;
  CameraController? _camera;
  Timer? _addressTimer;
  StreamSubscription<AccelerometerEvent>? _sensors;
  List<String> _addresses = [];
  bool _busy = false;
  bool _serving = false;
  bool _encoding = false;
  bool _haveSensor = false;
  String _error = '';
  DateTime _lastEncode = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _fpsStamp = DateTime.now();
  int _frameCount = 0;
  double _fps = 0;
  int _sensedDegrees = 0;
  int? _pendingDegrees;
  DateTime? _pendingSince;

  @override
  void initState() {
    super.initState();
    _server = CameraServer(
      token: () => widget.model.serverToken.trim(),
      devices: () => widget.model.devices,
    );
    _refreshAddresses();
    _addressTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshAddresses();
    });
    _sensors = accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen(
      _onAcceleration,
      onError: (Object _) {},
    );
    widget.model.addListener(_onModel);
  }

  @override
  void dispose() {
    widget.model.removeListener(_onModel);
    _addressTimer?.cancel();
    unawaited(_sensors?.cancel());
    unawaited(_stop());
    super.dispose();
  }

  void _onModel() {
    if (mounted) setState(() {});
  }

  void _onAcceleration(AccelerometerEvent event) {
    final degrees = degreesFromAcceleration(event.x, event.y);
    if (degrees == null) return;
    if (degrees == _sensedDegrees && _haveSensor) {
      _pendingDegrees = null;
      return;
    }
    final now = DateTime.now();
    if (_pendingDegrees != degrees) {
      _pendingDegrees = degrees;
      _pendingSince = now;
      return;
    }
    final since = _pendingSince;
    if (since != null && now.difference(since) >= const Duration(milliseconds: 300)) {
      _sensedDegrees = degrees;
      _haveSensor = true;
      _pendingDegrees = null;
      if (mounted) setState(() {});
    }
  }

  int _deviceDegrees() {
    return deviceDegreesFor(
      mode: widget.model.orientationMode,
      sensedDegrees: _sensedDegrees,
      haveSensor: _haveSensor,
    );
  }

  Future<void> _refreshAddresses() async {
    try {
      final addresses = await localIpv4();
      if (!mounted) return;
      setState(() => _addresses = addresses);
    } on Object {
      // A missing interface list still leaves the port and token usable.
    }
  }

  Future<void> _start() async {
    if (_serving || _busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    try {
      final cameraPermission = await Permission.camera.request();
      if (!cameraPermission.isGranted) {
        throw StateError(tr(context).needCameraPermission);
      }
      await Permission.notification.request();
      final foreground = await NativeBridge.startForeground(
        title: tr(context).notifyTitle,
        text: tr(context).notifyText,
      );
      if (!foreground) {
        throw StateError(tr(context).foregroundFailed);
      }
      await WakelockPlus.enable();
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError(tr(context).noCamera);
      }
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _camera = controller;
      await controller.initialize();
      await controller.startImageStream(_onImage);
      final port = widget.model.serverPort;
      if (port < 1 || port > 65535) {
        throw StateError(tr(context).badPort);
      }
      await _server.start(port);
      await NativeBridge.dimScreen(true);
      _serving = true;
      await _refreshAddresses();
    } on SocketException {
      await _stop();
      _error = tr(context).portBusy;
    } on StateError catch (error) {
      await _stop();
      _error = error.message;
    } on Object catch (error) {
      await _stop();
      _error = tr(context).startFailed(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    _serving = false;
    _encoding = false;
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      try {
        if (camera.value.isStreamingImages) await camera.stopImageStream();
      } on Object {
        // The camera is already stopped.
      }
      await camera.dispose();
    }
    await _server.stop();
    await WakelockPlus.disable();
    await NativeBridge.dimScreen(false);
    await NativeBridge.stopForeground();
    if (mounted) setState(() => _fps = 0);
  }

  void _onImage(CameraImage image) {
    if (!_serving || _encoding) return;
    final now = DateTime.now();
    if (now.difference(_lastEncode) < const Duration(milliseconds: 280)) return;
    if (image.format.group != ImageFormatGroup.yuv420 || image.planes.length < 3) {
      return;
    }
    _encoding = true;
    _lastEncode = now;
    final y = image.planes[0];
    final u = image.planes[1];
    final v = image.planes[2];
    final frame = YuvFrame(
      width: image.width,
      height: image.height,
      y: Uint8List.fromList(y.bytes),
      u: Uint8List.fromList(u.bytes),
      v: Uint8List.fromList(v.bytes),
      yRow: y.bytesPerRow,
      uRow: u.bytesPerRow,
      vRow: v.bytesPerRow,
      yPixel: y.bytesPerPixel ?? 1,
      uPixel: u.bytesPerPixel ?? 1,
      vPixel: v.bytesPerPixel ?? 1,
    );
    final degrees = _deviceDegrees();
    final sensor = _camera?.description.sensorOrientation ?? 0;
    final mirror = _camera?.description.lensDirection == CameraLensDirection.front;
    final orientation = streamAngle(sensorOrientation: sensor, deviceDegrees: degrees);
    final pose = isLandscapeDegrees(degrees) ? 'landscape' : 'portrait';
    Future<void>(() {
      try {
        final jpeg = encodeYuv(
          frame,
          orientation: orientation,
          mirror: mirror,
        );
        if (jpeg != null && _serving) {
          _server.latest = StreamFrame(jpeg, pose);
          _noteFrame();
        }
      } on Object {
        // Skip a frame the encoder could not turn into a JPEG.
      } finally {
        _encoding = false;
      }
    });
  }

  void _noteFrame() {
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_fpsStamp).inMilliseconds;
    if (elapsed < 1000) return;
    _fps = _frameCount * 1000 / elapsed;
    _frameCount = 0;
    _fpsStamp = now;
    if (mounted) setState(() {});
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CameraSettingsPage(model: widget.model)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = tr(context);
    final degrees = _deviceDegrees();
    final landscape = isLandscapeDegrees(degrees);
    final pose = text.sendingPose(landscape, widget.model.orientationMode != 'auto');
    final port = widget.model.serverPort;
    final url = _addresses.isEmpty ? null : streamUrl(host: _addresses.first, port: port);
    final tailscale = url != null && isTailscaleAddress(_addresses.first);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.homeCamera),
        actions: [
          IconButton(
            tooltip: text.settings,
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _preview(landscape),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : (_serving ? _stop : _start),
            child: Text(_busy ? text.preparing : (_serving ? text.stopSending : text.startSending)),
          ),
          const SizedBox(height: 8),
          Text(pose),
          const SizedBox(height: 4),
          Text(
            _serving
                ? text.streamingFps(_fps.toStringAsFixed(1))
                : text.beforeStream,
          ),
          if (_serving) ...[
            const SizedBox(height: 4),
            Text(text.dimNote),
          ],
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_error, style: const TextStyle(color: Color(0xFF9B2C2C))),
          ],
          const SizedBox(height: 16),
          SectionCard(
            title: text.cameraIp,
            child: url == null
                ? Text(text.findingAddress)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tailscale ? text.copyThisIp : text.homeOnlyIp),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: Text(_addresses.first)),
                          IconButton(
                            onPressed: () => copyText(context, _addresses.first, text.cameraIp),
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _preview(bool landscape) {
    final camera = _camera;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: navy,
        child: SizedBox(
          height: landscape ? 220 : 360,
          width: double.infinity,
          child: camera != null && camera.value.isInitialized
              ? CameraPreview(camera)
              : const Center(child: Icon(Icons.videocam, color: cream, size: 64)),
        ),
      ),
    );
  }
}
