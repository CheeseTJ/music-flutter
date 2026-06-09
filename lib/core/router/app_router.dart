import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/song.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/player/presentation/player_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/player',
      builder: (context, state) {
        final song = state.extra as Song;
        return PlayerPage(song: song);
      },
    ),
  ],
);
