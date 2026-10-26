import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:remote_camera/frame_encoder.dart';
import 'package:remote_camera/iot_device.dart';
import 'package:remote_camera/mjpeg.dart';

void main() {
  test('mjpeg part round trip keeps the jpeg', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9, 1, 2, 3]);
    final assembler = MjpegAssembler();
    final frames = assembler.add(mjpegPart(jpeg));
    expect(frames, hasLength(1));
    expect(frames.single.bytes, jpeg);
    expect(frames.single.orientation, '');
  });

  test('assembler keeps the shot orientation', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
    final frames = MjpegAssembler().add(mjpegPart(jpeg, orientation: 'landscape'));
    expect(frames.single.bytes, jpeg);
    expect(frames.single.orientation, 'landscape');
  });

  test('assembler accepts a frame split across chunks', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0x00, 0x11, 0x22]);
    final part = mjpegPart(jpeg);
    final assembler = MjpegAssembler();
    expect(assembler.add(part.sublist(0, 12)), isEmpty);
    final frames = assembler.add(part.sublist(12));
    expect(frames.single.bytes, jpeg);
  });

  test('assembler reads two frames from one chunk', () {
    final first = Uint8List.fromList([0xFF, 0xD8, 1]);
    final second = Uint8List.fromList([0xFF, 0xD8, 2, 3]);
    final assembler = MjpegAssembler();
    final frames = assembler.add([...mjpegPart(first), ...mjpegPart(second)]);
    expect(frames.map((frame) => frame.bytes), [first, second]);
  });

  test('resolveStreamUri fills the screensaver path', () {
    expect(
      resolveStreamUri('100.64.1.2').toString(),
      'http://100.64.1.2:8787/api/v1/stream.mjpeg',
    );
    expect(
      displayCameraAddress('http://100.64.1.2:8787/api/v1/stream.mjpeg'),
      '100.64.1.2',
    );
    expect(
      resolveStreamUri('http://camera.example:8787/api/v1/stream.mjpeg').path,
      streamPath,
    );
    expect(() => resolveStreamUri('   '), throwsFormatException);
  });

  test('tailscale addresses are the 100.64/10 range', () {
    expect(isTailscaleAddress('100.64.0.1'), isTrue);
    expect(isTailscaleAddress('100.127.255.255'), isTrue);
    expect(isTailscaleAddress('100.63.1.1'), isFalse);
    expect(isTailscaleAddress('100.128.0.1'), isFalse);
    expect(isTailscaleAddress('192.168.0.8'), isFalse);
  });

  test('yuv frame becomes a jpeg', () {
    final jpeg = encodeYuv(
      YuvFrame(
        width: 4,
        height: 4,
        y: Uint8List(16)..fillRange(0, 16, 140),
        u: Uint8List(4)..fillRange(0, 4, 128),
        v: Uint8List(4)..fillRange(0, 4, 128),
        yRow: 4,
        uRow: 2,
        vRow: 2,
        yPixel: 1,
        uPixel: 1,
        vPixel: 1,
      ),
      orientation: 90,
    );
    expect(jpeg, isNotNull);
    expect(jpeg!.first, 0xFF);
    expect(jpeg[1], 0xD8);
    final size = jpegSize(jpeg);
    expect(size?.width, 4);
    expect(size?.height, 4);
  });

  test('viewer device list hides local urls', () {
    final devices = parseViewerDevices(
      '[{"id":"lamp","name":"거실 조명","onUrl":"http://192.168.0.5/on"}]',
    );
    expect(devices.single.id, 'lamp');
    expect(devices.single.name, '거실 조명');
  });
}
