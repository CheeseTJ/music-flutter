import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../animation/pearl_motion.dart';
import '../theme/pearl_colors.dart';
import '../theme/pearl_elevation.dart';

/// 提示语义
enum PearlToastType { info, success, warning, error }

/// 统一的顶部轻提示（玻璃胶囊，带语义图标）。
///
/// 为什么不用 Material 的 [SnackBar]：
/// - M3 的 SnackBar 只能贴底，`margin` 只能从底部往上抬，没有顶部选项；
/// - 本项目的悬浮 tab bar 与迷你播放器是 `Stack` 里的普通 widget，而不是
///   `Scaffold.bottomNavigationBar`，`Scaffold` 并不知道它们存在，SnackBar 会直接压在上面；
/// - 若改成贴底浮动，偏移量还得按页面分别计算，13 处调用点漏一个就会重新被遮挡。
///
/// 这里改为往根 [Overlay] 插一个浮层，落点固定在状态栏之下，
/// 与页面底部有什么无关，全 App 一个常量。
///
/// ```dart
/// PearlToast.show(context, '已是最新版本 v1.1.6');
/// PearlToast.success(context, '晴天 已添加到曲库');
/// PearlToast.error(context, '获取下载链接失败');
/// ```
class PearlToast {
  PearlToast._();

  /// 距离状态栏的额外间距
  static const double _topGap = 8;

  static const Duration _defaultDuration = Duration(seconds: 3);

  /// 当前提示的移除器；插入新的提示时用它顶掉旧的
  static VoidCallback? _dismissCurrent;

  static void show(
    BuildContext context,
    String message, {
    PearlToastType type = PearlToastType.info,
    Duration duration = _defaultDuration,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // 同一时刻只留一个：新的直接顶掉旧的（不做退场动画，避免叠两层）
    _dismissCurrent?.call();
    _dismissCurrent = null;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PearlToastView(
        message: message,
        type: type,
        duration: duration,
        onGone: () => _remove(entry),
      ),
    );
    overlay.insert(entry);
    _dismissCurrent = () => _remove(entry);
  }

  static void success(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
  }) =>
      show(context, message, type: PearlToastType.success, duration: duration);

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
  }) =>
      show(context, message, type: PearlToastType.warning, duration: duration);

  static void error(
    BuildContext context,
    String message, {
    Duration duration = _defaultDuration,
  }) =>
      show(context, message, type: PearlToastType.error, duration: duration);

  /// 幂等移除：退场动画结束时和「被新提示顶掉」时会各调一次
  static void _remove(OverlayEntry entry) {
    if (entry.mounted) entry.remove();
  }
}

class _PearlToastView extends StatefulWidget {
  const _PearlToastView({
    required this.message,
    required this.type,
    required this.duration,
    required this.onGone,
  });

  final String message;
  final PearlToastType type;
  final Duration duration;
  final VoidCallback onGone;

  @override
  State<_PearlToastView> createState() => _PearlToastViewState();
}

class _PearlToastViewState extends State<_PearlToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  Timer? _timer;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: PearlMotion.durationLg);
    _fade = CurvedAnimation(
      parent: _ctrl,
      curve: PearlMotion.decelerate,
      reverseCurve: PearlMotion.accelerate,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(_fade);

    _ctrl.forward();
    _timer = Timer(widget.duration, _hide);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _hide() async {
    if (_gone) return;
    _gone = true;
    _timer?.cancel();
    await _ctrl.reverse();
    widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = widget.type;
    final color = _semanticColor(type, isDark);
    final isNeutral = type == PearlToastType.info;

    final border = isNeutral
        ? PearlElevation.border(PearlLayer.overlay, isDark)
        : color.withValues(alpha: isDark ? 0.34 : 0.30);

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        // Overlay 是根浮层，拿不到某个页面的 SafeArea，只能自己取状态栏高度
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + PearlToast._topGap,
          left: 16,
          right: 16,
        ),
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: GestureDetector(
              onTap: _hide,
              child: Container(
                // 阴影必须画在 ClipRRect 之外，否则会被裁掉
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: PearlElevation.shadow(PearlLayer.overlay, isDark),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: isNeutral
                            ? PearlElevation.fill(PearlLayer.overlay, isDark)
                            : color.withValues(alpha: isDark ? 0.16 : 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_icon(type), size: 17, color: color),
                          const SizedBox(width: 9),
                          Flexible(
                            child: Text(
                              widget.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: PearlColors.textPrimary(isDark),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Color _semanticColor(PearlToastType type, bool isDark) {
    switch (type) {
      case PearlToastType.info:
        return PearlColors.accent(isDark);
      case PearlToastType.success:
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      case PearlToastType.warning:
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
      case PearlToastType.error:
        return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    }
  }

  static IconData _icon(PearlToastType type) {
    switch (type) {
      case PearlToastType.info:
        return Icons.info_outline_rounded;
      case PearlToastType.success:
        return Icons.check_circle_outline_rounded;
      case PearlToastType.warning:
        return Icons.warning_amber_rounded;
      case PearlToastType.error:
        return Icons.error_outline_rounded;
    }
  }
}
