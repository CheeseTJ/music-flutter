# music_app

A new Flutter project.

## 锁屏 / 控制中心的媒体播控：厂商白名单问题

**通知栏播控**是 Android 标准能力（`MediaSession` + `MediaStyle`），我们已完整适配，实测
`dumpsys` 每一项都正确：会话 `active=true`、`flags=7`（媒体按键 + 传输控制 + 队列）、
`PlaybackState` 含完整 actions/进度/倍速、`MediaMetadata` 含歌名/歌手/专辑/封面；通知
`category=transport`、`vis=PUBLIC`、三个按钮 + 进度条；系统已把它选为 **Media button
session**，所以蓝牙/耳机按键正常。

**锁屏播控卡片**和**控制中心媒体卡片**在各家国产系统上不是 AOSP 那套实现，而是厂商自己的，
且多数按**白名单**放行：

| 系统 | 锁屏 / 控制中心播控 | 依据 |
|---|---|---|
| 小米 HyperOS | **开放** —— 按原生 MediaSession 适配即可 | 官方文档：「控制中心内的小米妙播播控，基于安卓原生 Media Session 能力实现，音频应用适配 Media Session 即可，众多知名三方应用均已适配」 |
| 华为 HarmonyOS | **白名单** | 官网《音频播控中心支持应用清单》列出支持应用（华为音乐、QQ音乐、网易云音乐、酷狗等），并写明「逐步与相关音频应用**合作**」 |
| vivo OriginOS | **白名单**（原子随身听），名单存在 `Settings.System#musicwidget_list_pkg_type_key` | 社区已定位该配置键，改动需 root/adb |
| OPPO ColorOS | **白名单**（媒体流体云），名单在 `com.oplus.mediacontroller` 内 | 社区模块 Asteria 专用于往该白名单加包名 |

### 结论

非白名单应用在华为 / vivo / OPPO 上**拿不到锁屏播控卡片，这不是代码问题，改代码无解**。

具体地：**不要**为了这个问题去 fork `audio_service` 补 `setCategory` 或 `setFlags` ——
2026-09 已在 HarmonyOS 4.2.0 真机实测，这些字段本来就都是对的：

```
Media button session is com.example.music_app/media-session (userId=0)
    active=true
    flags=7
    state=PlaybackState {state=2, position=118483, ..., actions=3670015, ...}
    metadata: size=10, description=Lose Control, Hedley, Hello (Explicit)
Notification(channel=...channel.audio ... category=transport ... actions=3 vis=PUBLIC)
```

排查时也先确认这两处，避免重复走一遍：会话是否 `active`、`flags` 是否含
`TRANSPORT_CONTROLS(2)`、`PlaybackState.actions` 是否含切歌、通知是否 `category=transport`。

参考：

- [华为《手机/平板音频播控中心支持应用清单》](https://consumer.huawei.com/cn/support/content/zh-cn15940389/)
- [华为《音乐数据开放 MediaControl》](https://developer.huawei.com/consumer/cn/doc/content/mediacontrol-0000001275775133)（`packageName` 参数注：「当前仅支持指定华为音乐App」）
- [小米《小米妙播适配说明》](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=1602)
- [小米《Xiaomi HyperOS 媒体通知适配说明》](https://dev.mi.com/xiaomihyperos/documentation/detail?pId=2161)

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
