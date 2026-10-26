import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nsd/nsd.dart';

import 'native_bridge.dart';

class FoundDevice {
  const FoundDevice({
    required this.name,
    required this.kind,
    required this.onUrl,
    required this.offUrl,
  });

  final String name;
  final String kind;
  final String onUrl;
  final String offUrl;
}

/// Builds control addresses from a discovery reply. The viewer never sees these URLs.
FoundDevice describeDevice({
  required String name,
  required String host,
  required int port,
  String? shellyBody,
  String? tasmotaBody,
  String serviceType = '',
}) {
  final base = port == 80 ? 'http://$host' : 'http://$host:$port';
  final label = name.trim().isEmpty ? host : name.trim();
  if (shellyBody != null && shellyBody.contains('{')) {
    final secondGen = RegExp(r'"gen"\s*:\s*2').hasMatch(shellyBody);
    if (secondGen) {
      return FoundDevice(
        name: label,
        kind: 'Shelly',
        onUrl: '$base/rpc/Switch.Set?id=0&on=true',
        offUrl: '$base/rpc/Switch.Set?id=0&on=false',
      );
    }
    return FoundDevice(
      name: label,
      kind: 'Shelly',
      onUrl: '$base/relay/0?turn=on',
      offUrl: '$base/relay/0?turn=off',
    );
  }
  if (tasmotaBody != null && tasmotaBody.contains('Status')) {
    return FoundDevice(
      name: label,
      kind: 'Tasmota',
      onUrl: '$base/cm?cmnd=Power%20On',
      offUrl: '$base/cm?cmnd=Power%20Off',
    );
  }
  if (serviceType.contains('esphome')) {
    return FoundDevice(name: label, kind: 'ESPHome', onUrl: '$base/', offUrl: '');
  }
  return FoundDevice(name: label, kind: 'HTTP', onUrl: '', offUrl: '');
}

/// Looks for home devices advertising themselves on the local network.
Future<List<FoundDevice>> discoverHomeDevices() async {
  const types = ['_http._tcp', '_esphomelib._tcp', '_shelly._tcp'];
  final discoveries = <Discovery>[];
  await NativeBridge.acquireMulticast();
  try {
    for (final type in types) {
      try {
        discoveries.add(await startDiscovery(type, ipLookupType: IpLookupType.v4));
      } on Object {
        // This network may not answer that service type.
      }
    }
    await Future<void>.delayed(const Duration(seconds: 4));
    final found = <FoundDevice>[];
    final seen = <String>{};
    for (final discovery in discoveries) {
      for (final service in discovery.services) {
        final host = _hostOf(service);
        final port = service.port ?? 80;
        if (host == null || !seen.add('$host:$port')) continue;
        found.add(
          await _identify(
            name: service.name ?? host,
            host: host,
            port: port,
            serviceType: service.type ?? '',
          ),
        );
      }
    }
    return found;
  } finally {
    for (final discovery in discoveries) {
      try {
        await stopDiscovery(discovery);
      } on Object {
        // Stopping a finished discovery is harmless.
      }
    }
    await NativeBridge.releaseMulticast();
  }
}

String? _hostOf(Service service) {
  final addresses = service.addresses;
  if (addresses != null) {
    for (final address in addresses) {
      if (address.type == InternetAddressType.IPv4 && !address.isLoopback) {
        return address.address;
      }
    }
  }
  final host = service.host?.trim();
  if (host == null || host.isEmpty) return null;
  return host.endsWith('.') ? host.substring(0, host.length - 1) : host;
}

Future<FoundDevice> _identify({
  required String name,
  required String host,
  required int port,
  required String serviceType,
}) async {
  final base = port == 80 ? 'http://$host' : 'http://$host:$port';
  final shelly = await _get('$base/shelly');
  final tasmota = shelly == null ? await _get('$base/cm?cmnd=Status%200') : null;
  return describeDevice(
    name: name,
    host: host,
    port: port,
    shellyBody: shelly,
    tasmotaBody: tasmota,
    serviceType: serviceType,
  );
}

Future<String?> _get(String url) async {
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 3));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode >= 400) return null;
    return body;
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}
