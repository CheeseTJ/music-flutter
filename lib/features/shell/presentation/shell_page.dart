import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/song.dart';
import '../../../core/network/itunes_cover_service.dart';
import '../../player/providers/player_provider.dart';

class ShellPage extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerProvider);
    final notifier = ref.watch(playerProvider.notifier);
    final hasSong = notifier.currentSong != null;

    return Scaffold(
      body: SafeArea(
        top: true,
        child: Column(
          children: [
            Expanded(child: navigationShell),
            if (hasSong) _MiniPlayer(notifier: notifier, state: playerState),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.music_note_rounded), label: '音乐'),
          BottomNavigationBarItem(icon: Icon(Icons.upload_rounded), label: '上传'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), label: '我的'),
        ],
      ),
    );
  }
}

class _MiniPlayer extends ConsumerStatefulWidget {
  final PlayerController notifier;
  final PlayerState state;
  const _MiniPlayer({required this.notifier, required this.state});

  @override
  ConsumerState<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<_MiniPlayer> {
  Uint8List? _cover;
  int? _lastSongId;

  @override
  Widget build(BuildContext context) {
    final song = widget.notifier.currentSong!;
    final isPlaying = widget.state.isPlaying;

    if (song.id != _lastSongId) {
      _lastSongId = song.id;
      _cover = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCover(song));
    }

    return GestureDetector(
      onTap: () => GoRouter.of(context).push('/player', extra: song),
      child: Container(
        height: 64,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.subtle, width: 0.5)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _cover != null
                  ? Image.memory(_cover!, width: 44, height: 44, fit: BoxFit.cover)
                  : Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.music_note, color: AppColors.accent, size: 22),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: AppColors.accent),
              onPressed: () => widget.notifier.togglePlayPause(),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next_rounded, color: AppColors.text),
              onPressed: () => widget.notifier.next(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _fetchCover(Song song) async {
    final bytes = await const ITunesCoverService().fetch(song.title, song.artist);
    if (mounted && song.id == _lastSongId) {
      setState(() => _cover = bytes);
    }
  }
}
