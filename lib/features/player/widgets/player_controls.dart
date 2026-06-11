import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/song.dart';
import '../../player/providers/player_provider.dart';
import '../../home/providers/song_list_provider.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.watch(playerProvider.notifier);
    final isPlaying = state.isPlaying;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SmallBtn(
          icon: _playModeIcon(notifier.playMode),
          onTap: () => notifier.togglePlayMode(),
        ),
        _LargeBtn(
          icon: Icons.skip_previous_rounded,
          onTap: () => notifier.previous(),
        ),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Color(0x30D4A853), blurRadius: 12, offset: Offset(0, 3))],
          ),
          child: IconButton(
            icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30, color: AppColors.deep),
            onPressed: () => notifier.togglePlayPause(),
            padding: EdgeInsets.zero,
          ),
        ),
        _LargeBtn(
          icon: Icons.skip_next_rounded,
          onTap: () => notifier.next(),
        ),
        _SmallBtn(
          icon: Icons.queue_music_rounded,
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

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.subtle, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('播放列表', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Expanded(
              child: songs.isEmpty
                  ? const Center(child: Text('暂无歌曲', style: TextStyle(color: AppColors.muted)))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: songs.length,
                      itemBuilder: (_, i) {
                        final song = songs[i];
                        final isCurrent = song.id == currentId;
                        return ListTile(
                          leading: Icon(
                            isCurrent ? Icons.music_note_rounded : Icons.music_note_outlined,
                            color: isCurrent ? AppColors.accent : AppColors.muted,
                            size: 20,
                          ),
                          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: isCurrent ? AppColors.accent : AppColors.text, fontSize: 14, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400)),
                          subtitle: Text('${song.artist} · ${song.durationFormatted}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          onTap: () {
                            Navigator.pop(ctx);
                            final songList = songs;
                            notifier.setPlaylist(songList);
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
  final String? label;
  final VoidCallback onTap;
  const _SmallBtn({required this.icon, this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: AppColors.muted),
            if (label != null) ...[
              const SizedBox(height: 2),
              Text(label!, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
            ],
          ],
        ),
      ),
    );
  }
}

class _LargeBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _LargeBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        icon: Icon(icon, size: 36, color: AppColors.text),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
