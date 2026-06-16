import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/audio/audio_player_handler.dart';

class MusicApp extends ConsumerStatefulWidget {
  const MusicApp({super.key});

  @override
  ConsumerState<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends ConsumerState<MusicApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initAudioService(ref.read(audioHandlerProvider.notifier));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);

    return MaterialApp.router(
      title: 'Music',
      theme: theme.theme,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
