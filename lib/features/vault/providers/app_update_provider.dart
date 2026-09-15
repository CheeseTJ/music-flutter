import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/app_update_service.dart';
import '../../../core/utils/settings.dart';

/// 应用更新的状态。下载进度不在这里 —— 那是纯 UI 关注点，留在行内组件里。
class AppUpdateState {
  /// 当前安装版本（versionName，如 1.1.12）
  final String currentVersion;

  /// 最近一次检查的结果
  final AppUpdateInfo? info;

  final bool checking;

  const AppUpdateState({
    this.currentVersion = '',
    this.info,
    this.checking = false,
  });

  bool get hasUpdate => info?.hasUpdate == true;

  AppUpdateState copyWith({
    String? currentVersion,
    AppUpdateInfo? info,
    bool? checking,
  }) {
    return AppUpdateState(
      currentVersion: currentVersion ?? this.currentVersion,
      info: info ?? this.info,
      checking: checking ?? this.checking,
    );
  }
}

/// 更新检查的唯一入口。
///
/// 之前检查是挂在 Vault 页 Version 行的 initState 上的，而那行位于 Vault 列表
/// 最底部，靠 sliver 懒构建触发 —— 什么时候查、查不查，取决于列表长度和视口
/// 高度，时机不可预期。现在改成 App 启动时显式触发（见 ShellPage.initState），
/// 并在静默检查上加了 [silentInterval] 节流。
class AppUpdateNotifier extends StateNotifier<AppUpdateState> {
  AppUpdateNotifier(this._service) : super(const AppUpdateState());

  final AppUpdateService _service;

  /// 静默检查的最小间隔：这段时间内重复调用直接跳过，
  /// 避免用户频繁起 App 时反复打蒲公英接口。
  static const silentInterval = Duration(hours: 6);

  Future<void> loadVersion() async {
    if (state.currentVersion.isNotEmpty) return;
    final pkg = await PackageInfo.fromPlatform();
    state = state.copyWith(currentVersion: pkg.version);
  }

  /// 返回是否成功拿到结果。
  ///
  /// [silent] 为 true 时不向上抛错（调用方不提示），且受 [silentInterval] 节流；
  /// [force] 为 true 时跳过节流（用户手动点击走这条）。
  /// 非 silent 时失败会 rethrow，由调用方决定怎么提示。
  Future<bool> check({bool silent = false, bool force = false}) async {
    if (state.checking) return false;
    await loadVersion();
    if (state.currentVersion.isEmpty) return false;

    if (silent && !force) {
      final last = await Settings.getLastUpdateCheck();
      if (last != null && DateTime.now().difference(last) < silentInterval) {
        return false;
      }
    }

    state = state.copyWith(checking: true);
    try {
      final info = await _service.check(state.currentVersion);
      state = state.copyWith(checking: false, info: info);
      await Settings.setLastUpdateCheck(DateTime.now());
      return true;
    } catch (e) {
      state = state.copyWith(checking: false);
      if (!silent) rethrow;
      return false;
    }
  }
}

final appUpdateProvider =
    StateNotifierProvider<AppUpdateNotifier, AppUpdateState>(
  (ref) => AppUpdateNotifier(AppUpdateService()),
);
