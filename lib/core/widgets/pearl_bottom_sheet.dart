import 'package:flutter/material.dart';
import '../theme/pearl_elevation.dart';

/// 统一风格的底部弹窗。
///
/// 用法：
/// ```dart
/// showPearlBottomSheet<T>(context, (ctx) => MyContent());
/// ```
///
/// 统一以下参数：
/// - 背景透明（让外层 Container 自绘玻璃样式）
/// - 顶部圆角与 [PearlElevation.sheetRadius] 一致（此前声明 32、容器实际画 24，对不上）
/// - 遮罩只做「淡出」（[PearlElevation.barrier]），不再把底栏压成一片黑
/// - isScrollControlled / useSafeArea 一致
Future<T?> showPearlBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool useSafeArea = true,
  Color? barrierColor,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    barrierColor: barrierColor ?? PearlElevation.barrier(isDark),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(PearlElevation.sheetRadius),
      ),
    ),
    builder: builder,
  );
}
