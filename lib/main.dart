import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/debug/layout_debug.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Catch ParentDataWidget errors early and dump the widget tree /
  // stack so we can locate the offending Row/Column.
  LayoutDebug.installLayoutDebugger();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: MusicApp()));
}
