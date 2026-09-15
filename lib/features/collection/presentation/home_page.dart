import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/theme/pearl_elevation.dart';
import '../../../core/theme/pearl_theme.dart';
import '../../../core/utils/playback_history.dart';
import '../../../core/utils/settings.dart';
import '../../../core/widgets/pearl_anchored_menu.dart';
import '../../../core/widgets/pearl_bottom_sheet.dart';
import '../../../core/widgets/pearl_toast.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../collection/providers/song_list_provider.dart';
import '../../player/providers/player_provider.dart';
import 'package:music_app/core/i18n/app_strings.dart';
import '../../../core/widgets/pearl_loading.dart';
import '../../../core/widgets/pearl_empty_state.dart';

enum FilterOption { all, noLyric, duplicates, sortByName, recent }

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _filterBtnKey = GlobalKey();
  bool _refreshing = false;
  FilterOption _filter = FilterOption.all;
  String _greetingText = '';
  Timer? _greetingTimer;
  bool _restored = false;
  bool _currentSongVisible = true;
  int? _pendingRestoreId; // 冷启动待恢复的歌曲 ID

  /// 当前曲目在 filtered 里的下标（-1 = 不在列表里）。
  /// 只在 build 里算一次：滚动监听器靠它做 O(1) 算术，而不是每帧遍历歌单。
  int _currentIdx = -1;

  static const double _itemHeight = 68.0;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _scheduleGreetingRefresh();
    _scrollCtrl.addListener(_checkVisibility);
    // 首帧布局完成前拿不到 viewport 高度（hasClients 为 false），
    // 所以布局后再校正一次可见性；之后由滚动监听和 build 各自负责。
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    _scrollCtrl.removeListener(_checkVisibility);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// 右上角筛选入口：玻璃锚定菜单，展开在按钮正下方
  Future<void> _openFilterMenu() async {
    final anchorContext = _filterBtnKey.currentContext;
    if (anchorContext == null) return;
    final picked = await showPearlMenu<FilterOption>(
      context: context,
      anchorContext: anchorContext,
      selected: _filter,
      entries: [
        PearlMenuEntry(
            value: FilterOption.all,
            label: L.s.filterDefault,
            icon: Icons.format_list_bulleted_rounded),
        PearlMenuEntry(
            value: FilterOption.noLyric,
            label: L.s.filterNoLyric,
            icon: Icons.lyrics_outlined),
        PearlMenuEntry(
            value: FilterOption.duplicates,
            label: L.s.filterDuplicates,
            icon: Icons.content_copy_rounded),
        PearlMenuEntry(
            value: FilterOption.sortByName,
            label: L.s.filterSortByName,
            icon: Icons.sort_by_alpha_rounded),
        PearlMenuEntry(
            value: FilterOption.recent,
            label: L.s.filterRecent,
            icon: Icons.access_time_rounded),
      ],
    );
    if (!mounted || picked == null) return;
    setState(() => _filter = picked);
  }

  void _updateGreeting() {
    final hour = DateTime.now().hour;
    setState(() {
      if (hour < 12) {
        _greetingText = 'Good Morning';
      } else if (hour < 18) {
        _greetingText = 'Good Afternoon';
      } else {
        _greetingText = 'Good Evening';
      }
    });
  }

  void _scheduleGreetingRefresh() {
    _greetingTimer?.cancel();
    final now = DateTime.now();
    int nextHour;
    if (now.hour < 12) {
      nextHour = 12;
    } else if (now.hour < 18) {
      nextHour = 18;
    } else {
      nextHour = 24;
    }
    final next = DateTime(now.year, now.month, now.day, nextHour);
    final delay = next.difference(now).inSeconds + 1;
    _greetingTimer = Timer(Duration(seconds: delay), () {
      _updateGreeting();
      _scheduleGreetingRefresh();
    });
  }

  /// 当前播放歌曲是否在可视区域内（纯算术，O(1)）。
  bool _isCurrentVisible() {
    if (_currentIdx < 0 || !_scrollCtrl.hasClients) return true;
    final viewport = _scrollCtrl.position.viewportDimension;
    final offset = _scrollCtrl.position.pixels;
    final itemTop = _currentIdx * _itemHeight - offset;
    final itemBottom = (_currentIdx + 1) * _itemHeight - offset;
    return itemBottom > 0 && itemTop < viewport;
  }

  /// 滚动位置变化的回调。
  ///
  /// 这个函数在滚动时每帧都会被调用，所以它只允许做算术：过滤后的歌单和
  /// 当前曲目的下标都在 build 里算好了（见 [_currentIdx]）。之前这里每次都
  /// 重新 `_applyFilter` + `indexWhere`，等于每帧复制一遍全表再扫一遍，
  /// 上千首的库直接掉帧。
  void _checkVisibility() {
    if (_currentIdx < 0) {
      if (!_currentSongVisible) setState(() => _currentSongVisible = true);
      return;
    }
    final visible = _isCurrentVisible();
    if (visible != _currentSongVisible) {
      setState(() => _currentSongVisible = visible);
    }
  }

  void _scheduleRestore(WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreOnce(ref);
    });
  }

  Future<void> _doRefresh(WidgetRef ref) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await ref.read(songListProvider.notifier).load();
    if (mounted) {
      setState(() => _refreshing = false);
      _restoreOnce(ref);
    }
  }

  void _restoreOnce(WidgetRef ref) {
    if (_restored) return;
    _restored = true;

    // 歌单就绪时同步到播放器，同时尝试恢复 pending 歌曲
    ref.listen(songListProvider, (prev, next) {
      final songs = next.valueOrNull;
      if (songs == null || songs.isEmpty) return;
      final notifier = ref.read(playerProvider.notifier);
      notifier.setPlaylist(songs);
      // 若存在待恢复的歌曲 ID，查找完整 LocalSong 后加载
      if (_pendingRestoreId != null && notifier.currentSong == null) {
        final target = songs.cast<LocalSong?>().firstWhere(
          (s) => s?.id == _pendingRestoreId,
          orElse: () => null,
        );
        if (target != null) {
          _pendingRestoreId = null;
          notifier.load(target);
        }
      }
    });

    // 读取播放历史，获取上次播放的歌曲 ID
    PlaybackHistory().all.then((records) {
      if (!mounted || records.isEmpty) return;
      final lastId = records.first.songId;
      final notifier = ref.read(playerProvider.notifier);
      if (notifier.currentSong != null) return;

      // 优先从缓存歌单中定位完整 LocalSong
      final cached = ref.read(songListProvider).valueOrNull;
      if (cached != null && cached.isNotEmpty) {
        final song = cached.cast<LocalSong?>().firstWhere(
          (s) => s?.id == lastId,
          orElse: () => null,
        );
        if (song != null) {
          notifier.setPlaylist(cached);
          notifier.load(song);
          return;
        }
      }

      // 缓存中未找到，记录 ID，等待 ref.listen 中歌单就绪后恢复
      _pendingRestoreId = lastId;
    });
  }

  List<LocalSong> _applyFilter(List<LocalSong> songs) {
    var filtered = List<LocalSong>.from(songs);

    switch (_filter) {
      case FilterOption.all:
        break;
      case FilterOption.noLyric:
        filtered = filtered.where((s) => !s.hasLyric).toList();
        break;
      case FilterOption.duplicates:
        final counts = <String, int>{};
        for (final s in filtered) {
          final key = '${s.title.toLowerCase()}|${s.artist.toLowerCase()}';
          counts[key] = (counts[key] ?? 0) + 1;
        }
        filtered = filtered.where((s) {
          final key = '${s.title.toLowerCase()}|${s.artist.toLowerCase()}';
          return (counts[key] ?? 0) >= 2;
        }).toList();
        break;
      case FilterOption.sortByName:
        filtered.sort((a, b) => a.title.compareTo(b.title));
        break;
      case FilterOption.recent:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    // Local search now lives in the dedicated search page (which can
    // query both the local library and online sources in parallel),
    // so the home page no longer performs in-place filtering.

    return filtered;
  }

  void _playAll(List<LocalSong> songs, WidgetRef ref) {
    if (songs.isEmpty) return;
    final notifier = ref.read(playerProvider.notifier);
    notifier.setPlaylist(songs);
    notifier.play(songs.first);
    context.push('/player', extra: songs.first);
  }

  bool get _hasActiveFilter => _filter != FilterOption.all;

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songListProvider);
    final songs = songsAsync.valueOrNull;
    final filtered = songs != null ? _applyFilter(songs) : const <LocalSong>[];
    // 只订阅真正影响列表的三样东西。之前是 ref.watch(playerProvider) 整个
    // state，于是歌词加载完成、播放模式切换这类跟列表无关的变化也会把整页
    // （含所有可见行）重建一遍。
    final (currentSongId, playingUrlId, playerPhase) = ref.watch(
      playerProvider.select((v) => (v.currentSongId, v.playingUrlId, v.phase)),
    );
    final hasSong = currentSongId != null || playingUrlId != null;
    final showMiniPlayer = ref.watch(showMiniPlayerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _scheduleRestore(ref);

    // 过滤结果和「当前曲目在列表里的下标」都只在这里算一次。
    // 滚动监听器（每帧触发）只做算术，不再遍历歌单。
    _currentIdx = currentSongId == null
        ? -1
        : filtered.indexWhere((s) => s.id == currentSongId);
    // 切歌 / 换筛选后同步一次可见性，替代之前每次 build 都挂一个
    // postFrameCallback 去重复检测。
    final currentVisible = _isCurrentVisible();
    _currentSongVisible = currentVisible;

    // Tab bar: 64 height + 16 bottom padding + safe area
    // Mini player: 68 height + 8 gap (only when song exists and setting is on)
    // viewPadding 不受 ShellPage SafeArea(bottom:false) 影响
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final miniPlayerHeight = (hasSong && showMiniPlayer) ? 68.0 + 8.0 : 0.0;
    final listBottomPadding = 64.0 + 16.0 + bottomInset + miniPlayerHeight + 16.0;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_greetingText,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: PearlColors.textPrimary(isDark),
                      )),
                  const SizedBox(height: 2),
                  Text(L.s.yourLibrary,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: PearlColors.textSecondary(isDark),
                      )),
                ],
              ),
              const Spacer(),
              // 筛选入口：玻璃锚定菜单（core/widgets/pearl_anchored_menu.dart），
              // 不再用 PopupMenuButton 的实心面板 + M3 elevation 8。
              SizedBox(
                key: _filterBtnKey,
                width: 38,
                height: 38,
                child: Material(
                  color: _hasActiveFilter
                      ? PearlColors.accent(isDark).withValues(alpha: 0.15)
                      : PearlElevation.fill(PearlLayer.inset, isDark),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _openFilterMenu,
                    child: Icon(Icons.filter_list_rounded,
                        size: 18,
                        color: _hasActiveFilter
                            ? PearlColors.accent(isDark)
                            : PearlColors.textSecondary(isDark)),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SizedBox(
            height: 52,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/import/search'),
              child: AbsorbPointer(
                child: TextField(
                  controller: _searchCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    hintText: L.s.searchHint,
                    prefixIcon: Icon(Icons.search_rounded, size: 20,
                        color: PearlColors.textDisabled(isDark)),
                    filled: true,
                    fillColor: PearlColors.glassBg(isDark),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(PearlTheme.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: PearlColors.textPrimary(isDark),
                  ),
                ),
              ),
            ),
          ),
        ),
        // LocalSong count + play all button
        songsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (songs) {
            if (filtered.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Row(
                children: [
                  Text(
                    _filter == FilterOption.sortByName ? L.s.countSongs('${filtered.length}') : L.s.countSongs('${filtered.length}'),
                    style: TextStyle(fontSize: 12, color: PearlColors.textSecondary(isDark)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _playAll(FilterOption.all == _filter ? songs : filtered, ref),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: PearlColors.accent(isDark).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.playlist_play_rounded, size: 14, color: PearlColors.accent(isDark)),
                          const SizedBox(width: 4),
                          Text(L.s.playAll,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                  color: PearlColors.accent(isDark))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 2),
        // Music List
        Expanded(
          child: Stack(
            children: [
              songsAsync.when(
            loading: () => Center(
              child: PearlLoading(size: 24, color: PearlColors.accent(isDark)),
            ),
            error: (e, _) => _ErrorView(isDark: isDark, onRetry: () => ref.read(songListProvider.notifier).load()),
            data: (songs) {
              if (filtered.isEmpty) {
                return _EmptyView(isDark: isDark);
              }
              return RefreshIndicator(
                color: PearlColors.accent(isDark),
                backgroundColor: PearlColors.glassBgStrong(isDark),
                onRefresh: () => _doRefresh(ref),
                child: Scrollbar(
                  controller: _scrollCtrl,
                  thumbVisibility: true,
                  interactive: true,
                  radius: const Radius.circular(4),
                  thickness: 4,
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    physics: const AlwaysScrollableScrollPhysics(),
                    // ignore: deprecated_member_use
                    cacheExtent: 500,
                    padding: EdgeInsets.only(bottom: listBottomPadding),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final song = filtered[i];
                      final isCurrent = currentSongId == song.id;
                      return RepaintBoundary(
                        child: SongTile(
                          key: ValueKey(song.id),
                          song: song,
                          isPlaying: isCurrent,
                          isPaused: playerPhase == PlayerPhase.paused,
                          isLoading:
                              isCurrent && playerPhase == PlayerPhase.loading,
                          onTap: () {
                            ref.read(playerProvider.notifier).setPlaylist(songs);
                            context.push('/player', extra: song);
                          },
                          onLongPress: () => _showSongMenu(context, ref, song),
                          onPlayPause: () =>
                              ref.read(playerProvider.notifier).togglePlayPause(),
                          onMore: () => _showSongMenu(context, ref, song),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // 定位当前播放歌曲按钮（仅当歌曲滚出可视区域时显示）
          if (hasSong && showMiniPlayer && _currentIdx >= 0)
            Positioned(
              right: 16,
              bottom: 64.0 + 16.0 + bottomInset + miniPlayerHeight + 12,
              child: AnimatedOpacity(
                opacity: currentVisible ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: _LocateButton(
                  scrollCtrl: _scrollCtrl,
                  // 这个分支已经保证 _currentIdx >= 0，即它就是当前曲目在
                  // filtered 里的下标
                  targetId: filtered[_currentIdx].id,
                  filtered: filtered,
                ),
              ),
            ),
        ],
      ),
    ),
    ],
    );
  }
}

void _showSongMenu(BuildContext context, WidgetRef ref, LocalSong song) {
  final notifier = ref.read(playerProvider.notifier);
  final isCurrentSong = notifier.currentSong?.id == song.id;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showPearlBottomSheet(
    context: context,
    builder: (ctx) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PearlElevation.sheetRadius),
        ),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            // 面板直接贴到屏幕底。之前额外留了 tab bar + 迷你播放器的高度，
            // 但遮罩已经把底栏压暗了，那截留白只让下部空出一块，没有意义。
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: PearlElevation.fill(PearlLayer.overlay, isDark),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(PearlElevation.sheetRadius),
              ),
              border: Border(
                top: BorderSide(
                  color: PearlElevation.border(PearlLayer.overlay, isDark),
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: PearlColors.textDisabled(isDark),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (song.type == 'netease')
                          SvgPicture.asset('assets/icons/网易云音乐.svg', width: 20, height: 20)
                        else if (song.type == 'qq')
                          SvgPicture.asset('assets/icons/QQ音乐.svg', width: 20, height: 20),
                        if (song.type.isNotEmpty) const SizedBox(width: 6),
                        Expanded(
                          child: Text(song.title,
                              style: TextStyle(
                                  color: PearlColors.textPrimary(isDark),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('${song.artist} · ${song.durationFormatted}',
                        style: TextStyle(
                            color: PearlColors.textSecondary(isDark), fontSize: 13)),
                    const SizedBox(height: 16),
                    if (isCurrentSong)
                      _MenuTile(
                        icon: notifier.player.playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        label: notifier.player.playing ? L.s.pause : L.s.play,
                        color: PearlColors.accent(isDark),
                        onTap: () {
                          Navigator.pop(ctx);
                          notifier.togglePlayPause();
                        },
                      ),
                    if (!song.hasLyric)
                      _MenuTile(
                        icon: Icons.lyrics_outlined,
                        label: L.s.uploadLyrics,
                        color: PearlColors.accent(isDark),
                        onTap: () {
                          Navigator.pop(ctx);
                        },
                      ),
                    _MenuTile(
                      icon: Icons.delete_outline_rounded,
                      label: L.s.deleteSong,
                      color: const Color(0xFFFF7A9E),
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await ref.read(songListProvider.notifier).removeSong(song.id);
                        } catch (e) {
                          if (context.mounted) {
                            PearlToast.error(context, L.s.deleteFailed('$e'));
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool isDark;
  const _EmptyView({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return PearlEmptyState(
      isDark: isDark,
      icon: Icons.headphones_rounded,
      title: L.s.emptyTitle,
      hint: L.s.emptyHint,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;
  const _ErrorView({required this.isDark, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return PearlEmptyState(
      isDark: isDark,
      icon: Icons.cloud_off_rounded,
      iconColor: const Color(0xFFFF7A9E),
      title: L.s.loadFailed,
      action: ElevatedButton(
        onPressed: onRetry,
        style: ElevatedButton.styleFrom(
          backgroundColor: PearlColors.accent(isDark),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(L.s.retry),
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  final ScrollController scrollCtrl;
  final int targetId;
  final List<LocalSong> filtered;

  const _LocateButton({
    required this.scrollCtrl,
    required this.targetId,
    required this.filtered,
  });

  static const double _kItemHeight = 68.0;

  void _locate() {
    final idx = filtered.indexWhere((s) => s.id == targetId);
    if (idx < 0 || !scrollCtrl.hasClients) return;

    final targetOffset = idx * _kItemHeight;
    final maxScroll = scrollCtrl.position.maxScrollExtent;
    final offset = targetOffset.clamp(0.0, maxScroll);

    scrollCtrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _locate,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: PearlColors.glassBgStrong(isDark),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.my_location_rounded,
            size: 18,
            color: PearlColors.accent(isDark),
          ),
        ),
      ),
    );
  }
}