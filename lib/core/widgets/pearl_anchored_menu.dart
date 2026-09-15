import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../animation/pearl_motion.dart';
import '../theme/pearl_colors.dart';
import '../theme/pearl_elevation.dart';
import 'package:music_app/core/i18n/app_strings.dart';

/// 锚定菜单的一项。
class PearlMenuEntry<T> {
  final T value;
  final String label;
  final IconData icon;

  const PearlMenuEntry({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// 玻璃质感的锚定菜单，取代 Material 的 `PopupMenuButton`。
///
/// 原生 `PopupMenuButton` 用 `Material(elevation: 8)` 画一块实心不透明面板
/// 加 M3 硬阴影，是全 App 唯一一个不透光的浮层，和 tab bar / 迷你播放器 /
/// 轻提示的玻璃语言对不上。这里换成同一套表面令牌：明度台阶 + 1px 描边 +
/// overlay 层阴影，并从锚点做 160ms 的 scale + fade 展开。
///
/// 返回选中项的值；点空白处或系统返回键返回 null。
Future<T?> showPearlMenu<T>({
  required BuildContext context,
  required BuildContext anchorContext,
  required List<PearlMenuEntry<T>> entries,
  T? selected,
  double width = 184,
  double gap = 6,
  double itemHeight = 42,
  EdgeInsets margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
  String? barrierLabel,
}) {
  final anchorBox = anchorContext.findRenderObject() as RenderBox?;
  if (anchorBox == null || !anchorBox.hasSize) return Future<T?>.value();

  final screen = MediaQuery.sizeOf(context);
  final origin = anchorBox.localToGlobal(Offset.zero);
  final anchorSize = anchorBox.size;

  // 默认右对齐到锚点，并夹在屏幕内
  final rawLeft = origin.dx + anchorSize.width - width;
  final maxLeft = screen.width - width - margin.right;
  final left = rawLeft < margin.left
      ? margin.left
      : (rawLeft > maxLeft ? maxLeft : rawLeft);

  // 面板高度按条目数估算，空间不够就翻到锚点上方
  final panelHeight = entries.length * itemHeight + 12;
  final below = origin.dy + anchorSize.height + gap;
  final top = (below + panelHeight > screen.height - margin.bottom)
      ? origin.dy - gap - panelHeight
      : below;

  return Navigator.of(context, rootNavigator: true).push<T>(
    _PearlMenuRoute<T>(
      entries: entries,
      selected: selected,
      width: width,
      left: left,
      top: top < margin.top ? margin.top : top,
      itemHeight: itemHeight,
      barrierLabel: barrierLabel ?? L.s.closeMenu,
    ),
  );
}

class _PearlMenuRoute<T> extends PopupRoute<T> {
  _PearlMenuRoute({
    required this.entries,
    required this.selected,
    required this.width,
    required this.left,
    required this.top,
    required this.itemHeight,
    required this.barrierLabel,
  });

  final List<PearlMenuEntry<T>> entries;
  final T? selected;
  final double width;
  final double left;
  final double top;
  final double itemHeight;
  @override
  final String barrierLabel;

  /// 不压暗背景：锚定菜单是一次轻操作，不需要 ModalBarrier 的暗场
  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _PearlMenuPanel<T>(
      entries: entries,
      selected: selected,
      width: width,
      left: left,
      top: top,
      itemHeight: itemHeight,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: PearlMotion.decelerate,
      reverseCurve: PearlMotion.accelerate,
    );
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        // 从右上角（贴着锚点）展开
        alignment: Alignment.topRight,
        scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

class _PearlMenuPanel<T> extends StatelessWidget {
  const _PearlMenuPanel({
    required this.entries,
    required this.selected,
    required this.width,
    required this.left,
    required this.top,
    required this.itemHeight,
  });

  final List<PearlMenuEntry<T>> entries;
  final T? selected;
  final double width;
  final double left;
  final double top;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = PearlElevation.radius(PearlLayer.overlay);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: Container(
            // 阴影画在 ClipRRect 之外，否则会被裁掉
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: PearlElevation.shadow(PearlLayer.overlay, isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: PearlElevation.fill(PearlLayer.overlay, isDark),
                    borderRadius: BorderRadius.circular(radius),
                    border: PearlElevation.outline(PearlLayer.overlay, isDark),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in entries)
                          _PearlMenuRow(
                            label: entry.label,
                            icon: entry.icon,
                            selected: entry.value == selected,
                            isDark: isDark,
                            height: itemHeight,
                            onTap: () => Navigator.of(context).pop(entry.value),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PearlMenuRow extends StatelessWidget {
  const _PearlMenuRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.height,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool isDark;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = PearlColors.accent(isDark);
    return InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: selected ? accent.withValues(alpha: 0.10) : null,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? accent : PearlColors.textSecondary(isDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: selected ? accent : PearlColors.textPrimary(isDark),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_rounded, size: 17, color: accent),
          ],
        ),
      ),
    );
  }
}
