import 'notification_channel.dart';

class NotificationService {
  static Future<bool> get isPermissionGranted async {
    try {
      final result =
          await notificationChannel.invokeMethod<bool>('isNotificationPermissionGranted');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await notificationChannel.invokeMethod('openNotificationSettings');
    } catch (_) {}
  }

  static Future<String> debugInfo() async {
    try {
      final result = await notificationChannel.invokeMethod<String>('debugInfo');
      return result ?? 'unknown';
    } catch (e) {
      return 'error: $e';
    }
  }
}
