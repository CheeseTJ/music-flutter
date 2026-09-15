import 'package:flutter/material.dart';

/// 全局滚动手感。
///
/// 手机端的「跟手程度」有一半不在帧率上，而在物理曲线和边界行为上：
///
/// - [BouncingScrollPhysics]：Android 默认是 Clamping —— 滑到边界直接钉住，
///   没有 iOS 那种橡皮筋回弹，惯性曲线也更短。统一用 Bouncing，两端的
///   回弹和滑动距离会明显更接近 iOS。
/// - 关掉 overscroll 指示器：Material 默认的拉伸效果会在过度滚动时把整块
///   内容拉长重绘，既多花帧，观感也不是想要的。
class PearlScrollBehavior extends MaterialScrollBehavior {
  const PearlScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
