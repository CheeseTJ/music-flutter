import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/song.dart';
import '../../features/collection/presentation/home_page.dart';
import '../../features/player/presentation/player_page.dart';
import '../../features/player/presentation/lyrics_page.dart';
import '../../features/import/presentation/upload_page.dart';
import '../../features/import/presentation/search_page.dart';
import '../../features/vault/presentation/profile_page.dart';
import '../../features/history/presentation/history_page.dart';
import '../../features/shell/presentation/shell_page.dart';

final _rootKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ShellPage(navigationShell: navigationShell);
      },
      branches: [
        // Collection tab (index 0)
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const CollectionPage()),
        ]),
        // Import tab (index 1)
        StatefulShellBranch(routes: [
          GoRoute(path: '/import', builder: (_, __) => const ImportPage()),
        ]),
        // Vault tab (index 2)
        StatefulShellBranch(routes: [
          GoRoute(path: '/vault', builder: (_, __) => const VaultPage()),
        ]),
      ],
    ),
    // Now Playing (full-screen modal, not a tab)
    GoRoute(
      path: '/player',
      parentNavigatorKey: _rootKey,
      pageBuilder: (context, state) {
        final song = state.extra as Song;
        return CustomTransitionPage(
          key: state.pageKey,
          child: PlayerPage(song: song),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        );
      },
    ),
    // Lyrics (full-screen from Now Playing)
    GoRoute(
      path: '/player/lyrics',
      parentNavigatorKey: _rootKey,
      pageBuilder: (context, state) {
        final song = state.extra as Song;
        return CustomTransitionPage(
          key: state.pageKey,
          child: LyricsPage(song: song),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        );
      },
    ),
    // Play History
    GoRoute(
      path: '/history',
      parentNavigatorKey: _rootKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const PlayHistoryPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        );
      },
    ),
    // Online Search
    GoRoute(
      path: '/import/search',
      parentNavigatorKey: _rootKey,
      pageBuilder: (context, state) {
        return CustomTransitionPage(
          key: state.pageKey,
          child: const InternetSearchPage(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            );
          },
        );
      },
    ),
  ],
);
