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

  /// 当前 AudioManager.mode。2 = MODE_IN_CALL，3 = MODE_IN_COMMUNICATION。
  ///
  /// 拿不到时返回 0（MODE_NORMAL），即「不在通话中」。
  static Future<int> getAudioMode() async {
    try {
      final mode = await notificationChannel.invokeMethod<int>('getAudioMode');
      return mode ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 通话开始 / 结束时回调，参数是新的 AudioManager.mode。
  ///
  /// 为什么要从原生侧推：正常流程是系统在通话时给 app 发焦点丢失回调，但部分
  /// 厂商 ROM 不给第三方 app 发，Dart 侧等不到任何信号，音乐就继续播。
  /// 详见 MainActivity.startAudioModeWatch()。
  static void listenAudioMode(void Function(int mode) onChanged) {
    notificationChannel.setMethodCallHandler((call) async {
      if (call.method == 'onAudioModeChanged' && call.arguments is int) {
        onChanged(call.arguments as int);
      }
      return null;
    });
  }
}
