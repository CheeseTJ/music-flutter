import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/theme/pearl_theme.dart';
import '../../../core/utils/playback_history.dart';
import '../../../core/utils/settings.dart';
import '../../../core/widgets/pearl_bottom_sheet.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../collection/providers/song_list_provider.dart';
import '../../player/providers/player_provider.dart';

enum FilterOption { all, noLyric, duplicates, sortByName, recent }

class CollectionPage extends ConsumerStatefulWidget {
  const CollectionPage({super.key});

  @override
  ConsumerState<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends ConsumerState<CollectionPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _refreshing = false;
  FilterOption _filter = FilterOption.all;
  String _greetingText = '';
  Timer? _greetingTimer;
  bool _restored = false;

  @override
  void initState() {
    super.initState();
    _updateGreeting();
    _scheduleGreetingRefresh();
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
    PlaybackHistory().all.then((records) {
      if (!mounted || records.isEmpty) return;
      final last = records.first;
      final notifier = ref.read(playerProvider.notifier);
      if (notifier.currentSong != null) return;

      // 直接从历史记录构造 Song 恢复，不等 songListProvider 加载完成
      final song = Song(
        id: last.songId,
        title: last.title,
        artist: last.artist,
        album: '',
        format: last.format,
        duration: last.duration,
        size: last.size,
        type: '',
        createdAt: last.playedAt,
      );

      // 若本地曲库已就绪，顺便设置 playlist 供 next/previous 使用
      final songs = ref.read(songListProvider).valueOrNull;
      if (songs != null && songs.isNotEmpty) {
        notifier.setPlaylist(songs);
      }

      notifier.load(song);
    });
  }

  List<Song> _applyFilter(List<Song> songs) {
    var filtered = List<Song>.from(songs);

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

  void _playAll(List<Song> songs, WidgetRef ref) {
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
    final filtered = songs != null ? _applyFilter(songs) : const <Song>[];
    final playerState = ref.watch(playerProvider);
    final currentSong = ref.watch(playerProvider.notifier).currentSong;
    final hasSong = currentSong != null;
    final showMiniPlayer = ref.watch(showMiniPlayerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    _scheduleRestore(ref);

    // Tab bar: 64 height + 16 bottom padding + safe area
    // Mini player: 68 height + 8 gap (only when song exists and setting is on)
    final bottomInset = MediaQuery.of(context).padding.bottom;
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
                  Text('Your Collection',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: PearlColors.textSecondary(isDark),
                      )),
                ],
              ),
              const Spacer(),
              // Filter popup — same visual style as the search page's
              // source/platform dropdowns (rounded square icon, 12-radius
              // menu, 6px offset, soft shadow).
              PopupMenuButton<FilterOption>(
                tooltip: '',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 6),
                elevation: 8,
                color: PearlColors.bgSecondary(isDark),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (f) => setState(() => _filter = f),
                itemBuilder: (_) => [
                  _buildFilterItem(context, '默认', FilterOption.all, Icons.format_list_bulleted_rounded, isDark),
                  _buildFilterItem(context, '缺歌词', FilterOption.noLyric, Icons.lyrics_outlined, isDark),
                  _buildFilterItem(context, '重名筛查', FilterOption.duplicates, Icons.content_copy_rounded, isDark),
                  _buildFilterItem(context, '按名称排序', FilterOption.sortByName, Icons.sort_by_alpha_rounded, isDark),
                  _buildFilterItem(context, '最近添加', FilterOption.recent, Icons.access_time_rounded, isDark),
                ],
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _hasActiveFilter
                        ? PearlColors.accent(isDark).withValues(alpha: 0.15)
                        : PearlColors.glassBg(isDark),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.filter_list_rounded,
                      size: 18,
                      color: _hasActiveFilter
                          ? PearlColors.accent(isDark)
                          : PearlColors.textSecondary(isDark)),
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
                    hintText: '搜索本地 + 在线歌曲...',
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
        // Song count + play all button
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
                    _filter == FilterOption.sortByName ? 'A-Z · ${filtered.length} 首' : '共 ${filtered.length} 首',
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
                          Text('Play All',
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
          child: songsAsync.when(
            loading: () => Center(
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PearlColors.accent(isDark),
                ),
              ),
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
                    cacheExtent: 2000,
                    padding: EdgeInsets.only(bottom: listBottomPadding),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final song = filtered[i];
                      final isCurrent = currentSong?.id == song.id;
                      return RepaintBoundary(
                        child: SongTile(
                          key: ValueKey(song.id),
                          song: song,
                          isPlaying: isCurrent,
                          isPaused: playerState.phase == PlayerPhase.paused,
                          onTap: () {
                            ref.read(playerProvider.notifier).setPlaylist(songs);
                            context.push('/player', extra: song);
                          },
                          onLongPress: () => _showSongMenu(context, ref, song),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  PopupMenuItem<FilterOption> _buildFilterItem(BuildContext context, String label, FilterOption value, IconData icon, bool isDark) {
    final selected = _filter == value;
    return PopupMenuItem<FilterOption>(
      height: 40,
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: selected
              ? PearlColors.accent(isDark)
              : PearlColors.textSecondary(isDark)),
          const SizedBox(width: 10),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  color: selected
                      ? PearlColors.accent(isDark)
                      : PearlColors.textPrimary(isDark),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          const Spacer(),
          if (selected) Icon(Icons.check_rounded, size: 18,
              color: PearlColors.accent(isDark)),
        ],
      ),
    );
  }
}

