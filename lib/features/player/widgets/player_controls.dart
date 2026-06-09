import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/player_provider.dart';

class PlayerControls extends ConsumerWidget {
  const PlayerControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playerProvider);
    final notifier = ref.watch(playerProvider.notifier);
    final isPlaying = state == PlayerState.playing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            notifier.playMode == 1 ? Icons.repeat_one : Icons.repeat,
            size: 22,
          ),
          onPressed: () => notifier.togglePlayMode(),
          tooltip: notifier.playModeLabel,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 36),
          onPressed: () => notifier.previous(),
        ),
        const SizedBox(width: 12),
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              size: 34,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            onPressed: () => notifier.togglePlayPause(),
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(Icons.skip_next, size: 36),
          onPressed: () => notifier.next(),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.shuffle, size: 22),
          onPressed: () => notifier.togglePlayMode(),
        ),
      ],
    );
  }
}
