import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'iot_device.dart';
import 'mjpeg.dart';

final _commandPattern = RegExp(r'^/api/v1/iot/devices/([^/]+)/command$');

class StreamFrame {
  const StreamFrame(this.jpeg, this.orientation);

  final Uint8List jpeg;
  final String orientation;
}

/// Home-phone HTTP server. Viewers, including the Windows screensaver,
/// open [streamPath] with an optional bearer token.
class CameraServer {
  CameraServer({required this.token, required this.devices});

  final String Function() token;
  final List<IotDevice> Function() devices;

  StreamFrame? latest;
  int port = 0;

  HttpServer? _server;
  bool _running = false;

  Future<void> start(int requestedPort) async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, requestedPort);
    _server = server;
    _running = true;
    port = server.port;
    server.autoCompress = false;
    server.listen(
      (request) => unawaited(_handle(request)),
      onError: (Object _) {},
    );
  }

  Future<void> stop() async {
    _running = false;
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  bool _authorized(HttpRequest request) {
    final expected = token().trim();
    if (expected.isEmpty) return true;
    final header = request.headers.value(HttpHeaders.authorizationHeader) ?? '';
    if (!header.toLowerCase().startsWith('bearer ')) return false;
    return header.substring(7).trim() == expected;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (!_authorized(request)) {
        await _json(response, 401, {'error': 'The token does not match.'});
        return;
      }
      final path = request.uri.path;
      if (request.method == 'GET' && path == healthPath) {
        await _json(response, 200, {'ok': true});
        return;
      }
      if (request.method == 'GET' && path == streamPath) {
        await _stream(response);
        return;
      }
      if (request.method == 'GET' && path == devicesPath) {
        await _json(response, 200, [
          for (final device in devices()) {'id': device.id, 'name': device.name},
        ]);
        return;
      }
      final command = _commandPattern.firstMatch(path);
      if (request.method == 'POST' && command != null) {
        await _command(
          request,
          response,
          Uri.decodeComponent(command.group(1)!),
        );
        return;
      }
      await _json(response, 404, {'error': 'That address does not exist.'});
    } on Object {
      try {
        await response.close();
      } on Object {
        // The viewer already hung up.
      }
    }
  }

  Future<void> _stream(HttpResponse response) async {
    response.statusCode = HttpStatus.ok;
    response.headers.set(
      HttpHeaders.contentTypeHeader,
      'multipart/x-mixed-replace; boundary=frame',
    );
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.bufferOutput = false;
    StreamFrame? sent;
    var last = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      while (_running) {
        final frame = latest;
        final now = DateTime.now();
        if (frame != null &&
            (!identical(frame, sent) ||
                now.difference(last) > const Duration(seconds: 2))) {
          response.add(mjpegPart(frame.jpeg, orientation: frame.orientation));
          await response.flush();
          sent = frame;
          last = now;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await response.close();
    } on Object {
      try {
        await response.close();
      } on Object {
        // Closed by the viewer.
      }
    }
  }

  Future<void> _command(
    HttpRequest request,
    HttpResponse response,
    String id,
  ) async {
    var size = 0;
    final builder = await request.fold<BytesBuilder>(
      BytesBuilder(copy: false),
      (builder, chunk) {
        size += chunk.length;
        if (size <= 4096) builder.add(chunk);
        return builder;
      },
    );
    if (size > 4096) {
      await _json(response, 413, {'error': 'The request is too long.'});
      return;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(builder.toBytes()));
    } on Object {
      await _json(response, 400, {'error': 'Check the request.'});
      return;
    }
    final action = decoded is Map ? decoded['action']?.toString() : null;
    if (action != 'on' && action != 'off') {
      await _json(response, 400, {'error': 'The action must be on or off.'});
      return;
    }
    IotDevice? device;
    for (final item in devices()) {
      if (item.id == id) device = item;
    }
    if (device == null) {
      await _json(response, 404, {'error': 'That device does not exist.'});
      return;
    }
    try {
      await device.invoke(action!);
    } on DeviceCallException catch (error) {
      await _json(response, 502, {'error': error.message});
      return;
    }
    await _json(response, 200, {'ok': true});
  }

  Future<void> _json(HttpResponse response, int status, Object body) async {
    final bytes = utf8.encode(jsonEncode(body));
    response.statusCode = status;
    response.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    response.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
  }
}
