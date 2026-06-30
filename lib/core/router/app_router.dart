import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/song.dart';
import '../animation/pearl_motion.dart';
import '../../features/collection/presentation/home_page.dart';
import '../../features/player/presentation/player_page.dart';
import '../../features/player/presentation/lyrics_page.dart';
import '../../features/import/presentation/search_page.dart';
import '../../features/vault/presentation/profile_page.dart';
import '../../features/shell/presentation/shell_page.dart';
import '../../features/history/presentation/history_page.dart';

final _rootKey = GlobalKey<NavigatorState>();

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/collection',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ShellPage(navigationShell: navigationShell);
        },
        branches: [
          // Collection tab (index 0)
          StatefulShellBranch(routes: [
            GoRoute(path: '/collection', builder: (_, __) => const CollectionPage()),
          ]),
          // Vault tab (index 1) — Import is no longer a tab; the bottom
          // bar's right-side upload button opens the file picker
          // directly, and online search is reached via the search bar
          // on the home page.
          StatefulShellBranch(routes: [
            GoRoute(path: '/vault', builder: (_, __) => const VaultPage()),
          ]),
        ],
      ),
      // Now Playing (full-screen modal, slides up)
      GoRoute(
        path: '/player',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) {
          final song = state.extra;
          if (song is! Song) {
            return _invalidPage(state, 'Invalid player target');
          }
          return CustomTransitionPage(
            key: state.pageKey,
            child: PlayerPage(song: song),
            transitionDuration: PearlMotion.durationPage,
            reverseTransitionDuration: PearlMotion.durationPage,
            barrierColor: Colors.transparent,
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: PearlMotion.standard,
                  reverseCurve: PearlMotion.standardIn,
                )),
                child: child,
              );
            },
          );
        },
      ),
      // Lyrics (slides up from Now Playing)
      GoRoute(
        path: '/player/lyrics',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) {
          final song = state.extra;
          if (song is! Song) {
            return _invalidPage(state, 'Invalid lyrics target');
          }
          return CustomTransitionPage(
            key: state.pageKey,
            child: LyricsPage(song: song),
            transitionDuration: PearlMotion.durationPage,
            reverseTransitionDuration: PearlMotion.durationPage,
            barrierColor: Colors.transparent,
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: PearlMotion.standard,
                  reverseCurve: PearlMotion.standardIn,
                )),
                child: child,
              );
            },
          );
        },
      ),
      // Online Search (slides from right)
      GoRoute(
        path: '/import/search',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) {
          final initialQuery = state.extra is String ? state.extra as String : '';
          return CustomTransitionPage(
            key: state.pageKey,
            child: InternetSearchPage(initialQuery: initialQuery),
            transitionDuration: PearlMotion.durationPage,
            reverseTransitionDuration: PearlMotion.durationPage,
            barrierColor: Colors.transparent,
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: PearlMotion.standard,
                  reverseCurve: PearlMotion.standardIn,
                )),
                child: child,
              );
            },
          );
        },
      ),
      // Play History (slides from right)
      GoRoute(
        path: '/history',
        parentNavigatorKey: _rootKey,
        pageBuilder: (context, state) {
          return CustomTransitionPage(
            key: state.pageKey,
            child: const PlayHistoryPage(),
            transitionDuration: PearlMotion.durationPage,
            reverseTransitionDuration: PearlMotion.durationPage,
            barrierColor: Colors.transparent,
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: PearlMotion.standard,
                  reverseCurve: PearlMotion.standardIn,
                )),
                child: child,
              );
            },
          );
        },
      ),
    ],
  );
}

CustomTransitionPage _invalidPage(GoRouterState state, String msg) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: Scaffold(
      body: Center(
        child: Text(msg, style: const TextStyle(fontSize: 16)),
      ),
    ),
    transitionDuration: PearlMotion.durationPage,
    reverseTransitionDuration: PearlMotion.durationPage,
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
