import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/pearl_colors.dart';
import '../../core/theme/pearl_elevation.dart';
import '../../data/models/song.dart';
import '../../core/network/platform_cover_service.dart';
import '../../features/player/providers/player_provider.dart';
import 'pearl_cover.dart';

class MiniPlayer extends ConsumerStatefulWidget {
  const MiniPlayer({super.key});

  @override
  ConsumerState<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends ConsumerState<MiniPlayer> {
  String? _coverUrl;
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
      _coverUrl = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCover(song));
    }

    return GestureDetector(
      onTap: () => context.push('/player', extra: song),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          // 阴影画在 ClipRRect 之外，否则会被裁掉（浮层用同一套表面令牌）
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PearlElevation.radius(PearlLayer.float)),
            boxShadow: PearlElevation.shadow(PearlLayer.float, isDark),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(PearlElevation.radius(PearlLayer.float)),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: 68,
                decoration: BoxDecoration(
                  color: PearlElevation.fill(PearlLayer.float, isDark),
                  borderRadius: BorderRadius.circular(PearlElevation.radius(PearlLayer.float)),
                  border: PearlElevation.outline(PearlLayer.float, isDark),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _coverUrl != null
                          ? Image.network(
                              _coverUrl!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => PearlCover(
                                  isDark: isDark,
                                  size: PearlCoverSize.nowPlaying),
                            )
                          : PearlCover(isDark: isDark, size: PearlCoverSize.nowPlaying),
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
      ),
    );
  }

  Future<void> _fetchCover(LocalSong song) async {
    final url = await const PlatformCoverService().fetch(song.type, song.title, song.artist);
    if (mounted && song.id == _lastSongId) {
      setState(() => _coverUrl = url);
    }
  }
}
