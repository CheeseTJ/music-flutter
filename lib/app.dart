import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/pearl_theme.dart';
import 'core/router/app_router.dart';
import 'core/audio/audio_player_handler.dart';
import 'core/audio/notification_service.dart';
import 'core/utils/settings.dart';
import 'core/i18n/app_strings.dart';

class MusicApp extends ConsumerStatefulWidget {
  const MusicApp({super.key});

  @override
  ConsumerState<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends ConsumerState<MusicApp> {
  /// 路由只建一次。之前写在 build() 里，任何一次 MusicApp 重建都会新建 GoRouter
  /// 并重置导航状态 —— 语言切换会触发重建，正好会踩到。
  late final _router = buildRouter();

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
              title: Text(L.s.notifTitle),
              content: Text(L.s.notifBody),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    initAudioService(ref.read(audioHandlerProvider.notifier));
                  },
                  child: Text(L.s.later),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    NotificationService.openSettings();
                  },
                  child: Text(L.s.goSettings),
                ),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);
    // 文案走全局 L.s：这里把当前语言同步进去，语言一变这次 build 就会把整棵树
    // 重建一遍，所有 L.s.xxx 都拿到新语言。
    L.apply(lang);

    return MaterialApp.router(
      title: 'Music',
      theme: PearlTheme.get(Brightness.light),
      darkTheme: PearlTheme.get(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: Locale(lang == AppLang.en ? 'en' : 'zh'),
      supportedLocales: const [Locale('zh'), Locale('en')],
      // Material 自己的内置文案（对话框按钮、tooltip 等）也要跟着切
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
