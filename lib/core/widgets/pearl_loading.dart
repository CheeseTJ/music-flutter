import 'package:flutter/material.dart';

/// 统一的加载转圈。
///
/// 之前 6 处各写一份 CircularProgressIndicator，尺寸 12/16/20/20/24/36、
/// 线宽 1.6/2/默认 4，颜色 5 处 accent、1 处青色。这几处替换不改变任何观感，
/// 所以 size / strokeWidth 都按各处原值传进来。
///
/// 颜色做成必传而不是内置 accent：一是「下载」那块有专用青色，
/// 二是这里的调用点有几个在 const 上下文里，从外面传色比塞 isDark 更好写。
class PearlLoading extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const PearlLoading({
    super.key,
    required this.color,
    this.size = 24,
    this.strokeWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
      ),
    );
  }
}
