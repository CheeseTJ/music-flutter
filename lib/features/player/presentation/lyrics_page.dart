import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../data/models/song.dart';
import '../../player/providers/player_provider.dart';

class LyricsPage extends ConsumerStatefulWidget {
  final Song song;
  const LyricsPage({super.key, required this.song});

  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage> {
  final ScrollController _scrollCtrl = ScrollController();
  int _lastIdx = -1;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  static const double _kItemHeight = 56;

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
    final lyric = notifier.lyric;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textP = PearlColors.textPrimary(isDark);
    final textS = PearlColors.textSecondary(isDark);
    final accent = PearlColors.accent(isDark);

    return Scaffold(
      backgroundColor: PearlColors.bgPrimary(isDark),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 28,
              color: textP),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Lyrics',
            style: TextStyle(color: textP, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          if (lyric == null || lyric.lines.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lyrics_outlined, size: 56,
                        color: PearlColors.textDisabled(isDark)),
                    const SizedBox(height: 16),
                    Text('No lyrics available',
                        style: TextStyle(color: textS, fontSize: 16)),
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
    );
  }
}
