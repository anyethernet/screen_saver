import 'dart:async';
import 'dart:convert';
import 'dart:io';

class IotDevice {
  const IotDevice({
    required this.id,
    required this.name,
    required this.onUrl,
    required this.offUrl,
  });

  final String id;
  final String name;
  final String onUrl;
  final String offUrl;

  Map<String, String> toJson() => {
    'id': id,
    'name': name,
    'onUrl': onUrl,
    'offUrl': offUrl,
  };

  factory IotDevice.fromJson(Map<String, dynamic> json) {
    return IotDevice(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      onUrl: json['onUrl']?.toString() ?? '',
      offUrl: json['offUrl']?.toString() ?? '',
    );
  }

  String urlFor(String action) => action == 'on' ? onUrl : offUrl;

  /// Calls the device on the home network. The viewer never sends this URL.
  Future<void> invoke(String action) {
    return invokeDeviceUrl(urlFor(action));
  }
}

class DeviceCallException implements Exception {
  DeviceCallException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ViewerDevice {
  const ViewerDevice(this.id, this.name);
  final String id;
  final String name;
}

List<ViewerDevice> parseViewerDevices(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) {
    throw const FormatException('The device list is not valid.');
  }
  final devices = <ViewerDevice>[];
  for (final item in decoded) {
    if (item is! Map) continue;
    final id = item['id']?.toString() ?? '';
    final name = item['name']?.toString() ?? '';
    if (id.isEmpty) continue;
    devices.add(ViewerDevice(id, name.isEmpty ? 'Device' : name));
  }
  return devices;
}

Future<void> invokeDeviceUrl(String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    throw DeviceCallException('This action has no address.');
  }
  final Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } on FormatException {
    throw DeviceCallException('The device address is not valid.');
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw DeviceCallException('The device address must be http or https.');
  }
  if (uri.host.isEmpty) {
    throw DeviceCallException('The device address is not valid.');
  }

  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 4);
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(const Duration(seconds: 5));
    await response.drain<void>();
    if (response.statusCode >= 400) {
      throw DeviceCallException('The device returned ${response.statusCode}.');
    }
  } on DeviceCallException {
    rethrow;
  } on TimeoutException {
    throw DeviceCallException('The device did not respond.');
  } on Object {
    throw DeviceCallException('Could not reach the device.');
  } finally {
    client.close(force: true);
  }
}
