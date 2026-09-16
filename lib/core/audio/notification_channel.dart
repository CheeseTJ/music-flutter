import 'package:flutter/services.dart';

/// 通知相关的原生 MethodChannel。
///
/// 过去 NotificationService 与 CustomNotificationService 各自声明了一份同样的
/// 字符串常量，同一个 channel 名写在两个文件里，改歪一处编译期发现不了，只会
/// 在运行时报 MissingPluginException。收拢到这里。
const MethodChannel notificationChannel =
    MethodChannel('com.example.music_app/notification');
