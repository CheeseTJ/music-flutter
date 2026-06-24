import 'package:flutter/material.dart';
import '../theme/pearl_theme.dart';

/// 统一风格的底部弹窗。
///
/// 用法：
/// ```dart
/// showPearlBottomSheet<T>(context, (ctx) => MyContent());
/// ```
///
/// 统一以下参数：
/// - 背景透明（让外层 Container 自绘玻璃样式）
/// - 圆角 32px
/// - isScrollControlled / useSafeArea 一致
Future<T?> showPearlBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color? barrierColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(PearlTheme.radiusXl)),
    ),
    builder: builder,
  );
}
