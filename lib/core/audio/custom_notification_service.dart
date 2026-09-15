import 'dart:async';
import 'package:flutter/foundation.dart';

import 'notification_channel.dart';

class CustomNotificationService {
  static bool _enabled = false;
  static bool get isEnabled => _enabled;
  static void enable() {
    _enabled = true;
    debugPrint('[CustomNotif] Enabled as fallback');
  }

  static Stream<String> get onAction {
    _actionController ??= StreamController<String>.broadcast();
    notificationChannel.setMethodCallHandler((call) async {
      debugPrint('[CustomNotif] onAction callback: ${call.method}');
      if (call.method == 'onPlay') {
        _actionController?.add('play');
      } else if (call.method == 'onPause') {
        _actionController?.add('pause');
      } else if (call.method == 'onSkipNext') {
        _actionController?.add('skipNext');
      } else if (call.method == 'onSkipPrev') {
        _actionController?.add('skipPrev');
      }
    });
    return _actionController!.stream;
  }

  static StreamController<String>? _actionController;

  static Future<void> show({
    required String title,
    required String artist,
    String album = '',
    String? coverUrl,
    bool playing = true,
  }) async {
    if (!_enabled) return;
    try {
      debugPrint('[CustomNotif] show() calling native: title=$title, coverUrl=$coverUrl');
      await notificationChannel.invokeMethod('showCustomNotification', {
        'title': title,
        'artist': artist,
        'album': album,
        'coverUrl': coverUrl,
        'playing': playing,
      });
      debugPrint('[CustomNotif] show() native call returned');
    } catch (e) {
      debugPrint('[CustomNotif] show() FAILED: $e');
    }
  }

  static Future<void> updatePlayState(bool playing) async {
    if (!_enabled) return;
    try {
      await notificationChannel
          .invokeMethod('updateCustomPlayState', {'playing': playing});
    } catch (_) {}
  }

  static Future<void> hide() async {
    try {
      await notificationChannel.invokeMethod('hideCustomNotification');
    } catch (_) {}
  }
}
