import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/theme/pearl_theme.dart';
import '../../../core/utils/color_extractor.dart';
import '../../../data/models/song.dart';
import '../../../core/network/itunes_cover_service.dart';
import '../../player/providers/player_provider.dart';
import '../../collection/providers/song_list_provider.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final Song song;
  const PlayerPage({super.key, required this.song});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with TickerProviderStateMixin {
  Uint8List? _cover;
  Color _bgColor = const Color(0xFF7D8CFF);
  int? _lastSongId;
  late final AnimationController _bgCtrl;
  late final AnimationController _lyricCtrl;
  late final AnimationController _fadeCtrl;
  bool _showLyrics = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 40),
    );
    _lyricCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _bgCtrl.repeat();
    _fadeCtrl.forward();
    _fetchCover(widget.song);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(playerProvider.notifier);
      if (notifier.currentSong?.id != widget.song.id) {
        notifier.play(widget.song);
      }
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _lyricCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCover(Song song) async {
    _lastSongId = song.id;
    final bytes = await const ITunesCoverService()
        .fetch(song.title, song.artist);
    if (mounted && _lastSongId == song.id && bytes != null) {
      extractDominantColor(bytes).then((c) {
        if (mounted && _lastSongId == song.id) setState(() => _bgColor = c);
      });
      setState(() => _cover = bytes);
    }
  }

  void _toggleLyrics() {
    if (_showLyrics) {
      _lyricCtrl.reverse().then((_) {
        if (mounted) setState(() => _showLyrics = false);
      });
    } else {
      setState(() => _showLyrics = true);
      _lyricCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.watch(playerProvider.notifier);
    final song = notifier.currentSong ?? widget.song;
    final isPlaying = state.isPlaying;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    if (song.id != _lastSongId) {
      _cover = null;
      _bgColor = const Color(0xFF7D8CFF);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCover(song));
    }

    return FadeTransition(
      opacity: _fadeCtrl,
      child: Scaffold(
        backgroundColor: PearlColors.bgPrimary(isDark),
        body: GestureDetector(
          onVerticalDragEnd: (details) {
            if (_showLyrics) {
              _toggleLyrics();
              return;
            }
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 500) {
              Navigator.of(context).pop();
            }
          },
          child: Stack(
            children: [
              _buildBackground(isDark, size),
              SafeArea(
                child: _buildMainContent(isDark, song, isPlaying, notifier, size),
              ),
              if (_showLyrics)
                _LyricsOverlay(
                  isDark: isDark,
                  controller: _lyricCtrl,
                  song: song,
                  onDismiss: _toggleLyrics,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackground(bool isDark, Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, child) {
        final t = _bgCtrl.value * 2 * pi;
        final hsv = HSVColor.fromColor(_bgColor);

        final c1 = hsv
            .withHue((hsv.hue + sin(t) * 15).clamp(0, 360))
            .withSaturation((hsv.saturation + cos(t * 1.3) * 0.12).clamp(0, 1))
            .withValue((hsv.value + sin(t * 0.7) * 0.08).clamp(0, 1))
            .toColor();

        final c2 = hsv
            .withHue((hsv.hue + cos(t * 1.7) * 18).clamp(0, 360))
            .withSaturation((hsv.saturation + sin(t * 0.9) * 0.1).clamp(0, 1))
            .withValue((hsv.value - 0.1 + cos(t * 1.1) * 0.06).clamp(0, 1))
            .toColor();

        return Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c1.withValues(alpha: 0.15), c2.withValues(alpha: 0.08)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(
    bool isDark,
    Song song,
    bool isPlaying,
    PlayerController notifier,
    Size size,
  ) {
    final textP = PearlColors.textPrimary(isDark);
    final textS = PearlColors.textSecondary(isDark);
    final maxArtworkSize = (size.width * 0.72).clamp(260.0, 360.0);

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: PearlColors.textDisabled(isDark),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Spacer(),

        Center(
          child: Container(
            width: maxArtworkSize,
            height: maxArtworkSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: _bgColor.withValues(alpha: 0.25),
                  blurRadius: 60,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
              child: _cover != null
                  ? Image.memory(_cover!, fit: BoxFit.cover)
                  : Container(
                      decoration: BoxDecoration(
                        color: PearlColors.glassBg(isDark),
                        borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
                      ),
                      child: Center(
                        child: Icon(Icons.music_note_rounded, size: 80,
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textP,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 15, color: textS),
        ),

        const Spacer(flex: 2),
        _CurrentLyricLine(song: song, isDark: isDark, onTap: _toggleLyrics),
        const Spacer(flex: 2),
        _ProgressBar(isDark: isDark),
        const SizedBox(height: 20),
        _PlayerControlsBar(isDark: isDark),

        const Spacer(flex: 1),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ProgressBar extends ConsumerWidget {
  final bool isDark;
  const _ProgressBar({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(playerProvider.notifier);
    final accent = PearlColors.accent(isDark);

    return StreamBuilder<Duration>(
      stream: notifier.player.positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: notifier.player.durationStream,
          builder: (context, durSnap) {
            final duration = durSnap.data ?? Duration.zero;
            final max = duration.inMilliseconds.toDouble();
            final value = position.inMilliseconds
                .toDouble()
                .clamp(0.0, max > 0 ? max : 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: accent,
                      inactiveTrackColor: PearlColors.bgTertiary(isDark),
                      thumbColor: accent,
                      overlayColor: accent.withValues(alpha: 0.12),
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape:
                          const RoundSliderOverlayShape(overlayRadius: 14),
                    ),
                    child: Slider(
                      value: value,
                      max: max > 0 ? max : 1,
                      onChanged: (v) =>
                          notifier.seekTo(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(position),
                            style: TextStyle(fontSize: 12,
                                color: PearlColors.textSecondary(isDark))),
                        Text(_fmt(duration),
                            style: TextStyle(fontSize: 12,
                                color: PearlColors.textSecondary(isDark))),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _PlayerControlsBar extends ConsumerWidget {
  final bool isDark;
  const _PlayerControlsBar({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(playerProvider.notifier);
    final state = ref.watch(playerProvider);
    final isPlaying = state.isPlaying;
    final accent = PearlColors.accent(isDark);
    final textP = PearlColors.textPrimary(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SmallBtn(
            icon: Icons.shuffle_rounded,
            selected: notifier.playMode == 2,
            isDark: isDark,
            onTap: () => notifier.togglePlayMode(),
          ),
          IconButton(
            icon: Icon(Icons.skip_previous_rounded, size: 32, color: textP),
            onPressed: () => notifier.previous(),
          ),
          GestureDetector(
            onTap: () => notifier.togglePlayPause(),
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.skip_next_rounded, size: 32, color: textP),
            onPressed: () => notifier.next(),
          ),
          _SmallBtn(
          icon: Icons.queue_music_rounded,
          selected: false,
          isDark: isDark,
          onTap: () => _showPlaylistSheet(context, ref),
        ),
        ],
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  const _SmallBtn({
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = PearlColors.accent(isDark);
    final textS = PearlColors.textSecondary(isDark);

    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        icon: Icon(icon, size: 22, color: selected ? accent : textS),
        onPressed: onTap,
      ),
    );
  }
}

class _CurrentLyricLine extends ConsumerWidget {
  final Song song;
  final bool isDark;
  final VoidCallback onTap;
  const _CurrentLyricLine({
    required this.song,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.watch(playerProvider.notifier);
    final textS = PearlColors.textSecondary(isDark);
    final accent = PearlColors.accent(isDark);

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: StreamBuilder<Duration>(
          stream: notifier.player.positionStream,
          builder: (context, snapshot) {
            if (state.lyricLoading) {
              return Center(
                child: Text('加载歌词中...',
                    style: TextStyle(fontSize: 14, color: textS)),
              );
            }

            final lyric = notifier.lyric;
            if (lyric == null || lyric.lines.isEmpty) {
              return Center(
                child: Text('暂无歌词',
                    style: TextStyle(fontSize: 14, color: textS)),
              );
            }

            final position = snapshot.data ?? Duration.zero;
            final idx = lyric.findIndex(position);

            final lines = <_LyricLineEntry>[];
            for (var i = -2; i <= 2; i++) {
              final lineIdx = idx + i;
              if (lineIdx >= 0 && lineIdx < lyric.lines.length) {
                lines.add(_LyricLineEntry(
                  text: lyric.lines[lineIdx].text,
                  isCurrent: i == 0,
                ));
              }
            }
            if (lines.isEmpty) {
              lines.add(const _LyricLineEntry(text: '...', isCurrent: true));
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(lines.length, (i) {
                final entry = lines[i];
                return Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
                  child: Text(
                    entry.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: entry.isCurrent ? 18 : 14,
                      fontWeight: entry.isCurrent ? FontWeight.w600 : FontWeight.w400,
                      color: entry.isCurrent ? accent : textS,
                      height: 1.5,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _LyricLineEntry {
  final String text;
  final bool isCurrent;
  const _LyricLineEntry({required this.text, required this.isCurrent});
}

class _LyricsOverlay extends ConsumerStatefulWidget {
  final bool isDark;
  final AnimationController controller;
  final Song song;
  final VoidCallback onDismiss;
  const _LyricsOverlay({
    required this.isDark,
    required this.controller,
    required this.song,
    required this.onDismiss,
  });

  @override
  ConsumerState<_LyricsOverlay> createState() => _LyricsOverlayState();
}

class _LyricsOverlayState extends ConsumerState<_LyricsOverlay> {
  final ScrollController _scrollCtrl = ScrollController();
  int _lastIdx = -1;
  bool _entering = true;
  static const double _kItemHeight = 56;

  void _scrollTo(int idx) {
    if (!_scrollCtrl.hasClients || idx < 0) return;
    final vp = _scrollCtrl.position.viewportDimension;
    final target = (idx * _kItemHeight) - vp / 2 + _kItemHeight / 2;
    final clamped = target.clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    if (_entering) {
      _entering = false;
      _scrollCtrl.jumpTo(clamped);
    } else {
      _scrollCtrl.animateTo(clamped,
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(playerProvider.notifier);
    final lyric = notifier.lyric;
    final isDark = widget.isDark;
    final accent = PearlColors.accent(isDark);
    final textS = PearlColors.textSecondary(isDark);
    final textD = PearlColors.textDisabled(isDark);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    final slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: widget.controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    return Positioned(
      top: statusBarHeight, left: 0, right: 0, bottom: 0,
      child: SlideTransition(
        position: slideAnim,
        child: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 300) {
              widget.onDismiss();
            }
          },
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  color: PearlColors.glassBgStrong(isDark),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: PearlColors.textDisabled(isDark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  if (lyric == null || lyric.lines.isEmpty)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lyrics_outlined, size: 56, color: textD),
                            const SizedBox(height: 16),
                            Text('暂无歌词', style: TextStyle(color: textS, fontSize: 16)),
                            if (widget.song.hasLyric)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text('纯音乐，请欣赏',
                                    style: TextStyle(color: textD, fontSize: 13)),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: StreamBuilder<Duration>(
                        stream: notifier.player.positionStream,
                        builder: (context, snapshot) {
                          final idx = lyric.findIndex(snapshot.data ?? Duration.zero);
                          if (idx != _lastIdx && idx >= 0) {
                            _lastIdx = idx;
                            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(idx));
                          }
                          return ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            itemCount: lyric.lines.length,
                            itemBuilder: (context, i) {
                              final isCurrent = i == idx;
                              return SizedBox(
                                height: _kItemHeight,
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 220),
                                    style: TextStyle(
                                      fontSize: isCurrent ? 20 : 15,
                                      fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                                      color: isCurrent ? accent : textS,
                                      letterSpacing: 0.3,
                                    ),
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
                        },
                      ),
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
}

void _showPlaylistSheet(BuildContext context, WidgetRef ref) {
  final notifier = ref.read(playerProvider.notifier);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final songs = ref.read(songListProvider).valueOrNull ?? [];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).padding.bottom;
      return Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
        decoration: BoxDecoration(
          color: PearlColors.glassBgStrong(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: PearlColors.textDisabled(isDark),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                '播放列表',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: PearlColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 320,
                child: songs.isEmpty
                    ? Center(
                        child: Text('暂无歌曲',
                            style: TextStyle(color: PearlColors.textSecondary(isDark))))
                    : ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (_, i) {
                          final song = songs[i];
                          final isCurrent = notifier.currentSong?.id == song.id;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Material(
                              color: isCurrent
                                  ? PearlColors.accent(isDark).withValues(alpha: 0.08)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  notifier.play(song);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isCurrent ? Icons.music_note_rounded : Icons.music_note_outlined,
                                        size: 18,
                                        color: isCurrent
                                            ? PearlColors.accent(isDark)
                                            : PearlColors.textDisabled(isDark),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: isCurrent
                                                    ? PearlColors.accent(isDark)
                                                    : PearlColors.textPrimary(isDark),
                                              ),
                                            ),
                                            Text(
                                              song.artist,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: PearlColors.textSecondary(isDark),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        song.durationFormatted,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: PearlColors.textDisabled(isDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

