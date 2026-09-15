import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/debug/layout_debug.dart';
import 'core/i18n/app_strings.dart';
import 'core/utils/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LayoutDebug.installLayoutDebugger();

  // 语言必须在第一帧之前定下来：否则英文用户会先闪一帧中文。
  // 读取是异步的，所以 main 是 async —— 代价是启动时多一次 SharedPreferences 读。
  final lang = await _resolveLang();
  L.apply(lang);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(
    ProviderScope(
      overrides: [appLangProvider.overrideWith((ref) => lang)],
      child: const MusicApp(),
    ),
  );
}

/// 语言优先级：用户上次选择 > 系统语言（zh 开头 → 中文，其余 → 英文）
Future<AppLang> _resolveLang() async {
  final saved = await Settings.getLang();
  if (saved == 'zh') return AppLang.zh;
  if (saved == 'en') return AppLang.en;
  final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return code.startsWith('zh') ? AppLang.zh : AppLang.en;
}
