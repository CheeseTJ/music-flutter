import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/pearl_elevation.dart';

/// 常驻玻璃层的包装。
///
/// 决策在 [PearlElevation.blurBackdrop]：只有深色才套 [BackdropFilter]，
/// 浅色直接把 [child] 原样返回 —— 这两层压在滚动列表上，开模糊意味着滚动
/// 期间每帧都要离屏渲染 + 回读背景做卷积。
class PearlGlass extends StatelessWidget {
  final bool isDark;
  final double sigma;
  final Widget child;

  const PearlGlass({
    super.key,
    required this.isDark,
    required this.child,
    this.sigma = 30,
  });

  @override
  Widget build(BuildContext context) {
    if (!PearlElevation.blurBackdrop(isDark)) return child;
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      child: child,
    );
  }
}
