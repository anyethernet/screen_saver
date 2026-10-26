import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_camera/camera_server.dart';
import 'package:remote_camera/iot_device.dart';
import 'package:remote_camera/mjpeg.dart';

void main() {
  test('server streams one authorized jpeg and rejects a bad token', () async {
    final server = CameraServer(token: () => 'secret', devices: () => const []);
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
    await server.start(0);
    server.latest = StreamFrame(jpeg, 'landscape');
    final client = HttpClient();
    try {
      final denied = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}$streamPath'),
      );
      denied.headers.set(HttpHeaders.authorizationHeader, 'Bearer wrong');
      final deniedResponse = await denied.close();
      expect(deniedResponse.statusCode, 401);
      await deniedResponse.drain<void>();

      final request = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}$streamPath'),
      );
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer secret');
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(response.headers.value(HttpHeaders.contentTypeHeader), contains('boundary=frame'));
      final assembler = MjpegAssembler();
      final frames = <MjpegFrame>[];
      await for (final chunk in response.timeout(const Duration(seconds: 5))) {
        frames.addAll(assembler.add(chunk));
        if (frames.isNotEmpty) break;
      }
      expect(frames.single.bytes, jpeg);
      expect(frames.single.orientation, 'landscape');
    } finally {
      client.close(force: true);
      await server.stop();
    }
  });

  test('device list omits lan urls and command calls the stored url', () async {
    final deviceServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final hits = <String>[];
    deviceServer.listen((request) {
      hits.add(request.uri.path);
      request.response.statusCode = 200;
      request.response.close();
    });
    final devices = [
      IotDevice(
        id: 'lamp',
        name: '거실 조명',
        onUrl: 'http://127.0.0.1:${deviceServer.port}/on',
        offUrl: 'http://127.0.0.1:${deviceServer.port}/off',
      ),
    ];
    final server = CameraServer(token: () => 'secret', devices: () => devices);
    await server.start(0);
    final client = HttpClient();
    try {
      final listRequest = await client.getUrl(
        Uri.parse('http://127.0.0.1:${server.port}$devicesPath'),
      );
      listRequest.headers.set(HttpHeaders.authorizationHeader, 'Bearer secret');
      final listResponse = await listRequest.close();
      final body = await listResponse.transform(utf8.decoder).join();
      expect(listResponse.statusCode, 200);
      expect(body, contains('거실 조명'));
      expect(body.contains('onUrl'), isFalse);
      expect(body.contains('127.0.0.1'), isFalse);

      final command = await client.postUrl(
        Uri.parse('http://127.0.0.1:${server.port}/api/v1/iot/devices/lamp/command'),
      );
      command.headers.set(HttpHeaders.authorizationHeader, 'Bearer secret');
      command.headers.contentType = ContentType.json;
      command.add(utf8.encode('{"action":"on"}'));
      final commandResponse = await command.close();
      expect(commandResponse.statusCode, 200);
      await commandResponse.drain<void>();
      expect(hits, ['/on']);
    } finally {
      client.close(force: true);
      await server.stop();
      await deviceServer.close(force: true);
    }
  });
}
