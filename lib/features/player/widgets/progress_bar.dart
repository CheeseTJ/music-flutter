import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../player/providers/player_provider.dart';

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

    return StreamBuilder<Duration>(
      stream: notifier.player.positionStream,
      builder: (context, positionSnap) {
        final position = positionSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: notifier.player.durationStream,
          builder: (context, durationSnap) {
            final duration = durationSnap.data ?? Duration.zero;
            final max = duration.inMilliseconds.toDouble();
            final value = (position.inMilliseconds.toDouble()).clamp(0.0, max > 0 ? max : 1) as double;

            return Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(_formatDuration(position), style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                ),
                Expanded(
                  child: Slider(
                    value: value,
                    max: max > 0 ? max : 1,
                    onChanged: (v) => notifier.seekTo(Duration(milliseconds: v.toInt())),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    _formatDuration(duration),
                    style: const TextStyle(color: AppColors.muted, fontSize: 13),
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
