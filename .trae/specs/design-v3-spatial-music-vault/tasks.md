# Tasks

- [x] Task 1: 创建 Pearl White 主题系统
  - [x] SubTask 1.1: 创建 `lib/core/theme/pearl_colors.dart`，定义浅色/深色模式 Color Tokens（bgPrimary, bgSecondary, bgTertiary, textPrimary, textSecondary, textDisabled, accent, glassBg, glassBgStrong）
  - [x] SubTask 1.2: 创建 `lib/core/theme/pearl_theme.dart`，定义 ThemeData（Material3, 圆角系统 16/24/28/32/36, 文字层级 headlineL/large→bodySmall, Slider/Input 主题, AppBar 无边框透明, Divider 无显式边界）
  - [x] SubTask 1.3: 创建 `lib/core/theme/theme_provider.dart` 重写为 Pearl Theme Provider，仅提供 isDark 布尔值 + ThemeData，无主题切换逻辑（跟随系统）
  - [x] SubTask 1.4: 验证编译通过（dart analyze 无错误）

- [x] Task 2: 重构 Shell 页面 + 悬浮 Tab 栏
  - [x] SubTask 2.1: 重写 `lib/features/shell/presentation/shell_page.dart`，页面体为 Column: [Expanded(导航内容), MiniPlayer区域, TabBar]
  - [x] SubTask 2.2: 重写 `lib/shared/widgets/floating_tab_bar.dart` 为悬浮式毛玻璃 Tab 栏：宽度 80%、高度 72px、圆角 36px、底部间距 20px、背景 glassBg + BackdropFilter blur 32px、Collection/Import/Vault 三个入口
  - [x] SubTask 2.3: 验证 Tab 栏外观符合设计 tokens

- [x] Task 3: 重命名并重构 Collection 页面
  - [x] SubTask 3.1: 将 `lib/features/home/` 目录重命名为 `lib/features/collection/`
  - [x] SubTask 3.2: 将 `HomePage` 类重命名为 `CollectionPage`，更新所有 import 引用
  - [x] SubTask 3.3: 更新路由表 `app_router.dart`：`/`→CollectionPage、`/import`→ImportPage、`/vault`→VaultPage
  - [x] SubTask 3.4: 重构 Collection 页面：顶部 "Good Evening" 问候语 + "Your Collection"、下方 Recently Added / Albums / Artists / Tracks 分区、搜索栏改为玻璃悬浮样式

- [x] Task 4: 重命名并重构 Import 页面
  - [x] SubTask 4.1: 将 `lib/features/upload/` 目录重命名为 `lib/features/import/`
  - [x] SubTask 4.2: 将 `UploadPage` 类重命名为 `ImportPage`，更新所有 import 引用
  - [x] SubTask 4.3: 重构 Import 页面：两张大玻璃卡片（Import from Web / Import Files）、支持格式标签改为玻璃风格、上传队列项改为玻璃卡片

- [x] Task 5: 重命名并重构 Vault 页面
  - [x] SubTask 5.1: 将 `lib/features/profile/` 目录重命名为 `lib/features/vault/`
  - [x] SubTask 5.2: 将 `MePage` 类重命名为 `VaultPage`，更新所有 import 引用
  - [x] SubTask 5.3: 重构 Vault 页面：突出巨大容量数字、同步状态文案（Synced · Just Now）、歌曲/歌词统计

- [x] Task 6: 升级 SongTile 组件
  - [x] SubTask 6.1: 重写 `lib/shared/widgets/song_tile.dart`：高度 92px、封面 56x56 圆角 16px、文字间距增加、右侧功能 icon 缩小
  - [x] SubTask 6.2: 更新 `lib/features/history/presentation/history_page.dart` 适配新 SongTile

- [x] Task 7: 重写 Mini Player
  - [x] SubTask 7.1: 重写 `lib/shared/widgets/mini_player.dart`：高度 68px、圆角 28px、玻璃背景、内容紧凑（封面 48x48 + 歌名歌手 + 播放暂停按钮）
  - [x] SubTask 7.2: 确保 Mini Player 整体布局嵌入 Shell Page（在 Tab 栏上方）

- [x] Task 8: 完全重写播放器页面
  - [x] SubTask 8.1: 重写 `lib/features/player/presentation/player_page.dart`：全出血封面布局、背景取封面颜色生成 40s 周期渐变动画、使用 AnimatedBuilder 驱动渐变位置
  - [x] SubTask 8.2: 实现封面颜色提取工具 `lib/core/utils/color_extractor.dart`（从 Uint8List 图片数据采样提取主色调）
  - [x] SubTask 8.3: 频谱可视化和底部歌词行保留，布局适配新结构

- [x] Task 9: 实现歌词层叠窗口
  - [x] SubTask 9.1: 删除独立 LyricsPage 路由（`/player/lyrics`）
  - [x] SubTask 9.2: 在播放器页面内部实现底部滑入式歌词覆盖层（AnimatedPositioned 或 showBottomSheet，覆盖 70% 区域，强玻璃背景）
  - [x] SubTask 9.3: 合并 `lyrics_page.dart` 的歌词滚动逻辑到覆盖层中

- [x] Task 10: 清理旧主题代码
  - [x] SubTask 10.1: 删除 `lib/core/theme/app_colors.dart`（AuroraColors、HarmoniqColors）
  - [x] SubTask 10.2: 删除 `lib/core/theme/app_theme.dart`（Aurora/Harmoniq ThemeData）
  - [x] SubTask 10.3: 删除 `lib/core/theme/theme_provider.dart` 中的 ThemeManager / ThemeMode 枚举
  - [x] SubTask 10.4: 全项目搜索 AuroraColors/HarmoniqColors 引用，替换为 PearlColors

- [x] Task 11: 全量编译验证
  - [x] 运行 `dart analyze lib` 确保零错误
  - [x] 确保所有路由正常工作
  - [x] 确保浅色/深色模式正确切换

# Task Dependencies

- Task 1（主题）是所有其他任务的先决条件
- Task 2（Shell + Tab）阻塞 Task 7（Mini Player）
- Task 3, 4, 5（三个页面重命名）可并行执行
- Task 6（SongTile）可与 Task 3, 4, 5 并行
- Task 8（播放器）可与 Task 3, 4, 5, 6 并行
- Task 9（歌词层叠）依赖 Task 8（播放器）
- Task 10（清理旧主题）依赖所有前序任务完成
- Task 11（验证）依赖所有任务完成
