import 'package:flutter/material.dart';
import '../../../../core/animation/pearl_motion.dart';
import '../../../../core/theme/pearl_colors.dart';
import '../../../../data/models/lrc_parser.dart';

/// 歌词滚动定位的公共算法
///
/// 用法：将 [LyricsScroller] 嵌入任意父级 ListView / Column / Overlay，
/// 传入 [lyric] / 当前 [position]，组件内部完成：
///   1) 找到当前行 idx
///   2) 平滑滚动 ListView
///   3) 当前行高亮（字体/颜色 tween）
class LyricsScroller extends StatefulWidget {
  final LrcParser? lyric;
  final Duration position;
  final double itemHeight;
  final TextStyle? baseStyle;
  final TextStyle? activeStyle;
  final EdgeInsets padding;
  final bool showMetadata;

  const LyricsScroller({
    super.key,
    required this.lyric,
    required this.position,
    this.itemHeight = 56,
    this.baseStyle,
    this.activeStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.showMetadata = true,
  });

  @override
  State<LyricsScroller> createState() => _LyricsScrollerState();
}

class _LyricsScrollerState extends State<LyricsScroller> {
  final ScrollController _scrollCtrl = ScrollController();
  int _lastIdx = -1;
  bool _entering = true;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Scroll to the index of the active lyric line, clamping within bounds.
  void _scrollTo(int idx) {
    if (!_scrollCtrl.hasClients || idx < 0) return;
    final vp = _scrollCtrl.position.viewportDimension;
    final target = (idx * widget.itemHeight) - vp / 2 + widget.itemHeight / 2;
    final clamped = target.clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    if (_entering) {
      _entering = false;
      _scrollCtrl.jumpTo(clamped);
    } else {
      _scrollCtrl.animateTo(
        clamped,
        duration: PearlMotion.durationLg,
        curve: PearlMotion.emphasized,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = PearlColors.accent(isDark);
    final textS = PearlColors.textSecondary(isDark);
    final textD = PearlColors.textDisabled(isDark);

    final baseStyle = widget.baseStyle ??
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textS,
          letterSpacing: 0.3,
        );
    final activeStyle = widget.activeStyle ??
        TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.3,
        );

    final lyric = widget.lyric;
    if (lyric == null || lyric.lines.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lyrics_outlined, size: 56, color: textD),
            const SizedBox(height: 16),
            Text(
              'No lyrics available',
              style: TextStyle(color: textS, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final idx = lyric.findIndex(widget.position);
    if (idx != _lastIdx && idx >= 0) {
      _lastIdx = idx;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(idx));
    }

    return ListView.builder(
      controller: _scrollCtrl,
      padding: widget.padding,
      itemCount: lyric.lines.length,
      itemBuilder: (context, i) {
        final isCurrent = i == idx;
        return SizedBox(
          height: widget.itemHeight,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: PearlMotion.durationMd,
              curve: PearlMotion.standard,
              style: isCurrent ? activeStyle : baseStyle,
              child: Text(
                lyric.lines[i].text,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}
