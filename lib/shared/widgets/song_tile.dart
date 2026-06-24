import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/pearl_colors.dart';
import '../../core/theme/pearl_theme.dart';
import '../../data/models/song.dart';
import '../../core/network/platform_cover_service.dart';

class SongTile extends ConsumerStatefulWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isPlaying;
  final bool isPaused;

  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.isPlaying = false,
    this.isPaused = false,
  });

  @override
  ConsumerState<SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<SongTile>
    with AutomaticKeepAliveClientMixin {
  String? _coverUrl;
  int? _lastSongId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _lastSongId = widget.song.id;
    _coverUrl = PlatformCoverService.getCachedUrl(
      widget.song.type,
      widget.song.title,
      widget.song.artist,
    );
    if (_coverUrl == null) {
      _fetchCover(widget.song);
    }
  }

  @override
  void didUpdateWidget(covariant SongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.song.title != widget.song.title ||
        oldWidget.song.artist != widget.song.artist) {
      _lastSongId = widget.song.id;
      _coverUrl = PlatformCoverService.getCachedUrl(
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

  Future<void> _fetchCover(Song song) async {
    final id = song.id;
    final url = await const PlatformCoverService().fetchUrl(
      song.type,
      song.title,
      song.artist,
    );
    if (!mounted || _lastSongId != id) return;
    setState(() => _coverUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCurrentPlaying = widget.isPlaying;
    final isPaused = widget.isPaused;

    final textP = isCurrentPlaying
        ? PearlColors.accent(isDark)
        : PearlColors.textPrimary(isDark);
    final textS = PearlColors.textSecondary(isDark);
    final textD = PearlColors.textDisabled(isDark);

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
                if (isCurrentPlaying)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 18,
                      color: PearlColors.accent(isDark),
                    ),
                  ),
                if (!widget.song.hasLyric)
                  Icon(Icons.lyrics_outlined, size: 13, color: textD),
                const SizedBox(width: 6),
                Icon(Icons.more_horiz_rounded, size: 15, color: textD),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover(bool isDark, bool isPlaying, bool isPaused) {
    final accent = PearlColors.accent(isDark);

    if (_coverUrl != null) {
      return Stack(
        children: [
          CachedNetworkImage(
            imageUrl: _coverUrl!,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            placeholder: (_, __) => _coverPlaceholder(accent),
            errorWidget: (_, __, ___) => _coverPlaceholder(accent),
          ),
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
    return _coverPlaceholder(accent);
  }

  Widget _coverPlaceholder(Color accent) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(PearlTheme.radiusSm),
      ),
      child: Center(
        child: Icon(Icons.music_note_rounded, size: 24, color: accent.withValues(alpha: 0.5)),
      ),
    );
  }
}
