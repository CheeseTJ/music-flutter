// 本文件由脚本生成后人工整理：界面文案的唯一来源。
//
// 用法：在任意位置用 `L.s.xxx` 取文案（L 是全局访问点，不需要 context）；
// 语言切换时 appLangProvider 变化 -> MusicApp 重建 -> 整棵树拿到新文案。

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLang { zh, en }

/// 当前界面语言。main() 启动时按「用户上次选择 > 系统语言」写入。
final appLangProvider = StateProvider<AppLang>((ref) => AppLang.zh);

abstract class AppStrings {
  const AppStrings();
  String get notifTitle;
  String get notifBody;
  String get later;
  String get goSettings;
  String get opUpload;
  String get opLyricUpload;
  String opFailed(String op, String detail);
  String get missingToken;
  String get badFormat;
  String requestFailed(String code);
  String get noLyric;
  String get loadingLyric;
  String get instrumental;
  String get playlist;
  String get noSongs;
  String get filterDefault;
  String get filterNoLyric;
  String get filterDuplicates;
  String get filterSortByName;
  String get filterRecent;
  String get searchHint;
  String countSongs(String n);
  String get play;
  String get pause;
  String get uploadLyrics;
  String get deleteSong;
  String deleteFailed(String e);
  String get emptyTitle;
  String get emptyHint;
  String get loadFailed;
  String get retry;
  String get playAll;
  String get yourLibrary;
  String get clearHistory;
  String get clearHistoryBody;
  String get cancel;
  String get confirm;
  String get playHistory;
  String get noHistory;
  String get library;
  String get librarySub;
  String get statSongs;
  String get statLyrics;
  String get settingsTitle;
  String get showUploadButton;
  String get showUploadButtonHint;
  String get showMiniPlayer;
  String get showMiniPlayerHint;
  String get clearCoverCache;
  String get clearCoverCacheHint;
  String get aboutTitle;
  String get versionLabel;
  String get coverCacheCleared;
  String get noPgyerKey;
  String upToDate(String v);
  String get noDownloadUrl;
  String installerFailed(String msg);
  String updateAvailable(String v);
  String packageSize(String size);
  String get updateNow;
  String get collapse;
  String get platformNetease;
  String get platformKuwo;
  String get platformKugou;
  String get platformMigu;
  String importQuality(String name);
  String get unknown;
  String get playLinkFailed;
  String playFailed(String e);
  String get downloadLinkFailed;
  String trialOnly(String name);
  String trialFallback(String kbps);
  String get uploadFailed;
  String addedToLibrary(String name);
  String importFailed(String e);
  String get searchSingerHint;
  String get searchHistoryTitle;
  String get searchLocalOnline;
  String get searchLocalOnlineHint;
  String get noResult;
  String get noResultHint;
  String get localSongs;
  String get searchingOnline;
  String get onlineResults;
  String coverCacheOf(String name);
  String get noApiKey;
  String checkFailed(String e);
  String get checkBadFormat;
  String pgyerError(String code, String msg);
  String downloadFailed(String e);
  String get musicPlayback;
  String get closeMenu;
  String importDone(String ok, String failed);
  String importDoneFailed(String n);
  String importAllFailed(String n);
  String get lyricsTitle;
}

