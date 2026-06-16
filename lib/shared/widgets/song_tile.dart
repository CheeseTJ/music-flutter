import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/song.dart';

class SongTile extends ConsumerStatefulWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SongTile({super.key, required this.song, this.onTap, this.onLongPress});

  @override
  ConsumerState<SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<SongTile> {
  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;
    final textP = isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary;
    final textS = isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                // Cover
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(colors: AuroraColors.gradient)
                          : const LinearGradient(colors: [HarmoniqColors.blue, HarmoniqColors.emphasize]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(Icons.music_note_rounded, size: 24,
                          color: isDark ? AuroraColors.textSecondary : Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.song.artist} · ${widget.song.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textS, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Duration
                Text(
                  widget.song.durationFormatted,
                  style: TextStyle(
                    color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                // More
                Icon(Icons.more_horiz_rounded, size: 18,
                    color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
