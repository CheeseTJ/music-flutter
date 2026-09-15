import 'package:flutter/material.dart';

import '../../core/theme/pearl_colors.dart';
import '../../core/theme/pearl_theme.dart';

/// 无封面时的占位图。
///
/// 之前这份东西在 4 个地方各写了一遍，尺寸、圆角、底色、图标不透明度全不一样
/// （圆角 16/12/8/8，底色纯色/渐变/变量，图标 50%/85%/100%，尺寸 56/48/44/由父容器决定）。
/// 现在收敛成三种规格，改图标形状只需要改这一个文件。
enum PearlCoverSize {
  /// 列表行内：56×56，r16(radiusSm)。歌曲行、搜索页结果行通用。
  inline,

  /// 紧凑：44×44，r8。空间紧张的行（如搜索结果）用这个。
  compact,

  /// 迷你播放器：48×48，r12，强调用的渐变底。
  nowPlaying,
}

class PearlCover extends StatelessWidget {
  /// 紧凑态圆角。这两个值只服务封面占位，不放进 PearlTheme 的通用梯度里。
  static const double _compactRadius = 8;
  static const double _nowPlayingRadius = 12;

  final bool isDark;
  final PearlCoverSize size;

  /// 底色基准色，默认主题 accent。
  /// 「本地歌曲」那块整体用青色系，所以需要能传进来。
  final Color? tint;

  /// 紧凑规格下当前播放/选中：底色加深一档
  final bool highlighted;

  final IconData icon;

  const PearlCover({
    super.key,
    required this.isDark,
    this.size = PearlCoverSize.inline,
    this.tint,
    this.highlighted = false,
    this.icon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final base = tint ?? PearlColors.accent(isDark);

    final double dim;
    final double iconSize;
    final BoxDecoration decoration;
    final Color iconColor;

    switch (size) {
      case PearlCoverSize.inline:
        dim = 56;
        iconSize = 24;
        decoration = BoxDecoration(
          color: base.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(PearlTheme.radiusSm),
        );
        iconColor = base.withValues(alpha: 0.5);

      case PearlCoverSize.compact:
        dim = 44;
        iconSize = 22;
        decoration = BoxDecoration(
          color: base.withValues(alpha: highlighted ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(_compactRadius),
        );
        iconColor = base.withValues(alpha: 0.85);

      case PearlCoverSize.nowPlaying:
        dim = 48;
        iconSize = 22;
        decoration = BoxDecoration(
          gradient: LinearGradient(
            colors: [base, base.withValues(alpha: 0.5)],
          ),
          borderRadius: BorderRadius.circular(_nowPlayingRadius),
        );
        iconColor = PearlColors.textPrimary(isDark);
    }

    return Container(
      width: dim,
      height: dim,
      decoration: decoration,
      child: Icon(icon, size: iconSize, color: iconColor),
    );
  }
}
