import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../data/models/song.dart';
import '../../player/providers/player_provider.dart';
import 'widgets/lyrics_scroller.dart';

class LyricsPage extends ConsumerStatefulWidget {
  final Song song;
  const LyricsPage({super.key, required this.song});

  @override
  ConsumerState<LyricsPage> createState() => _LyricsPageState();
}

class _LyricsPageState extends ConsumerState<LyricsPage> {
  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(playerProvider.notifier);
    final lyric = notifier.lyric;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textP = PearlColors.textPrimary(isDark);

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
      body: StreamBuilder<Duration>(
        // Use a small throttling delay so the lyrics scroller doesn't
        // recompute on every position tick.
        stream: notifier.player.positionStream,
        builder: (context, snapshot) {
          // Throttle: only rebuild if position changed by 80ms
          final pos = snapshot.data ?? Duration.zero;
          return LyricsScroller(
            lyric: lyric,
            position: pos,
          );
        },
      ),
    );
  }
}
