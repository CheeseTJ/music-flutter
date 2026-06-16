import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/floating_tab_bar.dart';
import '../../../shared/widgets/mini_player.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/theme/theme_provider.dart';

class ShellPage extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(playerProvider.notifier);
    final hasSong = notifier.currentSong != null;
    final isDark = ref.watch(themeProvider).isDark;

    return Scaffold(
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            Expanded(child: navigationShell),
            if (hasSong) const MiniPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom > 0
              ? 0
              : 8,
        ),
        child: SizedBox(
          height: 86 + 16 + 8,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                bottom: 0,
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: FloatingTabBar(
                    currentIndex: navigationShell.currentIndex,
                    isDark: isDark,
                    onTap: (index) {
                      navigationShell.goBranch(
                        index,
                        initialLocation: index == navigationShell.currentIndex,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
