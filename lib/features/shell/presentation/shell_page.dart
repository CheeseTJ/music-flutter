import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../shared/widgets/floating_tab_bar.dart';
import '../../../shared/widgets/mini_player.dart';
import '../../collection/presentation/home_page.dart';
import '../../vault/presentation/profile_page.dart';
import '../../player/providers/player_provider.dart';
import '../../../core/utils/settings.dart';

class ShellPage extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;
  const ShellPage({super.key, required this.navigationShell});

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSong = ref.watch(playerProvider.notifier).currentSong != null;
    final showUploadButton = ref.watch(showUploadButtonProvider);
    final navShell = widget.navigationShell;
    final currentIndex = navShell.currentIndex;

    return Scaffold(
      backgroundColor: PearlColors.bgPrimary(isDark),
      body: Stack(
        children: [
          // Active page content with status bar safe area.
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: IndexedStack(
                index: currentIndex,
                children: const [
                  CollectionPage(),
                  VaultPage(),
                ],
              ),
            ),
          ),
          // Mini player above the floating tab bar (only when there's a song)
          if (hasSong)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _MiniPlayerHolder(),
            ),
          // Floating tab bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: FloatingTabBar(
              currentIndex: currentIndex,
              onTap: (i) {
                navShell.goBranch(i, initialLocation: i == currentIndex);
              },
              showUploadButton: showUploadButton,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPlayerHolder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // tab bar height (64) + bottom padding (16 + safeArea)
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const bottom = 64.0 + 16.0 + 8.0;
    return Padding(
      padding: EdgeInsets.only(
        left: 12, right: 12, bottom: bottom + bottomInset,
      ),
      child: const MiniPlayer(),
    );
  }
}
