import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户设置的小开关集中点。SharedPreferences 是异步的，所以这里每个
/// getter / setter 都是 Future；调用方自行决定是否需要 await。
///
/// 响应式：底栏按钮需要在 vault 页修改后立刻反映，所以用
/// [showUploadButtonProvider] 作为 Riverpod state，订阅方 rebuild
/// 即可。
class Settings {
  Settings._();

  static const _kShowUploadButton = 'show_upload_button';
  static const _kShowMiniPlayer = 'show_mini_player';
  static const _kPlayMode = 'play_mode';

  /// 是否显示底栏的"上传"快捷按钮。默认 true。
  static Future<bool> getShowUploadButton() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kShowUploadButton) ?? true;
  }

  static Future<void> setShowUploadButton(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowUploadButton, value);
  }

  /// 是否显示底部迷你播放器。默认 true。
  static Future<bool> getShowMiniPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kShowMiniPlayer) ?? true;
  }

  static Future<void> setShowMiniPlayer(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowMiniPlayer, value);
  }

  static Future<int> getPlayMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kPlayMode) ?? 0;
  }

  static Future<void> setPlayMode(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kPlayMode, value);
  }
}

/// Riverpod 状态：当前是否显示底栏上传按钮。初始值假设为 true，
/// MusicApp 启动时从 SharedPreferences 异步刷新为真实值。
final showUploadButtonProvider = StateProvider<bool>((ref) => true);

/// Riverpod 状态：当前是否显示底部迷你播放器。
final showMiniPlayerProvider = StateProvider<bool>((ref) => true);
