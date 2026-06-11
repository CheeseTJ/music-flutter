import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/song.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/player/presentation/player_page.dart';
import '../../features/upload/presentation/upload_page.dart';
import '../../features/profile/presentation/profile_page.dart';
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
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const HomePage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/upload', builder: (_, __) => const UploadPage()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        ]),
      ],
    ),
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
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        );
      },
    ),
  ],
);
