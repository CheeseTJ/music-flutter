# 搜索页问题修复计划

## 问题概述

| # | 问题 | 严重度 | 涉及文件 |
|---|------|--------|----------|
| 1 | 播放状态不反映真实播放器状态 | 高 | search_page.dart, player_provider.dart |
| 2 | 点击按钮/Badge 缺少涟漪反馈 | 中 | search_page.dart, upload_page.dart |
| 3 | 搜索结果无法导入到本地曲库 | 中 | search_page.dart, 需新增桥接逻辑 |
| 4 | 线路筛选布局拥挤、可交互性差 | 中 | search_page.dart |

---

## 修复 1：播放状态同步

### 现状
- `search_page.dart` 的 `_playingSong` 是本地 bool，仅控制按钮 spinner
- `player_provider.dart` 的 `playUrl()` 方法将 `_currentSong` 置空（line 247），丢弃歌曲信息
- 搜索结果列表无法标记当前正在播放的歌曲

### 修改内容

**1.1 `player_provider.dart` — 新增临时播放歌曲标识**

在 `PlayerController` 中添加字段存储当前通过 `playUrl` 播放的歌曲信息：
```dart
String? _playingUrlId;  // 格式: "platform|id"
String? get playingUrlId => _playingUrlId;
```

修改 `playUrl()` 方法，增加 `platform` 和 `id` 参数：
```dart
Future<void> playUrl(String url, String title, String artist, {String? platform, String? id}) async {
  _playingUrlId = (platform != null && id != null) ? '$platform|$id' : null;
  // ... 其余不变
}
```

修改 `play(Song song)` 方法，清除 `_playingUrlId`：
```dart
Future<void> play(Song song) async {
  _playingUrlId = null;
  // ... 其余不变
}
```

**1.2 `search_page.dart` — 使用真实播放状态**

- 删除本地 `_playingSong` 字段
- 读取 `ref.watch(playerProvider.select((v) => v.phase))` 判断是否正在加载
- 读取 `ref.watch(playerProvider.notifier).playingUrlId` 判断当前播放的歌曲
- `_ResultTile` 传递 `isPlaying: songId == playingUrlId` 高亮当前歌曲
- `_doPlay` 改为：
```dart
Future<void> _doPlay(Song song) async {
  final mgr = ref.read(musicManagerProvider);
  final url = await mgr.getUrl(song);
  if (url == null || url.url.isEmpty) { /* snackbar */ return; }
  final notifier = ref.read(playerProvider.notifier);
  await notifier.playUrl(url.url, song.name, song.singer, platform: song.platform, id: song.id);
}
```

**1.3 `_ResultTile` — 支持播放中高亮**

- 新增 `isPlaying` 属性替代 `playing`
- 播放中歌曲：封面/图标区域显示动画/播放中颜色

---

## 修复 2：点击涟漪反馈

### 修改 `search_page.dart`

- `_SourceBar`（line 383）：`GestureDetector` → `Material` + `InkWell`，保留圆角
- `_LineChip`（line 485）：`GestureDetector` → `Material` + `InkWell`，保留圆角

### 修改 `upload_page.dart`

- `_ImportCard`（line 257）：`GestureDetector` → `Material` + `InkWell`

---

## 修复 3：搜索结果 → 本地入库

### 方案

搜索结果每行添加「添加到曲库」操作入口。由于导入模块的 `Song` 和本地 `Song` 是不同模型，需要：

**3.1 添加 API 端：通过 URL 下载并上传到服务器**

搜索结果的 `Song` 只有 `name`/`singer`/`id` 等信息，需要：
1. 用户点击「导入」按钮
2. 从 `musicManager` 获取播放 URL
3. 调用 API 将 URL 作为远程资源上传到后端
4. 后端下载并入库

但这需要在 `ApiClient` 中添加对应接口，考虑简化：直接在 `_ResultTile` 右侧添加「导入」按钮，点击后：
- 获取播放 URL
- 调用 `ApiClient.downloadFromUrl(url, songName, songArtist)` 将在线歌曲下载并上传到后端

**3.2 `_ResultTile` 修改**

右侧区域改为两个按钮：播放按钮 + 导入按钮（图标按钮），播放按钮保持现有功能，导入按钮新增。

**3.3 ApiClient 新增方法**

```dart
Future<void> downloadFromUrl(String url, String title, String artist) async { ... }
```

> 注：如果 API 端尚不支持此接口，可先预留 UI，用 SnackBar 提示"API 尚未支持"。

---

## 修复 4：线路筛选布局优化

### 现状

三个 chip（自动/专用/Meting）挤在一行居中排列，字号 11、padding 10x5，过小难点。

### 修改内容

**重新设计 `_LineBar` 为 segmented control 风格：**

```
┌──────────────────────────────┐
│  ● 自动（双线）  ○ 专用  ○ 兜底  │
└──────────────────────────────┘
```

- 使用 `Container` + `Row` 包裹三个等宽分段
- 每段宽度 = `(屏幕宽度 - 32) / 3`
- 选中段：accent 颜色背景 + 白色文字
- 未选中段：透明背景 + 次要文字
- 禁用段：灰色 + 不可点击
- 高度增大至 40，字号提升至 13
- 整体包裹在 `Padding(horizontal: 16)` 中

**同时修改 `_SourceBar`** — 将平台选择器的 chips 也稍微调整：
- `GestureDetector` → `Material` + `InkWell`（与修复 2 一起处理）
- 高度从 44 减到 40，与线路栏对齐

---

## 实施步骤

| 步骤 | 内容 | 文件 |
|------|------|------|
| S1 | 修改 `player_provider.dart` — 新增 `playingUrlId`，修改 `playUrl` 签名 | player_provider.dart |
| S2 | 修改 `search_page.dart` — 删除 `_playingSong`，接入真实播放状态，更新 `_doPlay` | search_page.dart |
| S3 | 修改 `_ResultTile` — 支持 `isPlaying` 高亮 + 添加「导入」按钮 | search_page.dart |
| S4 | 修改 `_SourceBar` / `_LineChip` / `_ImportCard` — 添加 InkWell 涟漪 | search_page.dart, upload_page.dart |
| S5 | 重新设计 `_LineBar` — segmented control 布局 | search_page.dart |
| S6 | 在 `ApiClient` 中添加 `downloadFromUrl` 方法 | api_client.dart |
| S7 | `flutter analyze` 验证无错误 | — |

## 验证方式

1. 搜索歌曲 → 点击播放 → 结果列表中该歌曲显示「正在播放」高亮
2. 播放另一首 → 高亮切换
3. 点击所有 chip / 卡片 → 有涟漪动画反馈
4. 点击导入按钮 → 触发下载流程
5. 线路筛选三段式布局清晰可点击
6. `flutter analyze` 零 issue
