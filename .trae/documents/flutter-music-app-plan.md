# Flutter 在线音乐 App 开发计划

## 1. 项目概览

| 项目   | 说明                       |
| ---- | ------------------------ |
| 项目名称 | music-flutter            |
| 目标平台 | Android + iOS            |
| 音乐来源 | 在线音乐 API 流媒体             |
| 核心功能 | 基础播放控制、播放列表管理、歌词显示、搜索与发现 |

## 2. 当前状态分析

* 项目目录当前为空，需从零创建 Flutter 项目。

* 无现有代码、无依赖、无架构约束。

## 3. 技术选型

| 领域   | 技术方案                              | 理由                       |
| ---- | --------------------------------- | ------------------------ |
| 状态管理 | **Riverpod**                      | 编译时安全、无 context 依赖、测试友好  |
| 路由   | **go\_router**                    | 声明式路由，支持深层链接             |
| 音频播放 | **just\_audio**                   | 跨平台音频播放，支持流媒体、后台播放       |
| 网络请求 | **dio**                           | 拦截器、取消、超时等能力丰富           |
| 数据层  | **retrofit + json\_serializable** | 类型安全 API 调用 + 自动序列化      |
| 本地缓存 | **hive**                          | 轻量 NoSQL，适合缓存音乐列表/歌词     |
| 歌词解析 | 自研 LRC 解析器                        | LRC 格式简单，不引入额外依赖         |
| 后台播放 | **audio\_service**                | Android/iOS 通知栏控制 + 后台播放 |
| 图标   | **cupertino\_icons**              | 同时满足 Material + iOS 风格   |

## 4. 项目目录结构

```
music-flutter/
├── lib/
│   ├── main.dart                    # 应用入口
│   ├── app.dart                     # MaterialApp 配置
│   ├── core/
│   │   ├── theme/                   # 主题定义
│   │   ├── router/                  # go_router 路由配置
│   │   ├── constants/               # 常量（API 地址等）
│   │   └── utils/                   # 工具函数
│   ├── data/
│   │   ├── models/                  # 数据模型（Song, Playlist, Lyric 等）
│   │   ├── repositories/            # 数据仓库实现
│   │   ├── datasources/             # 远程/本地数据源
│   │   └── services/                # API 服务定义
│   ├── features/
│   │   ├── player/                  # 播放器模块
│   │   │   ├── presentation/        # UI 页面 + Widget
│   │   │   ├── providers/           # Riverpod providers
│   │   │   └── widgets/             # 播放器组件
│   │   ├── playlist/                # 播放列表模块
│   │   ├── search/                  # 搜索发现模块
│   │   ├── lyric/                   # 歌词模块
│   │   └── home/                    # 首页模块
│   └── shared/
│       └── widgets/                 # 公共组件（歌曲卡片等）
├── assets/
│   ├── fonts/
│   └── images/
├── android/
├── ios/
├── pubspec.yaml
└── test/
```

## 5. 功能模块详细设计

### 5.1 音乐播放器模块 (`features/player`)

**核心能力：**

* 在线流媒体播放（URL 直链）

* 播放/暂停、上一首/下一首、进度拖拽

* 播放模式切换（列表循环、单曲循环、随机播放）

* 后台播放 + 通知栏控制（audio\_service）

* 迷你播放器（底部常驻条）

**关键文件：**

* `lib/features/player/providers/player_provider.dart` — 播放状态管理（当前歌曲、进度、状态）

* `lib/features/player/providers/audio_player_provider.dart` — just\_audio 封装

* `lib/features/player/presentation/player_page.dart` — 全屏播放页

* `lib/features/player/widgets/mini_player.dart` — 迷你播放器

* `lib/features/player/widgets/player_controls.dart` — 播放控制按钮组

* `lib/features/player/widgets/progress_bar.dart` — 可拖拽进度条

### 5.2 播放列表模块 (`features/playlist`)

**核心能力：**

* 创建 / 编辑 / 删除播放列表

* 向播放列表添加 / 移除歌曲

* 收藏歌曲到「我喜欢」

**关键文件：**

* `lib/features/playlist/providers/playlist_provider.dart`

* `lib/features/playlist/presentation/playlist_page.dart` — 播放列表页

