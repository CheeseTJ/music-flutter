# Checklist

## 主题系统
- [x] PearlColors 定义所有 Color Token（bgPrimary/bgSecondary/bgTertiary/textPrimary/textSecondary/textDisabled/accent/glassBg/glassBgStrong），浅色和深色模式值正确
- [x] PearlTheme 返回完整 ThemeData，使用 Material3，圆角系统值为 16/24/28/32/36
- [x] AppBar 无边框、透明背景、无 elevation
- [x] Divider 无显式厚度边线，依靠空间区分
- [x] 主题跟随系统深色/浅色模式自动切换，无手动切换 UI
- [x] 全项目无 AuroraColors/HarmoniqColors 引用

## 悬浮 Tab 栏
- [x] Tab 栏宽度为屏幕 80%，圆角 36px，高度 72px
- [x] Tab 栏距离底部 20px
- [x] Tab 栏背景为半透明玻璃材质（glassBg + BackdropFilter blur 32px）
- [x] 三个 Tab 分别为 Collection / Import / Vault
- [x] 选中态有底部指示条（accent 色）

## Mini Player
- [x] 有歌曲播放时显示在 Tab 栏上方
- [x] 无歌曲播放时隐藏
- [x] 高度 68px，圆角 28px
- [x] 封面 48x48，歌名 + 歌手文字，播放/暂停按钮
- [x] 点击进入全屏播放器

## 播放器页面
- [x] 专辑封面全出血展示，占据页面上半区
- [x] 背景取封面颜色生成动态渐变，40 秒周期缓慢移动
- [x] 频谱可视化保留（真实 FFT 数据）
- [x] 底部显示当前歌词行，点击滑入歌词覆盖层

## 歌词层叠窗口
- [x] 删除独立 /player/lyrics 路由
- [x] 从播放器底部向上滑入，覆盖 70% 区域
- [x] 背景为强玻璃材质（glassBgStrong + blur）
- [x] 支持滚动浏览全部歌词，当前行高亮

## Collection 页面
- [x] 顶部 "Good Evening" + "Your Collection"
- [x] Recently Added / Albums / Artists / Tracks 分区
- [x] 搜索栏为玻璃悬浮样式
- [x] 歌曲列表项 92px 高度

## Import 页面
- [x] 两张玻璃卡片：Import from Web / Import Files
- [x] 格式标签玻璃风格
- [x] 上传队列项玻璃卡片

## Vault 页面
- [x] 巨大容量数字（如 34.6 GB）
- [x] 同步状态文案（Synced · Just Now）
- [x] 歌曲/歌词统计

## 路由
- [x] `/` → CollectionPage
- [x] `/import` → ImportPage
- [x] `/vault` → VaultPage
- [x] `/player` → PlayerPage（全屏模态）
- [x] `/history` → PlayHistoryPage
- [x] 无 `/player/lyrics` 路由

## 编译
- [x] `dart analyze lib` 零错误
