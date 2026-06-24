import 'package:flutter/services.dart';

class NotificationService {
  static const _channel = MethodChannel('com.example.music_app/notification');

  static Future<bool> get isPermissionGranted async {
    try {
      final result = await _channel.invokeMethod<bool>('isNotificationPermissionGranted');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> get isChannelEnabled async {
    try {
      final result = await _channel.invokeMethod<bool>('isNotificationChannelEnabled');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _channel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  static Future<String> debugInfo() async {
    try {
      final result = await _channel.invokeMethod<String>('debugInfo');
      return result ?? 'unknown';
    } catch (e) {
      return 'error: $e';
    }
  }
}