* `lib/features/playlist/presentation/playlist_detail_page.dart` — 播放列表详情

### 5.3 歌词模块 (`features/lyric`)

**核心能力：**

* 解析 LRC 歌词格式

* 歌词逐行同步滚动

* 当前行高亮显示

**关键文件：**

* `lib/core/utils/lrc_parser.dart` — LRC 解析器

* `lib/features/lyric/widgets/lyric_view.dart` — 歌词滚动视图

* `lib/features/lyric/providers/lyric_provider.dart`

### 5.4 搜索与发现模块 (`features/search`)

**核心能力：**

* 关键词搜索歌曲

* 搜索结果列表展示

* 点击结果直接播放

* 首页推荐 / 热门歌曲

**关键文件：**

* `lib/features/search/providers/search_provider.dart`

* `lib/features/search/presentation/search_page.dart`

## 6. 数据模型（预估）

```dart
// Song — 歌曲
class Song {
  String id;
  String title;        // 歌名
  String artist;       // 艺术家
  String album;        // 专辑
  String coverUrl;     // 封面图
  String audioUrl;     // 播放地址
  String? lyricUrl;    // 歌词地址
  Duration? duration;  // 时长
}

// Playlist — 播放列表
class Playlist {
  String id;
  String name;
  String? coverUrl;
  List<Song> songs;
}

// LyricLine — 歌词行
class LyricLine {
  Duration timestamp;
  String text;
}
```

## 7. 数据流架构

```
UI Layer (Pages / Widgets)
    ↕ 读取 / 修改
Providers (Riverpod — 状态管理)
    ↕ 调用
Repositories (数据仓库 — 统一数据访问)
    ↕
DataSources (Remote: Dio API / Local: Hive)
    ↕
外部音乐 API
```

## 8. 音乐 API 方案

由于商业音乐 API（QQ音乐/网易云）需要版权授权，开发阶段建议使用社区维护的 **NeteaseCloudMusicApi**（Node.js 开源项目）作为后端代理：

* 本地或服务器部署 NeteaseCloudMusicApi

* Flutter App 通过 dio 调用该 API 获取歌曲信息、播放地址、歌词

* 接口示例：`/search`, `/song/url`, `/lyric`, `/playlist/detail`

> 注：该 API 仅供学习用途，上架应用商店需自行获取版权授权。

## 9. 实施步骤（共 8 步）

| 步骤         | 任务                                             | 预估文件/改动数 |
| ---------- | ---------------------------------------------- | -------- |
| **Step 1** | 创建 Flutter 项目 + 配置 pubspec.yaml 依赖             | \~2 文件   |
| **Step 2** | 搭建 core 层（主题、路由、常量、工具）                         | \~5 文件   |
| **Step 3** | 定义数据模型（Song, Playlist, LyricLine）+ JSON 序列化    | \~4 文件   |
| **Step 4** | 实现 data 层（API Service, Repository, DataSource） | \~5 文件   |
| **Step 5** | 实现播放器模块（just\_audio + audio\_service + UI）     | \~8 文件   |
| **Step 6** | 实现播放列表模块（创建/编辑/收藏）                             | \~4 文件   |
| **Step 7** | 实现搜索与发现模块                                      | \~3 文件   |
| **Step 8** | 实现歌词模块（LRC 解析器 + 同步滚动 UI）                      | \~3 文件   |

## 10. 验证方式

* `flutter analyze` — 静态分析无 error

* `flutter test` — 核心逻辑单元测试通过

* `flutter run` — Android / iOS 真机或模拟器功能验证

* 核心场景验收：

  1. 搜索歌曲 → 显示结果列表
  2. 点击歌曲 → 开始播放 + 进度条走动
  3. 播放中切到后台 → 通知栏可控制
  4. 创建播放列表 → 添加歌曲 → 列表中选择播放
  5. 播放时查看歌词 → 歌词同步滚动

## 11. 关键决策

* 不引入用户系统（登录/注册），降低初期复杂度。后续可增量添加。

* 迷你播放器通过 Riverpod 全局共享播放状态，不依赖路由传参。

* 歌词解析采用同步方式（LRC 文本量小），不涉及异步解析。

* 使用 Material Design 3 作为 UI 框架，兼顾双平台视觉一致性。

