import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/song.dart';
import '../../../features/player/providers/player_provider.dart';
import '../../../features/home/providers/song_list_provider.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.watch(playerProvider.notifier);
    final isPlaying = state.isPlaying;
    final isDark = ref.watch(themeProvider).isDark;
    final playBtnGradient = isDark
        ? const LinearGradient(colors: [AuroraColors.gradientStart, AuroraColors.gradientEnd])
        : const LinearGradient(colors: [HarmoniqColors.blue, HarmoniqColors.emphasize]);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SmallBtn(
          icon: _playModeIcon(notifier.playMode),
          selected: notifier.playMode != 0,
          isDark: isDark,
          onTap: () => notifier.togglePlayMode(),
        ),
        _LargeBtn(
          icon: Icons.skip_previous_rounded,
          isDark: isDark,
          onTap: () => notifier.previous(),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: playBtnGradient,
            shape: BoxShape.circle,
            boxShadow: isDark
                ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 10))]
                : [BoxShadow(color: const Color(0x4076A8FF), blurRadius: 32, offset: const Offset(0, 14))],
          ),
          child: IconButton(
            icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 28, color: Colors.white),
            onPressed: () => notifier.togglePlayPause(),
            padding: EdgeInsets.zero,
          ),
        ),
        _LargeBtn(
          icon: Icons.skip_next_rounded,
          isDark: isDark,
          onTap: () => notifier.next(),
        ),
        _SmallBtn(
          icon: Icons.queue_music_rounded,
          selected: false,
          isDark: isDark,
          onTap: () => _showPlaylist(context, ref),
        ),
      ],
    );
  }

  IconData _playModeIcon(int mode) {
    switch (mode) {
      case 1:
        return Icons.repeat_one_rounded;
      case 2:
        return Icons.shuffle_rounded;
      default:
        return Icons.repeat_rounded;
    }
  }

  void _showPlaylist(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(playerProvider.notifier);
    final songsState = ref.read(songListProvider);
    final songs = songsState is AsyncData ? (songsState.value ?? <Song>[]) : <Song>[];
    final currentId = notifier.currentSong?.id;
    final isDark = ref.read(themeProvider).isDark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AuroraColors.bgSecondary : HarmoniqColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary,
                  borderRadius: BorderRadius.circular(2),
                )),
            const SizedBox(height: 16),
            Text('Playlist',
                style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600,
                  color: isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary,
                )),
            const SizedBox(height: 12),
            Expanded(
              child: songs.isEmpty
                  ? Center(child: Text('No songs',
                      style: TextStyle(color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: songs.length,
                      itemBuilder: (_, i) {
                        final song = songs[i];
                        final isCurrent = song.id == currentId;
                        return ListTile(
                          leading: Icon(
                            isCurrent ? Icons.music_note_rounded : Icons.music_note_outlined,
                            color: isCurrent
                                ? (isDark ? AuroraColors.gradientStart : HarmoniqColors.blue)
                                : (isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
                            size: 20,
                          ),
                          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isCurrent
                                    ? (isDark ? AuroraColors.gradientStart : HarmoniqColors.blue)
                                    : (isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary),
                                fontSize: 14,
                                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                              )),
                          subtitle: Text('${song.artist} 璺?${song.durationFormatted}',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary,
                                fontSize: 12,
                              )),
                          onTap: () {
                            Navigator.pop(ctx);
                            notifier.setPlaylist(songs);
                            notifier.play(song);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, required this.selected, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        child: Icon(icon, size: 22,
            color: selected
                ? (isDark ? AuroraColors.gradientStart : HarmoniqColors.blue)
                : (isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary)),
      ),
    );
  }
}

class _LargeBtn extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  const _LargeBtn({required this.icon, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        icon: Icon(icon, size: 34,
            color: isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
