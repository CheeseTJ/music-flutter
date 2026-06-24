import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/animation/pearl_motion.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/theme/pearl_theme.dart';
import '../../../core/utils/color_extractor.dart';
import '../../../core/widgets/pearl_bottom_sheet.dart';
import '../../../data/models/song.dart';
import '../../../core/network/platform_cover_service.dart';
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
  String? _coverUrl;
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
      duration: PearlMotion.durationBg,
    );
    _lyricCtrl = AnimationController(
      vsync: this,
      duration: PearlMotion.durationLg,
    );
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: PearlMotion.durationMd,
    );
    _bgCtrl.repeat();
    _fadeCtrl.forward();
    _coverUrl = PlatformCoverService.getCachedUrl(
      widget.song.type, widget.song.title, widget.song.artist,
    );
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
    final id = song.id;
    _lastSongId = id;

    final url = await const PlatformCoverService().fetchUrl(
      song.type, song.title, song.artist,
    );
    if (!mounted || _lastSongId != id) return;
    setState(() => _coverUrl = url);

    if (url != null) {
      _extractColorFromUrl(url, id);
    } else {
      // Local song: tint the background animation to match the gradient
      // cover so the player feels visually coherent.
      _bgColor = _GradientCover.colorsFor(song.title).first;
    }
  }

  Future<void> _extractColorFromUrl(String url, int songId) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      try {
        final req = await client.getUrl(Uri.parse(url));
        final resp = await req.close().timeout(const Duration(seconds: 6));
        if (resp.statusCode != 200) return;

        final bytes = await resp.fold<List<int>>(
          <int>[], (prev, chunk) => prev..addAll(chunk),
        );
        if (!mounted || _lastSongId != songId) return;
        final color = await extractDominantColor(Uint8List.fromList(bytes));
        if (mounted && _lastSongId == songId) {
          setState(() => _bgColor = color);
        }
      } finally {
        client.close();
      }
    } catch (_) {}
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
      _coverUrl = null;
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
    // NOTE: `Positioned.fill` MUST be a direct child of the surrounding
    // Stack. If it lives inside `AnimatedBuilder` / `RepaintBoundary`,
    // those `RenderProxyBox`es intercept the parent-data lookup and the
    // Positioned tries (and fails) to apply `StackParentData` to a node
    // that only accepts the default `ParentData` — which is the
    // "Incorrect use of ParentDataWidget" error you saw at runtime.
    // We therefore wrap the WHOLE subtree with Positioned.fill here,
    // so the Stack child slot gets StackParentData directly.
    return Positioned.fill(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _bgCtrl,
          builder: (context, child) {
            // Use a ColorTween to smoothly transition between the previous
            // extracted color and the latest one, avoiding hard cuts when
            // a new track's cover arrives.
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

            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    c1.withValues(alpha: 0.15),
                    c2.withValues(alpha: 0.08)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            );
          },
        ),
      ),
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
              child: _coverUrl != null
                  ? CachedNetworkImage(
                      imageUrl: _coverUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _GradientCover(
                        title: song.title,
                        radius: PearlTheme.radiusXl,
                        isDark: isDark,
                      ),
                      errorWidget: (_, __, ___) => _GradientCover(
                        title: song.title,
                        radius: PearlTheme.radiusXl,
                        isDark: isDark,
                      ),
                    )
                  : _GradientCover(
                      title: song.title,
                      radius: PearlTheme.radiusXl,
                      isDark: isDark,
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
            icon: state.playMode == 2 ? Icons.shuffle_rounded
                : state.playMode == 1 ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            selected: state.playMode != 0,
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
              child: Center(
                // AnimatedSwitcher smoothly cross-fades between play/pause
                // icons instead of swapping them instantly.
                child: AnimatedSwitcher(
                  duration: PearlMotion.durationSm,
                  switchInCurve: PearlMotion.standard,
                  switchOutCurve: PearlMotion.standardIn,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    key: ValueKey<bool>(isPlaying),
                    size: 36,
                    color: Colors.white,
                  ),
                ),
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

class _CurrentLyricLine extends ConsumerStatefulWidget {
  final Song song;
  final bool isDark;
  final VoidCallback onTap;
  const _CurrentLyricLine({
    required this.song,
    required this.isDark,
    required this.onTap,
  });

  @override
  ConsumerState<_CurrentLyricLine> createState() => _CurrentLyricLineState();
}

class _CurrentLyricLineState extends ConsumerState<_CurrentLyricLine> {
  int _prevIdx = -1;
  int _direction = 0;

  static const double _kLyricPreviewHeight = 160;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.watch(playerProvider.notifier);
    final isDark = widget.isDark;
    final textS = PearlColors.textSecondary(isDark);
    final accent = PearlColors.accent(isDark);

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: _kLyricPreviewHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: StreamBuilder<Duration>(
            stream: notifier.player.positionStream,
            builder: (context, snapshot) {
              final lyric = notifier.lyric;

              // 1. Lyric loaded with lines → show lyric group
              // 2. lyricFailed → confirmed no lyric
              // 3. Otherwise (lyric null, not failed) → still loading
              final Widget child;
              Key groupKey = const ValueKey<String>('lyric-loading');

              if (lyric != null && lyric.lines.isNotEmpty) {
                final position = snapshot.data ?? Duration.zero;
                final idx = lyric.findIndex(position);

                if (idx != _prevIdx) {
                  _direction = idx > _prevIdx ? 1 : -1;
                  _prevIdx = idx;
                }

                groupKey = ValueKey<int>(idx);

                final lines = <_LyricLineEntry>[];
                for (var i = -2; i <= 2; i++) {
                  final lineIdx = idx + i;
                  if (lineIdx >= 0 && lineIdx < lyric.lines.length) {
                    lines.add(_LyricLineEntry(
                      text: lyric.lines[lineIdx].text,
                      isCurrent: i == 0,
                      offset: i,
                    ));
                  }
                }
                if (lines.isEmpty) {
                  lines.add(const _LyricLineEntry(text: '...', isCurrent: true, offset: 0));
                }

                child = Column(
                  key: groupKey,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: List.generate(lines.length, (i) {
                    final entry = lines[i];
                    return Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                      child: AnimatedDefaultTextStyle(
                        duration: PearlMotion.durationLg,
                        curve: PearlMotion.standard,
                        style: TextStyle(
                          fontSize: entry.isCurrent ? 20 : 14,
                          fontWeight: entry.isCurrent ? FontWeight.w700 : FontWeight.w400,
                          color: entry.isCurrent ? accent : textS,
                          height: 1.5,
                        ),
                        child: Text(
                          entry.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }),
                );
              } else if (state.lyricFailed) {
                child = Text('暂无歌词',
                    key: const ValueKey('lyric-empty'),
                    style: TextStyle(fontSize: 14, color: textS));
              } else {
                child = Text('加载歌词中...',
                    key: const ValueKey('lyric-loading'),
                    style: TextStyle(fontSize: 14, color: textS));
              }

              return Center(
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: PearlMotion.durationLg,
                    switchInCurve: PearlMotion.standard,
                    switchOutCurve: PearlMotion.standardIn,
                    transitionBuilder: (widget, anim) {
                      // Lyric group changes → slide transition
                      if (widget.key is ValueKey<int>) {
                        final isIncoming = widget.key == groupKey;
                        final dy = _direction >= 0 ? 0.2 : -0.2;
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: Offset(0, isIncoming ? dy : -dy),
                            end: Offset.zero,
                          ).animate(anim),
                          child: FadeTransition(opacity: anim, child: widget),
                        );
                      }
                      // Loading / empty state → fade only
                      return FadeTransition(opacity: anim, child: widget);
                    },
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LyricLineEntry {
  final String text;
  final bool isCurrent;
  final int offset;
  const _LyricLineEntry({required this.text, required this.isCurrent, this.offset = 0});
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
          duration: PearlMotion.durationLg, curve: PearlMotion.emphasized);
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
      curve: PearlMotion.standard,
      reverseCurve: PearlMotion.standardIn,
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
                                    duration: PearlMotion.durationMd,
                                    curve: PearlMotion.standard,
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

  showPearlBottomSheet(
    context: context,
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

/// Fallback cover used when no online artwork is available (typically
/// for locally-imported songs). Picks a gradient from a small palette
/// based on the title's hash and shows the first letter large in the
/// centre so each track is visually distinct.
class _GradientCover extends StatelessWidget {
  final String title;
  final double radius;
  final bool isDark;

  const _GradientCover({
    required this.title,
    required this.radius,
    required this.isDark,
  });

  static const List<List<Color>> _palette = [
    [Color(0xFF7D8CFF), Color(0xFFB18BFF)],
    [Color(0xFF44D3FF), Color(0xFF7D8CFF)],
    [Color(0xFFEC4141), Color(0xFFFF8A65)],
    [Color(0xFF31C27C), Color(0xFF66BB6A)],
    [Color(0xFFFFB74D), Color(0xFFFF8A65)],
    [Color(0xFFAB47BC), Color(0xFF7D8CFF)],
    [Color(0xFF26A69A), Color(0xFF44D3FF)],
    [Color(0xFFEF5350), Color(0xFFAB47BC)],
  ];

  /// Picks the gradient colours for [title]. Exposed as a static helper
  /// so the player page can reuse the same palette when choosing a
  /// matching background tint.
  static List<Color> colorsFor(String title) {
    if (title.isEmpty) return _palette[0];
    final hash = title.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) & 0x7fffffff);
    return _palette[hash % _palette.length];
  }

  List<Color> _colors() => colorsFor(title);

  String _letter() {
    final t = title.trim();
    if (t.isEmpty) return '♪';
    // First non-ASCII character, else first ASCII letter.
    return t.runes.first > 127 ? String.fromCharCode(t.runes.first) : t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Stack(
        children: [
          // Subtle inner highlight for depth, mimicking real artwork lighting.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
          ),
          // Faint musical note in the lower-right corner as a watermark.
          Positioned(
            right: 12,
            bottom: 8,
            child: Icon(
              Icons.music_note_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          // Song initial at the centre.
          Center(
            child: Text(
              _letter(),
              style: TextStyle(
                fontSize: 96,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.92),
                letterSpacing: -2,
                height: 1,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

