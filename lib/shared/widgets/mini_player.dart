import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/pearl_colors.dart';
import '../../data/models/song.dart';
import '../../core/network/itunes_cover_service.dart';
import '../../features/player/providers/player_provider.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  Uint8List? _cover;
  int? _lastSongId;

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(playerProvider.notifier);
    final state = ref.watch(playerProvider);
    final song = notifier.currentSong;
    if (song == null) return const SizedBox.shrink();

    final isPlaying = state.isPlaying;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (song.id != _lastSongId) {
      _lastSongId = song.id;
      _cover = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCover(song));
    }

    return GestureDetector(
      onTap: () => context.push('/player', extra: song),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              height: 68,
              decoration: BoxDecoration(
                color: PearlColors.glassBg(isDark),
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _cover != null
                        ? Image.memory(_cover!, width: 48, height: 48, fit: BoxFit.cover)
                        : Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  PearlColors.accent(isDark),
                                  PearlColors.accent(isDark).withValues(alpha: 0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.music_note_rounded,
                              color: PearlColors.textPrimary(isDark),
                              size: 22,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PearlColors.textPrimary(isDark),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: PearlColors.textSecondary(isDark),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 36,
                    ),
                    color: PearlColors.accent(isDark),
                    onPressed: () => notifier.togglePlayPause(),
                  ),
                ],
              ),
            ),
          ),
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
