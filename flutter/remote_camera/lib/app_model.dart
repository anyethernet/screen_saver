import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'iot_device.dart';

class AppModel extends ChangeNotifier {
  static const roleCamera = 'camera';
  static const roleViewer = 'viewer';

  String role = '';
  String serverToken = '';
  int serverPort = 8787;
  int rotation = 0;
  String orientationMode = 'auto';
  String viewerUrl = '';
  String viewerToken = '';
  bool allowBadCert = false;
  String language = 'en';
  List<IotDevice> devices = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    role = prefs.getString('rc_role') ?? '';
    serverToken = prefs.getString('rc_server_token') ?? '';
    serverPort = prefs.getInt('rc_server_port') ?? 8787;
    rotation = prefs.getInt('rc_rotation') ?? 0;
    orientationMode = prefs.getString('rc_orientation_mode') ?? 'auto';
    if (orientationMode != 'portrait' && orientationMode != 'landscape') {
      orientationMode = 'auto';
    }
    viewerUrl = prefs.getString('rc_viewer_url') ?? '';
    viewerToken = prefs.getString('rc_viewer_token') ?? '';
    allowBadCert = prefs.getBool('rc_bad_cert') ?? false;
    language = prefs.getString('rc_language') == 'ko' ? 'ko' : 'en';
    devices = _readDevices(prefs.getString('rc_devices'));
    if (serverToken.isEmpty) {
      serverToken = createToken();
      await prefs.setString('rc_server_token', serverToken);
    }
    notifyListeners();
  }

  Future<void> setRole(String value) async {
    role = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rc_role', value);
  }

  Future<void> setServer({String? token, int? port, int? quarterTurns}) async {
    if (token != null) serverToken = token;
    if (port != null) serverPort = port;
    if (quarterTurns != null) rotation = quarterTurns % 360;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rc_server_token', serverToken);
    await prefs.setInt('rc_server_port', serverPort);
    await prefs.setInt('rc_rotation', rotation);
  }

  Future<void> setOrientationMode(String value) async {
    orientationMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rc_orientation_mode', value);
  }

  Future<void> setLanguage(String value) async {
    language = value == 'ko' ? 'ko' : 'en';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rc_language', language);
  }

  Future<void> setViewer({
    String? url,
    String? token,
    bool? insecure,
  }) async {
    if (url != null) viewerUrl = url;
    if (token != null) viewerToken = token;
    if (insecure != null) allowBadCert = insecure;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rc_viewer_url', viewerUrl);
    await prefs.setString('rc_viewer_token', viewerToken);
    await prefs.setBool('rc_bad_cert', allowBadCert);
  }

  Future<void> saveDevice(IotDevice device) async {
    final next = [...devices];
    final index = next.indexWhere((item) => item.id == device.id);
    if (index >= 0) {
      next[index] = device;
    } else {
      next.add(device);
    }
    devices = next;
    notifyListeners();
    await _saveDevices();
  }

  Future<void> removeDevice(String id) async {
    devices = devices.where((item) => item.id != id).toList();
    notifyListeners();
    await _saveDevices();
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'rc_devices',
      jsonEncode([for (final device in devices) device.toJson()]),
    );
  }

  static List<IotDevice> _readDevices(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic> && (item['id']?.toString().isNotEmpty ?? false))
            IotDevice.fromJson(item),
      ];
    } on Object {
      return [];
    }
  }
}

String createToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(18, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String newDeviceId() => DateTime.now().microsecondsSinceEpoch.toString();
