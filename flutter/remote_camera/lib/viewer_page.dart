import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_model.dart';
import 'iot_device.dart';
import 'l10n.dart';
import 'viewer_settings_page.dart';
import 'viewer_stream.dart';
import 'widgets.dart';

class ViewerPage extends StatefulWidget {
  const ViewerPage({super.key, required this.model});

  final AppModel model;

  @override
  State<ViewerPage> createState() => _ViewerPageState();
}

class _ViewerPageState extends State<ViewerPage> {
  late final ViewerStream _stream;
  bool _connecting = false;
  String? _commanding;

  @override
  void initState() {
    super.initState();
    _stream = ViewerStream();
    _stream.status.addListener(_rebuild);
    _stream.frame.addListener(_rebuild);
    _stream.landscape.addListener(_rebuild);
    _stream.aspect.addListener(_rebuild);
    _stream.deviceList.addListener(_rebuild);
    widget.model.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.model.removeListener(_rebuild);
    _stream.status.removeListener(_rebuild);
    _stream.frame.removeListener(_rebuild);
    _stream.landscape.removeListener(_rebuild);
    _stream.aspect.removeListener(_rebuild);
    _stream.deviceList.removeListener(_rebuild);
    _stream.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    try {
      await _stream.connect(
        url: widget.model.viewerUrl.trim(),
        token: widget.model.viewerToken.trim(),
        allowBadCert: widget.model.allowBadCert,
      );
    } on FormatException catch (error) {
      _stream.status.value = error.message;
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _command(ViewerDevice device, String action) async {
    setState(() => _commanding = device.id);
    final error = await _stream.command(device.id, action);
    if (!mounted) return;
    setState(() => _commanding = null);
    final text = tr(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error == null ? text.commandSent(device.name, action) : text.knownError(error))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = tr(context);
    final frame = _stream.frame.value;
    final shot = _stream.landscape.value;
    final connected = _stream.streamUri != null && _stream.status.value != 'disconnected';
    final devices = _stream.deviceList.value;
    final status = text.streamStatus(_stream.status.value);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(text.away),
        actions: [
          IconButton(
            tooltip: text.settings,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ViewerSettingsPage(model: widget.model)),
              );
            },
            icon: const Icon(Icons.settings),
          ),
          IconButton(
            tooltip: text.screensaver,
            onPressed: frame == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => SaverPage(stream: _stream)),
                    );
                  },
            icon: const Icon(Icons.bedtime),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                FittedStream(bytes: frame, aspect: _stream.aspect.value),
                if (frame == null)
                  Center(
                    child: Text(status, style: const TextStyle(color: cream)),
                  ),
                if (shot != null)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(text.shot(shot), style: const TextStyle(color: cream)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Material(
            color: cream,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.model.viewerUrl.trim().isEmpty
                          ? text.enterIpInSettings
                          : status,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _connecting
                                ? null
                                : widget.model.viewerUrl.trim().isEmpty
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ViewerSettingsPage(model: widget.model),
                                      ),
                                    );
                                  }
                                : _connect,
                            child: Text(
                              _connecting
                                  ? text.connecting
                                  : widget.model.viewerUrl.trim().isEmpty
                                  ? text.enterIp
                                  : text.connect,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: connected ? _stream.disconnect : null,
                          child: Text(text.disconnect),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (devices.isEmpty)
                      Text(text.devicesHint)
                    else
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            for (final device in devices)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(device.name),
                                    TextButton(
                                      onPressed: _commanding == device.id ? null : () => _command(device, 'on'),
                                      child: Text(text.turnOn),
                                    ),
                                    TextButton(
                                      onPressed: _commanding == device.id ? null : () => _command(device, 'off'),
                                      child: Text(text.turnOff),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SaverPage extends StatefulWidget {
  const SaverPage({super.key, required this.stream});

  final ViewerStream stream;

  @override
  State<SaverPage> createState() => _SaverPageState();
}

class _SaverPageState extends State<SaverPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    widget.stream.frame.addListener(_rebuild);
    widget.stream.aspect.addListener(_rebuild);
    widget.stream.landscape.addListener(_rebuild);
    widget.stream.status.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.stream.frame.removeListener(_rebuild);
    widget.stream.aspect.removeListener(_rebuild);
    widget.stream.landscape.removeListener(_rebuild);
    widget.stream.status.removeListener(_rebuild);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = tr(context);
    final frame = widget.stream.frame.value;
    final shot = widget.stream.landscape.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedStream(bytes: frame, aspect: widget.stream.aspect.value),
            if (frame == null)
              Center(
                child: Text(
                  text.streamStatus(widget.stream.status.value),
                  style: const TextStyle(color: cream),
                ),
              ),
            if (shot != null)
              Positioned(
                left: 16,
                top: 16,
                child: Text(shot == null ? '' : text.shot(shot), style: const TextStyle(color: cream)),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(text.tapToClose, style: const TextStyle(color: cream)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
