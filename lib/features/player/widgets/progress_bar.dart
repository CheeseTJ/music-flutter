import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../player/providers/player_provider.dart';

class ProgressBar extends ConsumerWidget {
  const ProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(playerProvider.notifier);
    final isDark = ref.watch(themeProvider).isDark;
    final activeColor = isDark ? AuroraColors.gradientStart : HarmoniqColors.blue;
    final inactiveColor = isDark ? AuroraColors.surface : HarmoniqColors.aux;

    return StreamBuilder<Duration>(
      stream: notifier.player.positionStream,
      builder: (context, positionSnap) {
        final position = positionSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(
          stream: notifier.player.durationStream,
          builder: (context, durationSnap) {
            final duration = durationSnap.data ?? Duration.zero;
            final max = duration.inMilliseconds.toDouble();
            final value = (position.inMilliseconds.toDouble()).clamp(0.0, max > 0 ? max : 1).toDouble();

            return Row(
              children: [
                SizedBox(width: 44,
                    child: Text(_fmt(position),
                        style: TextStyle(fontSize: 13,
                            color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary))),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: activeColor,
                      inactiveTrackColor: inactiveColor,
                      thumbColor: activeColor,
                      overlayColor: activeColor.withOpacity(0.12),
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    ),
                    child: Slider(
                      value: value,
                      max: max > 0 ? max : 1,
                      onChanged: (v) => notifier.seekTo(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                ),
                SizedBox(width: 44,
                    child: Text(_fmt(duration),
                        style: TextStyle(fontSize: 13,
                            color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary),
                        textAlign: TextAlign.end)),
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
