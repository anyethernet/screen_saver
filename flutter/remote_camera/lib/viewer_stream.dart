import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'iot_device.dart';
import 'mjpeg.dart';

class StreamStatus implements Exception {
  StreamStatus(this.message, {this.stop = false});
  final String message;
  final bool stop;

  @override
  String toString() => message;
}

/// Watches one home camera and sends device commands to that phone.
class ViewerStream {
  final frame = ValueNotifier<Uint8List?>(null);
  final landscape = ValueNotifier<bool?>(null);
  final aspect = ValueNotifier<double?>(null);
  final status = ValueNotifier<String>('idle');
  final deviceList = ValueNotifier<List<ViewerDevice>>(const []);

  int _generation = 0;
  HttpClient? _client;
  String _token = '';
  bool _allowBadCert = false;
  Uri? _streamUri;

  Uri? get streamUri => _streamUri;

  Future<void> connect({
    required String url,
    required String token,
    required bool allowBadCert,
  }) async {
    final generation = ++_generation;
    _client?.close(force: true);
    _token = token.trim();
    _allowBadCert = allowBadCert;
    frame.value = null;
    landscape.value = null;
    aspect.value = null;
    deviceList.value = const [];
    final uri = resolveStreamUri(url);
    _streamUri = uri;
    status.value = 'connecting';
    unawaited(_watchDevices(generation));
    unawaited(_loop(uri, generation));
  }

  Future<void> disconnect() async {
    _generation++;
    _client?.close(force: true);
    _client = null;
    status.value = 'disconnected';
  }

  void dispose() {
    _generation++;
    _client?.close(force: true);
    frame.dispose();
    landscape.dispose();
    aspect.dispose();
    status.dispose();
    deviceList.dispose();
  }

  Future<void> reloadDevices() => _loadDevices(_generation);

  Future<String?> command(String id, String action) async {
    final streamUri = _streamUri;
    if (streamUri == null) return 'connect-first';
    final client = _clientFor();
    try {
      final path = '/api/v1/iot/devices/${Uri.encodeComponent(id)}/command';
      final request = await client.postUrl(streamUri.replace(path: path, query: ''));
      _authorize(request);
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode({'action': action})));
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (response.statusCode == 200) return null;
      return _errorMessage(body) ?? 'device-no-response';
    } on Object {
      return 'device-request-failed';
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _loop(Uri uri, int generation) async {
    while (generation == _generation) {
      try {
        await _read(uri, generation);
      } on StreamStatus catch (error) {
        if (generation != _generation) return;
        status.value = error.message;
        if (error.stop) return;
      } on Object {
        if (generation != _generation) return;
        status.value = 'reconnecting';
      }
      if (generation != _generation) return;
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _read(Uri uri, int generation) async {
    final client = _clientFor();
    _client = client;
    Timer? idle;
    void bump() {
      idle?.cancel();
      idle = Timer(const Duration(seconds: 20), () => client.close(force: true));
    }

    try {
      bump();
      final request = await client.getUrl(uri);
      _authorize(request);
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (generation != _generation) return;
      if (response.statusCode == 401) {
        await response.drain<void>();
        throw StreamStatus('token', stop: true);
      }
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw StreamStatus('http:${response.statusCode}');
      }
      final mime = response.headers.contentType?.mimeType ?? '';
      if (mime == 'image/jpeg') {
        final bytes = await response.fold<BytesBuilder>(BytesBuilder(copy: false), (
          builder,
          chunk,
        ) {
          bump();
          builder.add(chunk);
          return builder;
        });
        if (generation == _generation) {
          _show(bytes.toBytes(), '');
        }
        return;
      }

      final assembler = MjpegAssembler();
      await for (final chunk in response) {
        if (generation != _generation) return;
        bump();
        for (final part in assembler.add(chunk)) {
          _show(part.bytes, part.orientation);
        }
      }
    } finally {
      idle?.cancel();
      if (identical(_client, client)) _client = null;
      client.close(force: true);
    }
  }

  Future<void> _watchDevices(int generation) async {
    while (generation == _generation) {
      await _loadDevices(generation);
      if (generation != _generation) return;
      await Future<void>.delayed(const Duration(seconds: 4));
    }
  }

  void _show(Uint8List jpeg, String orientation) {
    frame.value = jpeg;
    final size = jpegSize(jpeg);
    if (orientation == 'landscape' || orientation == 'portrait') {
      landscape.value = orientation == 'landscape';
    } else if (size != null) {
      landscape.value = size.width >= size.height;
    }
    if (size != null) aspect.value = size.width / size.height;
    status.value = 'live';
  }

  Future<void> _loadDevices(int generation) async {
    final streamUri = _streamUri;
    if (streamUri == null || generation != _generation) return;
    final client = _clientFor();
    try {
      final request = await client.getUrl(
        streamUri.replace(path: devicesPath, query: ''),
      );
      _authorize(request);
      final response = await request.close().timeout(const Duration(seconds: 12));
      final body = await response.transform(utf8.decoder).join();
      if (generation != _generation) return;
      if (response.statusCode == 401) {
        status.value = 'token';
        return;
      }
      if (response.statusCode != 200) return;
      deviceList.value = parseViewerDevices(body);
    } on Object {
      // The picture status already says whether the camera is reachable.
    } finally {
      client.close(force: true);
    }
  }

  HttpClient _clientFor() {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    if (_allowBadCert) {
      client.badCertificateCallback = (cert, host, port) => true;
    }
    return client;
  }

  void _authorize(HttpClientRequest request) {
    if (_token.isNotEmpty) {
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
    }
  }

  String? _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on Object {
      return null;
    }
    return null;
  }
}
