import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/utils/playback_history.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../collection/providers/song_list_provider.dart';
import 'package:music_app/core/i18n/app_strings.dart';
import '../../../core/widgets/pearl_loading.dart';
import '../../../core/widgets/pearl_empty_state.dart';

class PlayHistoryPage extends ConsumerStatefulWidget {
  const PlayHistoryPage({super.key});

  @override
  ConsumerState<PlayHistoryPage> createState() => _PlayHistoryPageState();
}

class _PlayHistoryPageState extends ConsumerState<PlayHistoryPage> {
  List<PlayRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await PlaybackHistory().all;
    if (!mounted) return;
    setState(() {
      _records = records;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: PearlColors.bgSecondary(isDark),
        title: Text(L.s.clearHistory,
            style: TextStyle(color: PearlColors.textPrimary(isDark))),
        content: Text(L.s.clearHistoryBody,
            style: TextStyle(color: PearlColors.textSecondary(isDark))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L.s.cancel,
                style: TextStyle(color: PearlColors.textSecondary(isDark))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(L.s.confirm,
                style: TextStyle(color: PearlColors.accent(isDark))),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await PlaybackHistory().clear();
    if (!mounted) return;
    setState(() => _records = []);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final songList = ref.watch(songListProvider).valueOrNull ?? [];

    // 记录 → 歌曲的解析只在 build 里做一次。
    // 之前这一步放在 itemBuilder 里对全表 firstWhere：每建一行就扫一遍歌单，
    // 快速滚动时一帧要建好几行，整体是 O(行数 × 歌单)。换成先建索引再查，
    // 每行只剩 O(1)，同时顺手把「歌已从曲库删掉」的记录过滤掉（以前是渲染成
    // 一个零高度的 SizedBox 占位）。
    final songById = <int, LocalSong>{for (final s in songList) s.id: s};
    final rows = <({PlayRecord record, LocalSong song})>[
      for (final r in _records)
        if (songById[r.songId] != null) (record: r, song: songById[r.songId]!),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(L.s.playHistory),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: _clearAll,
              tooltip: L.s.clearHistory,
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: PearlLoading(
                  size: 36, strokeWidth: 4, color: PearlColors.accent(isDark)),
            )
          : rows.isEmpty
              ? PearlEmptyState(
                  isDark: isDark,
                  icon: Icons.history_rounded,
                  title: L.s.noHistory,
                  hint: L.s.historyEmptyHint,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: rows.length,
                  itemBuilder: (ctx, i) {
                    final row = rows[i];
                    return RepaintBoundary(
                      child: SongTile(
                        key: ValueKey(
                            'history_${row.record.songId}_${row.record.playedAt}'),
                        song: row.song,
                        onTap: () {
                          context.push('/player', extra: row.song);
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
