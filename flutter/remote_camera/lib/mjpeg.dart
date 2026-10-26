import 'dart:convert';
import 'dart:typed_data';

/// Path the Windows screensaver already requests.
const streamPath = '/api/v1/stream.mjpeg';
const healthPath = '/api/v1/health';
const devicesPath = '/api/v1/iot/devices';

const _headerBreak = [13, 10, 13, 10]; // \r\n\r\n

/// Multipart body for one JPEG, using the boundary name `frame`.
///
/// [orientation] is `portrait` or `landscape` so a viewer can match the shot.
Uint8List mjpegPart(Uint8List jpeg, {String orientation = ''}) {
  final pose = orientation == 'portrait' || orientation == 'landscape'
      ? 'X-Orientation: $orientation\r\n'
      : '';
  final header = utf8.encode(
    '--frame\r\nContent-Type: image/jpeg\r\nContent-Length: ${jpeg.length}\r\n$pose\r\n',
  );
  final tail = utf8.encode('\r\n');
  final out = Uint8List(header.length + jpeg.length + tail.length);
  out.setRange(0, header.length, header);
  out.setRange(header.length, header.length + jpeg.length, jpeg);
  out.setRange(header.length + jpeg.length, out.length, tail);
  return out;
}

class MjpegFrame {
  const MjpegFrame(this.bytes, {this.orientation = ''});

  final Uint8List bytes;
  final String orientation;
}

/// Pulls JPEG frames out of a multipart/x-mixed-replace body.
class MjpegAssembler {
  final BytesBuilder _pending = BytesBuilder(copy: false);

  List<MjpegFrame> add(List<int> chunk) {
    _pending.add(chunk);
    if (_pending.length > 8 * 1024 * 1024) {
      _pending.clear();
      return const [];
    }
    final data = _pending.toBytes();
    final frames = <MjpegFrame>[];
    var start = 0;
    while (start < data.length) {
      final headerEnd = _indexOf(data, _headerBreak, start);
      if (headerEnd < 0) break;
      final header = utf8.decode(
        data.sublist(start, headerEnd),
        allowMalformed: true,
      );
      final length = _contentLength(header);
      if (length == null) {
        start += 1;
        continue;
      }
      final body = headerEnd + 4;
      if (data.length < body + length) break;
      final jpeg = Uint8List.sublistView(data, body, body + length);
      if (jpeg.length >= 2 && jpeg[0] == 0xFF && jpeg[1] == 0xD8) {
        frames.add(MjpegFrame(Uint8List.fromList(jpeg), orientation: _orientation(header)));
      }
      start = body + length;
    }
    _pending.clear();
    if (start < data.length) {
      _pending.add(Uint8List.sublistView(data, start));
    }
    return frames;
  }

  static String _orientation(String header) {
    final match = RegExp(
      r'x-orientation:\s*(portrait|landscape)',
      caseSensitive: false,
    ).firstMatch(header);
    return match?.group(1)?.toLowerCase() ?? '';
  }

  static int? _contentLength(String header) {
    final match = RegExp(
      r'content-length:\s*(\d+)',
      caseSensitive: false,
    ).firstMatch(header);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  static int _indexOf(List<int> data, List<int> pattern, int from) {
    final last = data.length - pattern.length;
    for (var i = from; i <= last; i++) {
      var found = true;
      for (var j = 0; j < pattern.length; j++) {
        if (data[i + j] != pattern[j]) {
          found = false;
          break;
        }
      }
      if (found) return i;
    }
    return -1;
  }
}

/// Accepts a base URL or the full stream URL.
Uri resolveStreamUri(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('empty');
  }
  final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
  final uri = Uri.parse(withScheme);
  if (uri.host.isEmpty) {
    throw const FormatException('bad');
  }
  var path = uri.path;
  if (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.isEmpty || path == '/') path = streamPath;
  final port = uri.hasPort ? uri.port : 8787;
  return uri.replace(path: path, port: port);
}

/// The address a person types. A normal camera URL is shown as the IP only.
String displayCameraAddress(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';
  try {
    final uri = resolveStreamUri(trimmed);
    final standard = uri.scheme == 'http' &&
        uri.port == 8787 &&
        uri.path == streamPath &&
        uri.query.isEmpty;
    if (standard) return uri.host;
    return trimmed.contains('://') ? uri.toString() : trimmed;
  } on FormatException {
    return trimmed;
  }
}

String streamUrl({required String host, required int port}) {
  return 'http://$host:$port$streamPath';
}

/// Tailscale's IPv4 range is 100.64.0.0/10.
bool isTailscaleAddress(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;
  final numbers = parts.map(int.tryParse).toList();
  if (numbers.any((n) => n == null || n < 0 || n > 255)) return false;
  return numbers[0] == 100 && numbers[1]! >= 64 && numbers[1]! <= 127;
}

/// Width and height from a JPEG SOF marker, without decoding the picture.
({int width, int height})? jpegSize(Uint8List data) {
  if (data.length < 4 || data[0] != 0xFF || data[1] != 0xD8) return null;
  var i = 2;
  while (i + 3 < data.length) {
    if (data[i] != 0xFF) {
      i++;
      continue;
    }
    final marker = data[i + 1];
    if (marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final length = (data[i + 2] << 8) | data[i + 3];
    if (length < 2) return null;
    if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2) {
      if (i + 8 >= data.length) return null;
      final height = (data[i + 5] << 8) | data[i + 6];
      final width = (data[i + 7] << 8) | data[i + 8];
      if (width <= 0 || height <= 0) return null;
      return (width: width, height: height);
    }
    i += 2 + length;
  }
  return null;
}
