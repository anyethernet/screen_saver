import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class YuvFrame {
  const YuvFrame({
    required this.width,
    required this.height,
    required this.y,
    required this.u,
    required this.v,
    required this.yRow,
    required this.uRow,
    required this.vRow,
    required this.yPixel,
    required this.uPixel,
    required this.vPixel,
  });

  final int width;
  final int height;
  final Uint8List y;
  final Uint8List u;
  final Uint8List v;
  final int yRow;
  final int uRow;
  final int vRow;
  final int yPixel;
  final int uPixel;
  final int vPixel;
}

/// Downsamples a camera frame to about 640 pixels wide and returns JPEG bytes.
Uint8List? encodeYuv(
  YuvFrame frame, {
  int orientation = 0,
  bool mirror = false,
}) {
  if (frame.width < 2 || frame.height < 2) return null;
  final step = math.max(1, (frame.width / 640).round());
  final dstW = frame.width ~/ step;
  final dstH = frame.height ~/ step;
  if (dstW < 2 || dstH < 2) return null;

  final rgb = Uint8List(dstW * dstH * 3);
  var index = 0;
  for (var y = 0; y < dstH; y++) {
    final sy = y * step;
    final uy = sy ~/ 2;
    for (var x = 0; x < dstW; x++) {
      final sx = x * step;
      final ux = sx ~/ 2;
      final yp = _sample(frame.y, frame.yRow, frame.yPixel, sx, sy, 16);
      final up = _sample(frame.u, frame.uRow, frame.uPixel, ux, uy, 128);
      final vp = _sample(frame.v, frame.vRow, frame.vPixel, ux, uy, 128);
      final d = up - 128;
      final e = vp - 128;
      rgb[index++] = _clamp(yp + ((1436 * e) >> 10));
      rgb[index++] = _clamp(yp - ((352 * d + 731 * e) >> 10));
      rgb[index++] = _clamp(yp + ((1815 * d) >> 10));
    }
  }

  img.Image picture = img.Image.fromBytes(
    width: dstW,
    height: dstH,
    bytes: rgb.buffer,
    numChannels: 3,
  );
  final turns = ((orientation % 360) + 360) % 360;
  if (turns == 90 || turns == 180 || turns == 270) {
    picture = img.copyRotate(picture, angle: turns);
  }
  if (mirror) picture = img.flipHorizontal(picture);
  return img.encodeJpg(picture, quality: 55);
}

int _sample(
  Uint8List plane,
  int rowStride,
  int pixelStride,
  int x,
  int y,
  int fallback,
) {
  final stride = pixelStride <= 0 ? 1 : pixelStride;
  final row = rowStride <= 0 ? 1 : rowStride;
  final index = y * row + x * stride;
  if (index < 0 || index >= plane.length) return fallback;
  return plane[index];
}

int _clamp(int value) => value < 0 ? 0 : (value > 255 ? 255 : value);
