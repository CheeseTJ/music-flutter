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

  const SongTile({super.key, required this.song, this.onTap, this.onLongPress});

  @override
  ConsumerState<SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<SongTile> {
  String? _coverUrl;

  @override
  void initState() {
    super.initState();
    _fetchCover();
  }

  @override
  void didUpdateWidget(covariant SongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id ||
        oldWidget.song.title != widget.song.title ||
        oldWidget.song.artist != widget.song.artist) {
      _coverUrl = null;
      _fetchCover();
    }
  }

  Future<void> _fetchCover() async {
    final url = await const PlatformCoverService().fetchUrl(
      widget.song.type,
      widget.song.title,
      widget.song.artist,
    );
    if (mounted) setState(() => _coverUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textP = PearlColors.textPrimary(isDark);
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
          child: Container(
            height: 68,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(PearlTheme.radiusSm),
                  child: _buildCover(isDark),
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
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.song.artist} · ${widget.song.durationFormatted}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textS, fontSize: 12),
                      ),
                    ],
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

  Widget _buildCover(bool isDark) {
    final accent = PearlColors.accent(isDark);

    if (_coverUrl != null) {
      return Image.network(
        _coverUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(PearlTheme.radiusSm),
          ),
          child: Center(
            child: Icon(Icons.music_note_rounded, size: 24, color: accent.withValues(alpha: 0.5)),
          ),
        ),
      );
    }
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
