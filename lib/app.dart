import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/pearl_theme.dart';
import 'core/router/app_router.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/utils/settings.dart';

class MusicApp extends ConsumerStatefulWidget {
  const MusicApp({super.key});

  @override
  ConsumerState<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends ConsumerState<MusicApp> {
  @override
  void initState() {
    super.initState();
    // Read the "show upload button" flag from disk before the first
    // frame is laid out, so the bottom bar is correct from the start.
    Settings.getShowUploadButton().then((value) {
      if (mounted) {
        ref.read(showUploadButtonProvider.notifier).state = value;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      initAudioService(ref.read(audioHandlerProvider.notifier));
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Music',
      theme: PearlTheme.get(Brightness.light),
      darkTheme: PearlTheme.get(Brightness.dark),
      themeMode: ThemeMode.system,
      routerConfig: buildRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}
