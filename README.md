<div align="center">
  <h1>Music App</h1>
  <p>个人云音乐播放器 · Flutter 客户端</p>
</div>

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3-02569B)
![Dart](https://img.shields.io/badge/Dart-%5E3.5-0175C2)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84)
![Version](https://img.shields.io/badge/version-1.2.22%2B35-blue)

</div>

## 项目定位

Android 端的个人云音乐播放器。**它本身不存储曲库**，而是把一个应用拆成两条独立的链路：

| 链路 | 后端 | 做什么 |
|---|---|---|
| **在线找歌** | [music-api](https://github.com/CheeseTJ/music-api) | 聚合多音源的搜索 / 播放直链 / 歌词 |
| **我的音乐** | [music-worker](https://github.com/CheeseTJ/music-worker) | 个人曲库：上传 / 列表 / 播放 / 删除 |

两者职责完全分离：在线搜索负责"找到并导入"，个人曲库负责"长期保存和播放"。导入后音频文件存在 Cloudflare R2 上，元数据存在 D1 里，本机只保留缓存。

## 功能

- **个人曲库** —— 列表浏览、搜索、播放、删除；支持在线搜索后一键导入，也支持本地文件直接上传
- **播放** —— 后台播放、通知栏 / 锁屏控制（`MediaSession`）、进度拖拽、倍速
- **歌词** —— 内嵌歌词与独立歌词页，`LRC` 解析 + 逐行滚动
- **封面** —— 优先读取音频内嵌封面，缺失时按平台兜底（网易云 / iTunes）
- **播放历史** —— 本地记录，可回跳
- **中英双语** —— 跟随系统语言，也可手动切换
- **应用内更新** —— 走蒲公英开放 API（国内直连、下载走国内 CDN）

## 技术栈

| 类别 | 选型 |
|---|---|
| 框架 | Flutter 3（Dart `^3.5.0`） |
| 状态管理 | `flutter_riverpod` |
| 路由 | `go_router`（`StatefulShellRoute` 双 Tab + 全屏模态播放页） |
| 音频 | `just_audio` + `audio_service` |
| 网络 | `dio` |
| 存储 | `shared_preferences`（设置 / 历史）+ `path_provider`（缓存） |
| 其他 | `cached_network_image`、`flutter_svg`、`file_picker`、`open_filex` |
| 设计系统 | 自研 `pearl_*`（主题 / 动效 / 玻璃质感 / 通用组件） |

## 快速开始

前置：Flutter 3（stable）、Android SDK、JDK 17。**运行前需要先把两个后端跑起来**，或在 `lib/core/constants/app_constants.dart` 里改成你自己的地址。

```bash
flutter pub get
flutter run                    # 连真机 / 模拟器
flutter analyze                # 静态检查
```

## 构建与发布

**本地打 release 包**（需要签名配置）：

```bash
flutter build apk --release --dart-define=PGYER_API_KEY=<你的蒲公英 API Key>
```

`PGYER_API_KEY` 用于应用内更新检查。未注入时更新检查会明确提示"未配置"，不会静默失败。

**CI 发布**：推送 `v*` tag 触发 [release.yml](.github/workflows/release.yml)，自动 analyze → 构建 APK → 创建 GitHub Release 并附包。

```bash
git tag v1.2.23 && git push origin v1.2.23
```

CI 需要这些 Secrets：`KEYSTORE_BASE64`、`KEYSTORE_PASSWORD`、`KEY_ALIAS`、`KEY_PASSWORD`、`PGYER_API_KEY`。

> ⚠️ 签名缺失会直接失败退出 —— 因为退回 debug 签名会导致每次构建签名不同，用户无法覆盖安装。

## 配置

后端地址与蒲公英 App Key 集中在 [`lib/core/constants/app_constants.dart`](lib/core/constants/app_constants.dart)：

| 常量 | 用途 |
|---|---|
| `baseUrl` | music-api 地址（搜索 / 取链 / 歌词） |
| `vaultBaseUrl` | music-worker 地址（个人曲库） |
| `appKey` | 访问 music-worker 的应用标识 |
| `pgyerApiKey` | 构建时经 `--dart-define` 注入，不入库 |

## 项目结构

```text
lib/
├─ main.dart              # 入口：先定语言再起第一帧（避免中文用户闪一帧英文）
├─ app.dart               # MaterialApp 组装
├─ core/
│  ├─ audio/              # audio_service handler、通知、通知渠道
│  ├─ constants/          # 后端地址、蒲公英配置
│  ├─ crypto/             # kgm 等加密格式解析
│  ├─ i18n/               # 中英文本地化
│  ├─ network/            # 应用更新、封面兜底服务
│  ├─ router/             # go_router 路由与转场
│  ├─ theme/              # pearl 设计系统（配色 / 高度 / 滚动）
│  ├─ utils/              # 设置、播放历史、缓存目录、取色
│  └─ widgets/            # pearl 通用组件
├─ data/
│  ├─ models/             # Song、LRC 解析
│  └─ datasources/remote/ # api_client、music_api
├─ features/
│  ├─ collection/         # 曲库主页
│  ├─ player/             # 播放页 + 歌词页
│  ├─ import/             # 在线搜索与导入
│  ├─ vault/              # 个人曲库（存储管理）
│  ├─ history/            # 播放历史
│  └─ shell/              # 底部导航壳
└─ shared/widgets/        # mini_player、song_tile、封面等跨 feature 组件
```

## 相关仓库

| 仓库 | 说明 |
|---|---|
| [music-api](https://github.com/CheeseTJ/music-api) | 多音源聚合 API（搜索 / 直链 / 歌词 / 下载） |
| [music-worker](https://github.com/CheeseTJ/music-worker) | 个人曲库后端（Cloudflare Workers + R2 + D1） |

## 已知约束

- **`objective_c` 被钉在 9.5.0**（见 [`pubspec.yaml`](pubspec.yaml) 的 `dependency_overrides`）。9.6.1 的 build hook 引用了当前 Dart SDK 不存在的 `Architecture.arm64e`，会让 `assembleRelease` 的 native assets 阶段编译失败；而 `pubspec.lock` 未入库，CI 每次全新解析都会拉到它。
- **仅 Android**（`ios: false`）。图标由 `flutter_launcher_icons` 从 `assets/icons/logo.png` 生成，Android 最低支持版本跟随 Flutter SDK 默认值（当前为 minSdk 24）。

## 免责声明

本项目仅供个人学习与技术研究使用。在线搜索能力依赖第三方公开接口，本项目不存储任何第三方音乐内容，请支持正版音乐。
