import 'package:flutter/foundation.dart';

/// 调试辅助：拦截 ParentDataWidget 相关错误，打印触发 widget 链路，
/// 方便定位 "Row + MainAxisSize.min + Expanded" 这类隐藏 bug。
///
/// 接入方式：在 `main()` 里 `WidgetsFlutterBinding.ensureInitialized()`
/// 之后调用 [installLayoutDebugger]。
class LayoutDebug {
  static const _kParentDataKeywords = [
    'ParentDataWidget',
    'mainAxisSize',
    'ParentData',
    'RenderFlex',
    'hasSize',
  ];

  static void installLayoutDebugger() {
    if (!kDebugMode) return;

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final msg = details.exceptionAsString();
      if (_isParentDataError(msg)) {
        // 输出比 Flutter 默认更多的上下文：触发 widget 类型、当前
        // 错误栈、以及 exception.toString() 完整原文。
        debugPrint('========== LAYOUT DEBUG START ==========');
        debugPrint('Detected ParentDataWidget / RenderFlex error.');
        debugPrint('Exception: ${details.exception}');
        debugPrint('Library:  ${details.library}');
        debugPrint('Context:  ${details.context}');
        if (details.silent) {
          debugPrint('Silent:   true (suppressed by framework)');
        }
        if (details.informationCollector != null) {
          debugPrint('--- informationCollector ---');
          details.informationCollector!();
        }
        debugPrint('--- Stack (all frames) ---');
        final stack = details.stack;
        if (stack != null) {
          // 过滤出我们自己工程的栈帧，便于定位是哪个文件触发的。
          // StackTrace 不能直接 for-in，需要 toString().split('\n') 解析。
          for (final line in stack.toString().split('\n')) {
            // 仅打印 music-flutter 工程目录下的栈帧
            if (line.contains('/lib/') || line.contains(r'lib\')) {
              debugPrint('  $line');
            }
          }
        } else {
          debugPrint('  (no stack)');
        }
        debugPrint('========== LAYOUT DEBUG END ==========');
      }
      // 继续走默认处理（红色错误条），不要吞掉错误本身。
      originalOnError?.call(details);
    };
  }

  static bool _isParentDataError(String msg) {
    for (final k in _kParentDataKeywords) {
      if (msg.contains(k)) return true;
    }
    return false;
  }
}
