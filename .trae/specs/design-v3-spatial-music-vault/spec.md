# Spatial Music Vault — Design V3 Spec

## Why

当前 App 采用传统音乐播放器 UI 布局（Tab 栏 + 列表 + 全屏播放器），缺乏空间感和高级感。需要借鉴 Apple Music、Arc Browser、Vision Pro、Nothing 四套设计语言，将产品从"听歌工具"升级为"个人数字音乐收藏馆"。

## What Changes

- **BREAKING** 页面重命名：Library→Collection、Upload→Import、Me→Vault
- **BREAKING** 主题系统替换：删除 Aurora/Harmoniq 双主题，改为 Pearl White 单主题 + 深色模式自动适配
- **BREAKING** Tab 栏重构：从固定底部导航改为悬浮式 Tab（80% 宽度、36px 圆角、毛玻璃背景）
- **BREAKING** Mini Player 重构：嵌入 Tab 栏上方，类 Apple Music 悬浮定位
- **BREAKING** 播放器页面完全重设计：全出血封面 + 动态背景 + 歌词层叠窗口
- 新增频谱可视化（真实音频 FFT）已在前序迭代中完成，保留
- 列表项高度从 80px 提升至 92px，增加留白
- 所有圆角统一升级（16→24/28/32）
- 所有卡片增加悬浮阴影 + 玻璃材质背景

## Impact

- Affected specs: 无（首次 Spec 化设计系统）
- Affected code:
  - `lib/core/theme/` — 主题系统完全替换
  - `lib/core/router/app_router.dart` — 路由路径适配新页面名
  - `lib/features/shell/` — Shell 页面 + Tab 栏重构
  - `lib/features/home/` → 重命名为 `collection/`
  - `lib/features/upload/` → 重命名为 `import/`
  - `lib/features/profile/` → 重命名为 `vault/`
  - `lib/features/player/` — 播放器页面完全重写
  - `lib/shared/widgets/` — Mini Player、SongTile 重写

## Design Tokens

### 色彩系统 — Pearl White (推荐)

| Token | Light | Dark |
|-------|-------|------|
| `bgPrimary` | `#F6F7FB` | `#0A0C12` |
| `bgSecondary` | `#FFFFFF` | `#121722` |
| `bgTertiary` | `#EEF2F7` | `#1A1F2E` |
| `textPrimary` | `#1A1F2E` | `#E9EDF4` |
| `textSecondary` | `#6B7280` | `#8890A0` |
| `textDisabled` | `#A0A8B8` | `#556070` |
| `accent` | `#7D8CFF` | `#7D8CFF` |
| `glassBg` | `rgba(255,255,255,0.70)` | `rgba(255,255,255,0.06)` |
| `glassBgStrong` | `rgba(255,255,255,0.85)` | `rgba(255,255,255,0.10)` |

### 圆角系统

| Token | Value |
|-------|-------|
| `radiusSm` | `16` |
| `radiusMd` | `24` |
| `radiusLg` | `28` |
| `radiusXl` | `32` |
| `radiusTab` | `36` |

### 间距 / 尺寸

| Token | Value |
|-------|-------|
| `miniPlayerHeight` | `68` |
| `tabBarHeight` | `72` |
| `tabBarWidth` | `80%` |
| `tabBarBottomOffset` | `20` |
| `songTileHeight` | `92` |
| `albumArtSize` | `320` |

## ADDED Requirements

### Requirement: Pearl White 主题系统

系统 SHALL 提供单一的 Pearl White 主题，自动在浅色/深色模式之间切换。所有组件 MUST 使用 glassBg/glassBgStrong 作为半透明背景材质，配合 backdrop-filter blur 实现玻璃质感。

#### Scenario: 浅色模式
- **WHEN** 系统处于浅色模式
- **THEN** 背景为 `#F6F7FB`，卡片为白色半透明玻璃材质

#### Scenario: 深色模式
- **WHEN** 系统处于深色模式
- **THEN** 背景为 `#0A0C12`，卡片为极低透明度玻璃材质

### Requirement: 悬浮 Tab 栏

系统 SHALL 在底部提供一个悬浮式 Tab 栏，三个 Tab 为 Collection / Import / Vault。

#### Scenario: Tab 栏外观
- **WHEN** 页面渲染
- **THEN** Tab 栏宽度为屏幕 80%、高度 72px、圆角 36px、距离底部 20px、背景为 glassBg + blur 32px、带悬浮阴影

### Requirement: Mini Player 定位

系统 SHALL 在 Tab 栏上方显示 Mini Player，当无歌曲播放时隐藏。

#### Scenario: 有歌曲播放
- **WHEN** currentSong 不为 null
- **THEN** Mini Player 显示在 Tab 栏正上方，高度 68px、圆角 28px、左右 margin 16px

#### Scenario: 无歌曲播放
- **WHEN** currentSong 为 null
- **THEN** Mini Player 不渲染

### Requirement: 全出血沉浸式播放器

系统 SHALL 提供全屏播放器页面，专辑封面占据整个上半区域，背景取封面颜色生成动态 Blur + 渐变。

#### Scenario: 播放器布局
- **WHEN** 进入播放器
- **THEN** 页面上半为全宽专辑封面，下半依次为歌名/歌手、频谱可视化、进度条、播放控制、歌词入口

#### Scenario: 动态背景
- **WHEN** 专辑封面加载完成
- **THEN** 系统提取封面颜色，生成 40 秒周期的缓慢移动渐变背景

### Requirement: 歌词层叠窗口

歌词 SHALL 不再是独立全屏页面，而是从播放器底部向上滑入的覆盖层。

#### Scenario: 点击歌词入口
- **WHEN** 用户点击播放器底部歌词区域
- **THEN** 歌词窗口从底部以 Vision Pro 风格的层叠动画滑入，覆盖播放器 70% 区域，背景为强玻璃材质

### Requirement: Collection 页面

Collection 页面 SHALL 替换原 Library 页面，顶部显示 "Good Evening" 问候语和 "Your Collection"，下方依次展示 Recently Added、Albums、Artists、Tracks 分区。

### Requirement: Import 页面

Import 页面 SHALL 替换原 Upload 页面，视觉风格从"上传工具"转变为"收藏品入馆"。

### Requirement: Vault 页面

Vault 页面 SHALL 替换原 Me/Profile 页面，突出显示存储容量（如 `34.6 GB`）、同步状态（`Synced · Just Now`）、歌曲/歌词统计。

### Requirement: 歌曲列表项升级

歌曲列表项高度 SHALL 为 92px，增加封面区域和留白，圆角 24px。

## MODIFIED Requirements

### Requirement: 音频可视化（保留）

前序实现的真实 FFT 音频频谱可视化 SHALL 保留，仅调整尺寸适配新播放器布局。

## REMOVED Requirements

### Requirement: Aurora / Harmoniq 双主题

**Reason**: 被 Pearl White 单主题系统取代
**Migration**: 删除 `AuroraColors`、`HarmoniqColors`、`AppThemeMode` 枚举、`ThemeManager` 类。所有组件统一使用 Pearl White Color Tokens。
