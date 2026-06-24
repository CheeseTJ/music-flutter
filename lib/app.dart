import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/pearl_theme.dart';
import 'core/router/app_router.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/audio/notification_service.dart';
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
    Settings.getShowUploadButton().then((value) {
      if (mounted) {
        ref.read(showUploadButtonProvider.notifier).state = value;
      }
    });
    Settings.getShowMiniPlayer().then((value) {
      if (mounted) {
        ref.read(showMiniPlayerProvider.notifier).state = value;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndInitNotification();
    });
  }

  Future<void> _checkAndInitNotification() async {
    final granted = await NotificationService.isPermissionGranted;
    debugPrint('[App] notification permission: $granted');
    if (!granted) {
      if (mounted) {
        _showNotificationPermissionDialog();
      }
    }
    initAudioService(ref.read(audioHandlerProvider.notifier));
  }

  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('需要通知权限'),
        content: const Text(
          '状态栏播放控件需要使用通知权限，请前往系统设置中开启"音乐"的通知权限。',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              initAudioService(ref.read(audioHandlerProvider.notifier));
            },
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              NotificationService.openSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
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
