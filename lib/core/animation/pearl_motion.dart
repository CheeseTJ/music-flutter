import 'package:flutter/animation.dart';

/// 全局动画设计令牌
///
/// 所有页面转场、Widget 动画、tween 曲线一律从本类取值，
/// 避免散落在业务文件中的 hard-code 时长/曲线，保证手感一致。
class PearlMotion {
  PearlMotion._();

  // ---- 时长 ----
  /// 100ms — 微反馈（按下回弹、ripple 结束）
  static const Duration durationXs = Duration(milliseconds: 100);

  /// 150ms — 紧凑切换（图标切换、播放/暂停）
  static const Duration durationSm = Duration(milliseconds: 150);

  /// 220ms — 默认组件动画（颜色、尺寸、tab 指示器）
  static const Duration durationMd = Duration(milliseconds: 220);

  /// 320ms — 浮层/抽屉进出
  static const Duration durationLg = Duration(milliseconds: 320);

  /// 480ms — 强调/页面级动画
  static const Duration durationXl = Duration(milliseconds: 480);

  /// 340ms — 路由 page transition
  static const Duration durationPage = Duration(milliseconds: 340);

  /// 600ms — 颜色/主题过渡（封面色 → 背景色）
  static const Duration durationColor = Duration(milliseconds: 600);

  /// 40s — 播放器背景 HSV 循环
  static const Duration durationBg = Duration(seconds: 40);

  // ---- 曲线 ----
  /// 默认减速曲线 — 主流入/过渡
  static const Curve standard = Curves.easeOutCubic;

  /// 强力减速 — 抽屉/浮层
  static const Curve decelerate = Curves.easeOutQuart;

  /// 默认加速曲线 — 退场
  static const Curve standardIn = Curves.easeInCubic;

  /// 同上别名（语义更明确）
  static const Curve accelerate = Curves.easeInCubic;

  /// 进入曲线（= standard）
  static const Curve standardOut = Curves.easeOutCubic;

  /// 强调 — 进度滚动、字号变化
  static const Curve emphasized = Curves.easeInOutCubic;

  /// 线性 — 循环背景
  static const Curve linear = Curves.linear;
}
