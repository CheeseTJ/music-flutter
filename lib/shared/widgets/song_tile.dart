import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/theme/pearl_colors.dart';
import '../../core/theme/pearl_theme.dart';
import '../../data/models/song.dart';
import '../../core/network/platform_cover_service.dart';
import '../../core/widgets/pearl_loading.dart';
import 'pearl_cover.dart';

class SongTile extends StatefulWidget {
  final LocalSong song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;
  final bool isPaused;

  /// 这首正在取链/加载。此时播放器里装的还是上一首，所以按钮转圈且不可点 ——
  /// 否则按下去会把上一首放出来（冷启动恢复的场景尤其明显）。
  final bool isLoading;

  /// 当前曲目的播放/暂停按钮；为 null 时不渲染这个按钮
  final VoidCallback? onPlayPause;

  /// 右侧「更多」按钮；为 null 时不渲染这个按钮
  final VoidCallback? onMore;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.isPlaying = false,
    this.isPaused = false,
    this.isLoading = false,
    this.onPlayPause,
    this.onMore,
  });

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  String? _coverUrl;
  int? _lastSongId;

  @override
  void initState() {
    super.initState();
    _lastSongId = widget.song.id;
    _coverUrl = PlatformCoverService.getCachedPath(
      widget.song.type,
      widget.song.title,
      widget.song.artist,
    );
    if (_coverUrl == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _coverUrl == null) {
          _fetchCover(widget.song);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant SongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.song.title != widget.song.title ||
        oldWidget.song.artist != widget.song.artist) {
      _lastSongId = widget.song.id;
      _coverUrl = PlatformCoverService.getCachedPath(
        widget.song.type,
        widget.song.title,
        widget.song.artist,
      );
      if (_coverUrl == null) {
        _fetchCover(widget.song);
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _fetchCover(LocalSong song) async {
    final id = song.id;
    final path = await const PlatformCoverService().fetch(
      song.type,
      song.title,
      song.artist,
    );
    if (!mounted || _lastSongId != id) return;
    setState(() => _coverUrl = path);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCurrentPlaying = widget.isPlaying;
    final isPaused = widget.isPaused;

    final textP = isCurrentPlaying
        ? PearlColors.accent(isDark)
        : PearlColors.textPrimary(isDark);
    final textS = PearlColors.textSecondary(isDark);
    final textD = PearlColors.textDisabled(isDark);
    final accent = PearlColors.accent(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isCurrentPlaying
                  ? PearlColors.accent(isDark).withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(PearlTheme.radiusSm),
                  child: _buildCover(isDark, isCurrentPlaying, isPaused),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textP,
                          fontSize: 15,
                          fontWeight: isCurrentPlaying ? FontWeight.w700 : FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.song.artist} · ${widget.song.durationFormatted}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrentPlaying
                              ? PearlColors.accent(isDark).withValues(alpha: 0.7)
                              : textS,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!widget.song.hasLyric)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.lyrics_outlined, size: 14, color: textD),
                  ),
                // 播放/暂停：只有当前曲目才有意义，就地 toggle
                if (isCurrentPlaying && widget.onPlayPause != null)
                  _TileIconButton(
                    icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: accent,
                    background: accent.withValues(alpha: 0.12),
                    loading: widget.isLoading,
                    onTap: widget.onPlayPause,
                  ),
                // 更多：打开操作面板
                if (widget.onMore != null)
                  _TileIconButton(
                    icon: Icons.more_horiz_rounded,
                    color: textS,
                    onTap: widget.onMore,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(bool isDark, bool isPlaying, bool isPaused) {
    if (_coverUrl != null) {
      final isLocal = _coverUrl!.startsWith('/') || _coverUrl!.startsWith(r'\');
      final imageWidget = isLocal
          ? Image.file(File(_coverUrl!), width: 56, height: 56, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => PearlCover(isDark: isDark))
          : CachedNetworkImage(
              imageUrl: _coverUrl!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (_, __) => PearlCover(isDark: isDark),
              errorWidget: (_, __, ___) => PearlCover(isDark: isDark),
            );
      return Stack(
        children: [
          imageWidget,
          if (isPlaying && !isPaused)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Icon(
                    Icons.bar_chart_rounded,
                    size: 22,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
          if (isPlaying && isPaused)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 24,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    return PearlCover(isDark: isDark);
  }
}

/// 歌曲行右侧的图标按钮：触摸区 36×36，视觉方块 32×32。
///
/// 之前这里的播放/暂停与「更多」只是两个 15~18px 的裸 [Icon]，既小又不可点
/// （整行只有一个 InkWell，点它们等于点整行）。现在改成真正的按钮，
/// 规格与搜索页 `_ResultTile` 的按钮对齐。
class _TileIconButton extends StatelessWidget {
  const _TileIconButton({
    required this.icon,
    required this.onTap,
    required this.color,
    this.background,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Color? background;

  /// 加载中：显示转圈并禁止点击
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(9),
              ),
              child: loading
                  // 这里必须用 Padding 收窄：Container 的 32×32 是紧约束，
                  // PearlLoading 自己的 size 会被强制撑成 32。
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: PearlLoading(size: 16, color: color),
                    )
                  : Icon(icon, size: 19, color: color),
            ),
          ),
        ),
      ),
    );
  }
}
