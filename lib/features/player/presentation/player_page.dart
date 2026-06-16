import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/song.dart';
import '../../../core/network/itunes_cover_service.dart';
import '../../player/providers/player_provider.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final Song song;
  const PlayerPage({super.key, required this.song});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin {
  Uint8List? _cover;
  late final AnimationController _rotateCtrl;
  late final AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20));
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _fadeCtrl.forward();
    _fetchCover();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(playerProvider.notifier);
      if (notifier.currentSong?.id != widget.song.id) {
        notifier.play(widget.song);
      }
    });
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchCover() async {
    final bytes = await const ITunesCoverService().fetch(widget.song.title, widget.song.artist);
    if (mounted) setState(() => _cover = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerProvider);
    final notifier = ref.watch(playerProvider.notifier);
    final song = notifier.currentSong ?? widget.song;
    final isPlaying = state.isPlaying;

    if (isPlaying && !_rotateCtrl.isAnimating) {
      _rotateCtrl.repeat();
    } else if (!isPlaying && _rotateCtrl.isAnimating) {
      _rotateCtrl.stop();
    }

    final isDark = ref.watch(themeProvider).isDark;
    final bg = isDark ? AuroraColors.bgPrimary : HarmoniqColors.bg;
    final textP = isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary;
    final textS = isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary;

    return FadeTransition(
      opacity: _fadeCtrl,
      child: Scaffold(
        backgroundColor: bg,
        body: GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! > 500) {
              Navigator.of(context).pop();
            }
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Album Art (320x320) with rotation
                  ScaleTransition(
                    scale: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
                    child: RotationTransition(
                      turns: _rotateCtrl,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Container(
                          width: 320,
                          height: 320,
                          decoration: BoxDecoration(
                            gradient: isDark
                                ? const LinearGradient(colors: AuroraColors.gradient)
                                : LinearGradient(
                                    colors: [HarmoniqColors.blue.withValues(alpha: 0.3), HarmoniqColors.emphasize.withValues(alpha: 0.3)],
                                  ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? Colors.black : const Color(0x14283246)).withValues(alpha: isDark ? 0.12 : 1.0),
                                blurRadius: isDark ? 40 : 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _cover != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(32),
                                  child: Image.memory(_cover!, fit: BoxFit.cover, width: 320, height: 320),
                                )
                              : Center(
                                  child: Icon(Icons.music_note_rounded, size: 80,
                                      color: Colors.white.withValues(alpha: 0.3)),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  ScaleTransition(
                    scale: CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic),
                    child: Column(
                      children: [
                        Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textP, letterSpacing: -0.3)),
                        const SizedBox(height: 8),
                        Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 15, color: textS)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _SpectrumAnimator(isPlaying: isPlaying, isDark: isDark),
                  const SizedBox(height: 20),

                  _ProgressBar(isDark: isDark),
                  const SizedBox(height: 24),

                  _PlayerControlsBar(isDark: isDark),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () => context.push('/player/lyrics', extra: song),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lyrics_outlined, size: 18,
                            color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('Lyrics',
                            style: TextStyle(fontSize: 14,
                                color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpectrumAnimator extends StatefulWidget {
  final bool isPlaying;
  final bool isDark;
  const _SpectrumAnimator({required this.isPlaying, required this.isDark});

  @override
  State<_SpectrumAnimator> createState() => _SpectrumAnimatorState();
}

class _SpectrumAnimatorState extends State<_SpectrumAnimator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    if (widget.isPlaying) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _SpectrumAnimator old) {
    super.didUpdateWidget(old);
    if (widget.isPlaying && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.isPlaying && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const barCount = 24;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(barCount, (i) {
              final heightFactor = widget.isPlaying
                  ? (0.3 + 0.7 * (0.5 + 0.5 * sin(_ctrl.value * 2 * pi + i * 0.8)))
                  : 0.2;
              final barHeight = (4 + 28 * heightFactor).clamp(4.0, 32.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 3,
                  height: barHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isDark
                          ? [AuroraColors.gradientStart, AuroraColors.gradientEnd]
                          : [HarmoniqColors.blue.withValues(alpha: 0.6), HarmoniqColors.emphasize],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

class _ProgressBar extends ConsumerWidget {
  final bool isDark;
  const _ProgressBar({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(playerProvider.notifier);
    final activeColor = isDark ? AuroraColors.gradientStart : HarmoniqColors.blue;
    final inactiveColor = isDark ? AuroraColors.surface : HarmoniqColors.aux;

    return StreamBuilder<Duration>(
      stream: notifier.player.positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: notifier.player.durationStream,
          builder: (context, durSnap) {
            final duration = durSnap.data ?? Duration.zero;
            final max = duration.inMilliseconds.toDouble();
            final value = (position.inMilliseconds.toDouble()).clamp(0.0, max > 0 ? max : 1).toDouble();

            return Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: activeColor,
                    inactiveTrackColor: inactiveColor,
                    thumbColor: activeColor,
                    overlayColor: activeColor.withValues(alpha: 0.12),
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: value,
                    max: max > 0 ? max : 1,
                    onChanged: (v) => notifier.seekTo(Duration(milliseconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(position),
                          style: TextStyle(fontSize: 12,
                              color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary)),
                      Text(_fmt(duration),
                          style: TextStyle(fontSize: 12,
                              color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary)),
                    ],
                  ),
                ),
              ],
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _SmallBtn(icon: Icons.shuffle_rounded, selected: notifier.playMode == 2, isDark: isDark,
            onTap: () => notifier.togglePlayMode()),
        IconButton(
          icon: Icon(Icons.skip_previous_rounded, size: 32,
              color: isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary),
          onPressed: () => notifier.previous(),
        ),
        GestureDetector(
          onTap: () => notifier.togglePlayPause(),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(colors: [AuroraColors.gradientStart, AuroraColors.gradientEnd])
                  : const LinearGradient(colors: [HarmoniqColors.blue, HarmoniqColors.emphasize]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : const Color(0x4076A8FF)).withValues(alpha: isDark ? 0.12 : 1.0),
                  blurRadius: isDark ? 40 : 32,
                  offset: Offset(0, isDark ? 10.0 : 14.0),
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
          icon: Icon(Icons.skip_next_rounded, size: 32,
              color: isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary),
          onPressed: () => notifier.next(),
        ),
        _SmallBtn(
          icon: notifier.playMode == 1 ? Icons.repeat_one_rounded : Icons.repeat_rounded,
          selected: notifier.playMode == 1,
          isDark: isDark,
          onTap: () => notifier.togglePlayMode(),
        ),
      ],
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
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        icon: Icon(icon, size: 22,
            color: selected
                ? (isDark ? AuroraColors.gradientStart : HarmoniqColors.blue)
                : (isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary)),
        onPressed: onTap,
      ),
    );
  }
}