void _showSongMenu(BuildContext context, WidgetRef ref, Song song) {
  final notifier = ref.read(playerProvider.notifier);
  final isCurrentSong = notifier.currentSong?.id == song.id;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showPearlBottomSheet(
    context: context,
    builder: (ctx) {
      final hasSong = ref.read(playerProvider.notifier).currentSong != null;
      final extraBottom = (72 + 20 + (hasSong ? 68 + 8 : 0)).toDouble();
      return Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, extraBottom),
        decoration: BoxDecoration(
          color: PearlColors.glassBgStrong(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: PearlColors.textDisabled(isDark), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (song.type == 'netease')
                    SvgPicture.asset('assets/icons/\u7f51\u6613\u4e91\u97f3\u4e50.svg', width: 20, height: 20)
                  else if (song.type == 'qq')
                    SvgPicture.asset('assets/icons/QQ\u97f3\u4e50.svg', width: 20, height: 20),
                  if (song.type.isNotEmpty) const SizedBox(width: 6),
                  Expanded(
                    child: Text(song.title,
                        style: TextStyle(color: PearlColors.textPrimary(isDark), fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${song.artist} · ${song.durationFormatted}',
                  style: TextStyle(color: PearlColors.textSecondary(isDark), fontSize: 13)),
              const SizedBox(height: 16),
              if (isCurrentSong)
                _MenuTile(
                  icon: notifier.player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  label: notifier.player.playing ? '暂停' : '播放',
                  color: PearlColors.accent(isDark),
                  onTap: () {
                    Navigator.pop(ctx);
                    notifier.togglePlayPause();
                  },
                ),
              if (!song.hasLyric)
                _MenuTile(
                  icon: Icons.lyrics_outlined,
                  label: '上传歌词',
                  color: PearlColors.accent(isDark),
                  onTap: () {
                    Navigator.pop(ctx);
                  },
                ),
              _MenuTile(
                icon: Icons.delete_outline_rounded,
                label: '删除歌曲',
                color: const Color(0xFFFF7A9E),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref.read(songListProvider.notifier).removeSong(song.id);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                    }
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.headphones_rounded,
              size: 56,
              color: PearlColors.textDisabled(isDark)),
          const SizedBox(height: 16),
          Text('还没有歌曲',
              style: TextStyle(
                fontSize: 16,
                color: PearlColors.textSecondary(isDark),
              )),
          const SizedBox(height: 6),
          Text('上传你的第一首歌吧',
              style: TextStyle(
                fontSize: 13,
                color: PearlColors.textDisabled(isDark),
              )),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;
  const _ErrorView({required this.isDark, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 56,
              color: const Color(0xFFFF7A9E)),
          const SizedBox(height: 16),
          Text('加载失败',
              style: TextStyle(
                fontSize: 16,
                color: PearlColors.textSecondary(isDark),
              )),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: PearlColors.accent(isDark),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
