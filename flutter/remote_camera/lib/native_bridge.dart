import 'package:flutter/services.dart';

class NativeBridge {
  static const _channel = MethodChannel('com.anyethernet.remote_camera/native');

  static Future<bool> tailscaleInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('tailscaleInstalled') ?? false;
    } on Object {
      return false;
    }
  }

  /// `opened` when Tailscale launched, `store` when Play Store opened.
  static Future<String> openTailscale() async {
    try {
      return await _channel.invokeMethod<String>('openTailscale') ?? 'missing';
    } on Object {
      return 'missing';
    }
  }

  static Future<bool> tailscaleConnected() async {
    try {
      return await _channel.invokeMethod<bool>('tailscaleConnected') ?? false;
    } on Object {
      return false;
    }
  }

  static Future<bool> startForeground({required String title, required String text}) async {
    try {
      return await _channel.invokeMethod<bool>('startForeground', {'title': title, 'text': text}) ?? false;
    } on Object {
      return false;
    }
  }

  static Future<void> acquireMulticast() async {
    try {
      await _channel.invokeMethod<void>('acquireMulticast');
    } on Object {
      // Discovery still runs if the phone does not expose a multicast lock.
    }
  }

  static Future<void> releaseMulticast() async {
    try {
      await _channel.invokeMethod<void>('releaseMulticast');
    } on Object {
      // The lock is already gone.
    }
  }

  static Future<void> stopForeground() async {
    try {
      await _channel.invokeMethod<void>('stopForeground');
    } on Object {
      // The service is already gone.
    }
  }

  /// Keeps the panel on at the lowest brightness so the camera is not closed.
  static Future<void> dimScreen(bool dim) async {
    try {
      await _channel.invokeMethod<void>('dimScreen', {'dim': dim});
    } on Object {
      // Brightness stays as the phone left it.
    }
  }

  static Future<bool> batteryUnrestricted() async {
    try {
      return await _channel.invokeMethod<bool>('batteryUnrestricted') ?? true;
    } on Object {
      return true;
    }
  }

  static Future<void> requestBatteryUnrestricted() async {
    try {
      await _channel.invokeMethod<void>('requestBatteryUnrestricted');
    } on Object {
      // The phone did not show the battery prompt.
    }
  }
}