class AppStringsZh extends AppStrings {
  const AppStringsZh();
  @override
  String get notifTitle => '需要通知权限';
  @override
  String get notifBody => '状态栏播放控件需要使用通知权限，请前往系统设置中开启“音乐”的通知权限。';
  @override
  String get later => '稍后';
  @override
  String get goSettings => '去设置';
  @override
  String get opUpload => '上传';
  @override
  String get opLyricUpload => '歌词上传';
  @override
  String opFailed(String op, String detail) => '$op失败: $detail';
  @override
  String get missingToken => '缺少歌曲 token，请重新搜索';
  @override
  String get badFormat => '接口返回格式异常';
  @override
  String requestFailed(String code) => '请求失败(code=$code)';
  @override
  String get noLyric => '暂无歌词';
  @override
  String get loadingLyric => '加载歌词中...';
  @override
  String get instrumental => '纯音乐，请欣赏';
  @override
  String get playlist => '播放列表';
  @override
  String get noSongs => '暂无歌曲';
  @override
  String get filterDefault => '默认';
  @override
  String get filterNoLyric => '缺歌词';
  @override
  String get filterDuplicates => '重名筛查';
  @override
  String get filterSortByName => '按名称排序';
  @override
  String get filterRecent => '最近添加';
  @override
  String get searchHint => '搜索本地 + 在线歌曲...';
  @override
  String countSongs(String n) => '$n 首';
  @override
  String get play => '播放';
  @override
  String get pause => '暂停';
  @override
  String get uploadLyrics => '上传歌词';
  @override
  String get deleteSong => '删除歌曲';
  @override
  String deleteFailed(String e) => '删除失败: $e';
  @override
  String get emptyTitle => '还没有歌曲';
  @override
  String get emptyHint => '上传你的第一首歌吧';
  @override
  String get loadFailed => '加载失败';
  @override
  String get retry => '重试';
  @override
  String get playAll => '全部播放';
  @override
  String get yourLibrary => '我的曲库';
  @override
  String get clearHistory => '清除记录';
  @override
  String get clearHistoryBody => '将清除所有播放记录。';
  @override
  String get cancel => '取消';
  @override
  String get confirm => '确定';
  @override
  String get playHistory => '播放记录';
  @override
  String get noHistory => '暂无播放记录';
  @override
  String get library => '曲库';
  @override
  String get librarySub => '本机上的音频与歌词缓存';
  @override
  String get statSongs => '歌曲';
  @override
  String get statLyrics => '歌词';
  @override
  String get settingsTitle => '设置';
  @override
  String get showUploadButton => '显示上传按钮';
  @override
  String get showUploadButtonHint => '底栏的快捷文件选择器';
  @override
  String get showMiniPlayer => '显示迷你播放器';
  @override
  String get showMiniPlayerHint => '悬浮导航栏上方的正在播放条';
  @override
  String get clearCoverCache => '清空封面缓存';
  @override
  String get clearCoverCacheHint => '删除全部已缓存的封面图';
  @override
  String get aboutTitle => '关于';
  @override
  String get versionLabel => '版本';
  @override
  String get coverCacheCleared => '封面缓存已清空';
  @override
  String get noPgyerKey => '未配置蒲公英 API Key，无法检查更新';
  @override
  String upToDate(String v) => '已是最新版本 v$v';
  @override
  String get noDownloadUrl => '蒲公英没有返回下载地址';
  @override
  String installerFailed(String msg) => '无法调起安装器：$msg\n若提示签名冲突，请先卸载旧版本再安装';
  @override
  String updateAvailable(String v) => '可更新 v$v';
  @override
  String packageSize(String size) => '安装包 $size';
  @override
  String get updateNow => '立即更新';
  @override
  String get collapse => '收起';
  @override
  String get platformNetease => '网易云';
  @override
  String get platformKuwo => '酷我';
  @override
  String get platformKugou => '酷狗';
  @override
  String get platformMigu => '咪咕';
  @override
  String importQuality(String name) => '导入音质 · $name';
  @override
  String get unknown => '未知';
  @override
  String get playLinkFailed => '获取播放链接失败';
  @override
  String playFailed(String e) => '播放失败: $e';
  @override
  String get downloadLinkFailed => '获取下载链接失败';
  @override
  String trialOnly(String name) => '$name 仅提供试听片段（30s）';
  @override
  String trialFallback(String kbps) => '所选音质为试听片段，已自动改用完整版（${kbps}kbps）';
  @override
  String get uploadFailed => '上传失败';
  @override
  String addedToLibrary(String name) => '$name 已添加到曲库';
  @override
  String importFailed(String e) => '导入失败: $e';
  @override
  String get searchSingerHint => '搜索歌曲或歌手...';
  @override
  String get searchHistoryTitle => '搜索历史';
  @override
  String get searchLocalOnline => '搜索本地 + 在线歌曲';
  @override
  String get searchLocalOnlineHint => '同时匹配曲库和在线平台';
  @override
  String get noResult => '没有找到相关歌曲';
  @override
  String get noResultHint => '换个关键词或线路试试';
  @override
  String get localSongs => '本地歌曲';
  @override
  String get searchingOnline => '正在搜索在线';
  @override
  String get onlineResults => '在线结果';
  @override
  String coverCacheOf(String name) => '$name 的封面';
  @override
  String get noApiKey => '未配置蒲公英 API Key\n构建时缺少 --dart-define=PGYER_API_KEY';
  @override
  String checkFailed(String e) => '检查更新失败：$e';
  @override
  String get checkBadFormat => '检查更新失败：返回格式异常';
  @override
  String pgyerError(String code, String msg) => '蒲公英返回错误 code=$code $msg';
  @override
  String downloadFailed(String e) => '下载失败：$e';
  @override
  String get musicPlayback => '音乐播放';
  @override
  String get closeMenu => '关闭菜单';
  @override
  String importDone(String ok, String failed) => '$ok 个文件已导入$failed';
  @override
  String importDoneFailed(String n) => '（$n 个失败）';
  @override
  String importAllFailed(String n) => '$n 个文件导入失败';
  @override
  String get lyricsTitle => '歌词';
}

