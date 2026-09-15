import 'package:flutter/services.dart';

/// 通知相关的原生 MethodChannel。
///
/// NotificationService 与 CustomNotificationService 原来各自声明了一份同样的
/// 字符串常量。同一个 channel 名写在两个文件里，改歪一处编译期发现不了，
/// 只会在运行时报 MissingPluginException。收拢到这里。
///
/// 两个类保留各自的职责划分（权限/设置 vs 通知收发），只是共用这一个通道。
const MethodChannel notificationChannel =
    MethodChannel('com.example.music_app/notification');
