import 'package:flutter/material.dart';

/// 浮层 / 表面的层级。
enum PearlLayer {
  /// 内嵌卡片：设置区、统计卡这类贴在页面里的块
  inset,

  /// 浮起层：迷你播放器
  float,

  /// 导航层：悬浮 tab bar
  nav,

  /// 弹出层：锚定菜单、底部面板、轻提示
  overlay,
}

/// 统一的表面令牌。
///
/// 层级靠「明度台阶 + 1px 描边」表达，阴影只做辅助：
///
/// - 深色（`#0A0C12`）：黑色阴影落在近黑底上对比度极低，堆阴影收益小、
///   模糊开销大，所以深色只给弹出层留一层接地阴影，其余全靠描边与明度。
/// - 浅色（`#F6F7FB`）：反过来，白底上阴影有效，而白色描边等于不存在 ——
///   所以浅色下描边必须翻转成黑色细线，并且每一层都补阴影。
///
/// 之前的问题是只有 `glassBg` / `glassBgStrong` 两个玻璃色、且全项目只有
/// 一处给描边做了深浅分支，导致浮层边缘在两种主题下都几乎不可见。
class PearlElevation {
  PearlElevation._();

  /// 表面填充色（数值越大越"高"）
  static Color fill(PearlLayer layer, bool isDark) {
    switch (layer) {
      case PearlLayer.inset:
        return isDark ? const Color(0x17FFFFFF) : const Color(0xD9FFFFFF);
      case PearlLayer.float:
        return isDark ? const Color(0x1AFFFFFF) : const Color(0xE0FFFFFF);
      case PearlLayer.nav:
        return isDark ? const Color(0x1CFFFFFF) : const Color(0xE6FFFFFF);
      case PearlLayer.overlay:
        return isDark ? const Color(0x29FFFFFF) : const Color(0xF7FFFFFF);
    }
  }

  /// 描边色。浅色下必须是黑，白色描边压在近白底上等于没有。
  static Color border(PearlLayer layer, bool isDark) {
    if (isDark) {
      switch (layer) {
        case PearlLayer.inset:
          return Colors.white.withValues(alpha: 0.06);
        case PearlLayer.float:
          return Colors.white.withValues(alpha: 0.10);
        case PearlLayer.nav:
          return Colors.white.withValues(alpha: 0.14);
        case PearlLayer.overlay:
          return Colors.white.withValues(alpha: 0.20);
      }
    }
    switch (layer) {
      case PearlLayer.inset:
        return Colors.black.withValues(alpha: 0.05);
      case PearlLayer.float:
        return Colors.black.withValues(alpha: 0.06);
      case PearlLayer.nav:
        return Colors.black.withValues(alpha: 0.08);
      case PearlLayer.overlay:
        return Colors.black.withValues(alpha: 0.12);
    }
  }

  /// 1px 描边
  static Border outline(PearlLayer layer, bool isDark) =>
      Border.all(color: border(layer, isDark), width: 1);

  /// 阴影。深色下只有弹出层需要接地感，浅色下逐层递增。
  static List<BoxShadow> shadow(PearlLayer layer, bool isDark) {
    if (!isDark) {
      switch (layer) {
        case PearlLayer.inset:
          return const [];
        case PearlLayer.float:
          return [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 26,
              offset: const Offset(0, 10),
              spreadRadius: -10,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ];
        case PearlLayer.nav:
          return [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 32,
              offset: const Offset(0, 14),
              spreadRadius: -12,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ];
        case PearlLayer.overlay:
          return [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 44,
              offset: const Offset(0, 18),
              spreadRadius: -12,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ];
      }
    }
    switch (layer) {
      case PearlLayer.inset:
      case PearlLayer.float:
      case PearlLayer.nav:
        return const [];
      case PearlLayer.overlay:
        return [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.46),
            blurRadius: 44,
            offset: const Offset(0, 18),
            spreadRadius: -12,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ];
    }
  }

  /// 圆角：卡片 / 菜单 16，浮起 28，导航 32
  static double radius(PearlLayer layer) {
    switch (layer) {
      case PearlLayer.inset:
      case PearlLayer.overlay:
        return 16;
      case PearlLayer.float:
        return 28;
      case PearlLayer.nav:
        return 32;
    }
  }

  /// 底部面板的顶部圆角
  static const double sheetRadius = 24;

  /// 遮罩色：面板之下的压暗层，只做"淡出"而不是"盖住"
  static Color barrier(bool isDark) =>
      Colors.black.withValues(alpha: isDark ? 0.32 : 0.18);
}
