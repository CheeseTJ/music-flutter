import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' hide PlayerState;
import '../../../core/theme/app_colors.dart';
import '../../../data/models/song.dart';
import '../../../data/models/lrc_parser.dart';
import '../../player/providers/player_provider.dart';
import '../../player/widgets/player_controls.dart';
import '../../../core/network/itunes_cover_service.dart';

class PlayerPage extends ConsumerStatefulWidget {
  final Song song;
  const PlayerPage({super.key, required this.song});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(playerProvider.notifier);
      if (notifier.currentSong?.id != widget.song.id ||
          notifier.player.processingState != ProcessingState.ready) {
        notifier.play(widget.song);
      }
    });
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
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

    return Scaffold(
      backgroundColor: AppColors.deep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(song.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text)),
            Text('${song.artist} · ${song.album}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _Artwork(isPlaying: isPlaying, controller: _rotateCtrl, song: song),
            const SizedBox(height: 32),
            _LyricView(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: _CompactProgressBar(),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: PlayerControls(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Artwork extends ConsumerStatefulWidget {
  final bool isPlaying;
  final AnimationController controller;
  final Song song;
  const _Artwork({required this.isPlaying, required this.controller, required this.song});

  @override
  ConsumerState<_Artwork> createState() => _ArtworkState();
}

class _ArtworkState extends ConsumerState<_Artwork> {
  Uint8List? _cover;

  @override
  void initState() {
    super.initState();
    _fetchCover();
  }

  @override
  void didUpdateWidget(covariant _Artwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _cover = null;
      _fetchCover();
    }
  }

  Future<void> _fetchCover() async {
    final bytes = await const ITunesCoverService().fetch(widget.song.title, widget.song.artist);
    if (mounted) setState(() => _cover = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: widget.controller,
      child: Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(180),
          gradient: const LinearGradient(
            colors: [Color(0xFF2A2015), Color(0xFF141720), Color(0xFF1A1520)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(widget.isPlaying ? 0.2 : 0),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipOval(
          child: _cover != null
              ? Image.memory(_cover!, fit: BoxFit.cover, width: 260, height: 260)
              : Center(
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.deep,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Icon(Icons.music_note_rounded, size: 36, color: AppColors.accent.withOpacity(0.7)),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CompactProgressBar extends ConsumerWidget {
  const _CompactProgressBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(playerProvider.notifier);
    final theme = Theme.of(context);

    return StreamBuilder<Duration>(
      stream: notifier.player.positionStream,
      builder: (context, posSnap) {
        final position = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: notifier.player.durationStream,
          builder: (context, durSnap) {
            final duration = durSnap.data ?? Duration.zero;
            final max = duration.inMilliseconds.toDouble();
            final value = (position.inMilliseconds.toDouble()).clamp(0.0, max > 0 ? max : 1) as double;

            return Column(
              children: [
                SliderTheme(
                  data: theme.sliderTheme.copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  ),
                  child: Slider(
                    value: value,
                    max: max > 0 ? max : 1,
                    onChanged: (v) => notifier.seekTo(Duration(milliseconds: v.toInt())),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(position), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    Text(_fmt(duration), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
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
    return '${d.inMinutes}:$m';
  }
}

class _LyricView extends ConsumerStatefulWidget {
  const _LyricView();

  @override
  ConsumerState<_LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends ConsumerState<_LyricView> {
  final ScrollController _scrollCtrl = ScrollController();
  int _lastIdx = -1;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  static const double _kItemHeight = 54;

  void _scrollTo(int idx) {
    if (!_scrollCtrl.hasClients || idx < 0) return;
    final vp = _scrollCtrl.position.viewportDimension;
    final target = (idx * _kItemHeight) - vp / 2 + _kItemHeight / 2;
    final clamped = target.clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(clamped,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(playerProvider.notifier);
    final state = ref.watch(playerProvider);
    final lyric = notifier.lyric;

    if (state.lyricLoading) {
      return _SkeletonView();
    }

    if (state.lyricFailed) {
      return const Expanded(
        child: Center(
          child: Text('暂无歌词', style: TextStyle(color: AppColors.subtle, fontSize: 14)),
        ),
      );
    }

    if (lyric == null || lyric.lines.isEmpty) {
      return _SkeletonView();
    }

    return _LyricList(
      scrollCtrl: _scrollCtrl,
      itemHeight: _kItemHeight,
      lyric: lyric,
      lastIdx: _lastIdx,
      onIdxChanged: (idx) {
        _lastIdx = idx;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(idx));
      },
      notifier: notifier,
    );
  }
}

class _SkeletonView extends StatefulWidget {
  @override
  State<_SkeletonView> createState() => _SkeletonViewState();
}

class _SkeletonViewState extends State<_SkeletonView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final alpha = (0.12 + 0.10 * (1 + _ctrl.value)).clamp(0.08, 0.28);
          final color = AppColors.accent.withOpacity(alpha);

          return ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            itemCount: 6,
            prototypeItem: const SizedBox(height: 54),
            itemBuilder: (context, i) {
              final w = 170.0 + (i % 2 == 0 ? 50 : -30).toDouble();
              return SizedBox(
                height: 54,
                child: Center(
                  child: Container(
                    width: w,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _LyricList extends StatelessWidget {
  final ScrollController scrollCtrl;
  final double itemHeight;
  final LrcParser lyric;
  final int lastIdx;
  final ValueChanged<int> onIdxChanged;
  final PlayerController notifier;

  const _LyricList({
    required this.scrollCtrl,
    required this.itemHeight,
    required this.lyric,
    required this.lastIdx,
    required this.onIdxChanged,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context) {
    final lines = lyric.lines;
    return Expanded(
      child: StreamBuilder<Duration>(
        stream: notifier.player.positionStream,
        builder: (context, snapshot) {
          final idx = lyric.findIndex(snapshot.data ?? Duration.zero);

          if (idx != lastIdx && idx >= 0) {
            onIdxChanged(idx);
          }

          return ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: lines.length,
            prototypeItem: SizedBox(
              height: itemHeight,
              child: const Center(
                child: Text('测', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
            itemBuilder: (context, i) {
              final isCurrent = i == idx;
              return SizedBox(
                height: itemHeight,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: isCurrent ? 4 : 1),
                    child: Text(
                      lines[i].text,
                      softWrap: true,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isCurrent ? 17 : 14,
                        fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                        color: isCurrent ? AppColors.accent : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