class AppStringsEn extends AppStrings {
  const AppStringsEn();
  @override
  String get notifTitle => 'Notification permission required';
  @override
  String get notifBody => 'The status-bar playback controls need notification permission. Please enable notifications for this app in system settings.';
  @override
  String get later => 'Later';
  @override
  String get goSettings => 'Open settings';
  @override
  String get opUpload => 'Upload';
  @override
  String get opLyricUpload => 'Lyric upload';
  @override
  String opFailed(String op, String detail) => '$op failed: $detail';
  @override
  String get missingToken => 'Missing song token, please search again';
  @override
  String get badFormat => 'Unexpected response format';
  @override
  String requestFailed(String code) => 'Request failed (code $code)';
  @override
  String get noLyric => 'No lyrics';
  @override
  String get loadingLyric => 'Loading lyrics…';
  @override
  String get instrumental => 'Instrumental — enjoy';
  @override
  String get playlist => 'Playlist';
  @override
  String get noSongs => 'No songs';
  @override
  String get filterDefault => 'Default';
  @override
  String get filterNoLyric => 'Missing lyrics';
  @override
  String get filterDuplicates => 'Find duplicates';
  @override
  String get filterSortByName => 'Sort by title';
  @override
  String get filterRecent => 'Recently added';
  @override
  String get searchHint => 'Search local + online…';
  @override
  String countSongs(String n) => '$n songs';
  @override
  String get play => 'Play';
  @override
  String get pause => 'Pause';
  @override
  String get uploadLyrics => 'Upload lyrics';
  @override
  String get deleteSong => 'Delete song';
  @override
  String deleteFailed(String e) => 'Delete failed: $e';
  @override
  String get emptyTitle => 'No songs yet';
  @override
  String get emptyHint => 'Upload your first song';
  @override
  String get loadFailed => 'Failed to load';
  @override
  String get retry => 'Retry';
  @override
  String get playAll => 'Play all';
  @override
  String get yourLibrary => 'Your library';
  @override
  String get clearHistory => 'Clear history';
  @override
  String get clearHistoryBody => 'This clears all play history.';
  @override
  String get cancel => 'Cancel';
  @override
  String get confirm => 'OK';
  @override
  String get playHistory => 'Play history';
  @override
  String get noHistory => 'No play history yet';
  @override
  String get library => 'Library';
  @override
  String get librarySub => 'Audio + lyric cache on this device';
  @override
  String get statSongs => 'Songs';
  @override
  String get statLyrics => 'Lyrics';
  @override
  String get settingsTitle => 'Settings';
  @override
  String get showUploadButton => 'Show upload button';
  @override
  String get showUploadButtonHint => 'Quick file picker on the bottom bar';
  @override
  String get showMiniPlayer => 'Show mini player';
  @override
  String get showMiniPlayerHint => 'Now-playing bar above the tab bar';
  @override
  String get clearCoverCache => 'Clear cover cache';
  @override
  String get clearCoverCacheHint => 'Remove all cached cover images';
  @override
  String get aboutTitle => 'About';
  @override
  String get versionLabel => 'Version';
  @override
  String get coverCacheCleared => 'Cover cache cleared';
  @override
  String get noPgyerKey => 'PGYER API key missing; cannot check for updates';
  @override
  String upToDate(String v) => 'Already up to date — v$v';
  @override
  String get noDownloadUrl => 'PGYER did not return a download URL';
  @override
  String installerFailed(String msg) => 'Could not launch the installer: $msg\nIf it reports a signature conflict, uninstall the old version first';
  @override
  String updateAvailable(String v) => 'Update available — v$v';
  @override
  String packageSize(String size) => 'Package $size';
  @override
  String get updateNow => 'Update now';
  @override
  String get collapse => 'Collapse';
  @override
  String get platformNetease => 'NetEase';
  @override
  String get platformKuwo => 'Kuwo';
  @override
  String get platformKugou => 'Kugou';
  @override
  String get platformMigu => 'Migu';
  @override
  String importQuality(String name) => 'Import quality · $name';
  @override
  String get unknown => 'Unknown';
  @override
  String get playLinkFailed => 'Failed to get playback URL';
  @override
  String playFailed(String e) => 'Playback failed: $e';
  @override
  String get downloadLinkFailed => 'Failed to get download URL';
  @override
  String trialOnly(String name) => '$name is only available as a 30s preview';
  @override
  String trialFallback(String kbps) => 'Selected quality was a preview; switched to the full track ($kbps kbps)';
  @override
  String get uploadFailed => 'Upload failed';
  @override
  String addedToLibrary(String name) => '$name added to your library';
  @override
  String importFailed(String e) => 'Import failed: $e';
  @override
  String get searchSingerHint => 'Search songs or artists…';
  @override
  String get searchHistoryTitle => 'Search history';
  @override
  String get searchLocalOnline => 'Search local + online';
  @override
  String get searchLocalOnlineHint => 'Matches both your library and online platforms';
  @override
  String get noResult => 'No matching songs';
  @override
  String get noResultHint => 'Try another keyword or source';
  @override
  String get localSongs => 'Local';
  @override
  String get searchingOnline => 'Searching online';
  @override
  String get onlineResults => 'Online results';
  @override
  String coverCacheOf(String name) => 'Cover for $name';
  @override
  String get noApiKey => 'PGYER API key missing\nBuild is missing --dart-define=PGYER_API_KEY';
  @override
  String checkFailed(String e) => 'Update check failed: $e';
  @override
  String get checkBadFormat => 'Update check failed: unexpected response format';
  @override
  String pgyerError(String code, String msg) => 'PGYER returned error code=$code $msg';
  @override
  String downloadFailed(String e) => 'Download failed: $e';
  @override
  String get musicPlayback => 'Music playback';
  @override
  String get closeMenu => 'Close menu';
  @override
  String importDone(String ok, String failed) => '$ok file(s) imported$failed';
  @override
  String importDoneFailed(String n) => ' ($n failed)';
  @override
  String importAllFailed(String n) => '$n file(s) failed to import';
  @override
  String get lyricsTitle => 'Lyrics';
}

/// 全局文案访问点。
///
/// 之所以不用 InheritedWidget + BuildContext：调用点有近百处，散落在
/// build / 回调 / service 里，逐个传 context 风险高、噪音大。这里用
/// 「全局当前语言 + 语言变化时从根部重建整棵树」换取调用点的零成本。
class L {
  L._();

  static AppStrings _current = const AppStringsZh();
  static AppStrings get s => _current;

  static void apply(AppLang lang) {
    _current = lang == AppLang.en ? const AppStringsEn() : const AppStringsZh();
  }
}
