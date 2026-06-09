import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';

class ProgressBar extends ConsumerWidget {
  const ProgressBar({super.key});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inMinutes}:$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(playerProvider.notifier);
    final theme = Theme.of(context);

    return StreamBuilder<Duration>(
      stream: notifier.player.positionStream,
      builder: (context, positionSnap) {
        final position = positionSnap.data ?? Duration.zero;

        return StreamBuilder<Duration?>(
          stream: notifier.player.durationStream,
          builder: (context, durationSnap) {
            final duration = durationSnap.data ?? Duration.zero;
            final max = duration.inMilliseconds.toDouble();
            final value = position.inMilliseconds
                .toDouble()
                .clamp(0.0, max) as double;

            return Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    _formatDuration(position),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: value,
                      max: max > 0 ? max : 1,
                      onChanged: (v) {
                        notifier.seekTo(Duration(milliseconds: v.toInt()));
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _formatDuration(duration),
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
