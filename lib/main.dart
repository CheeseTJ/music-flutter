import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/debug/layout_debug.dart';
import 'features/import/providers/provider_config_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LayoutDebug.installLayoutDebugger();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  ProviderConfigService.preload(); // 后台加载，不阻塞启动
  runApp(const ProviderScope(child: MusicApp()));
}
