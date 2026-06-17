import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/utils/playback_history.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/song_tile.dart';

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
        title: Text('清除记录',
            style: TextStyle(color: PearlColors.textPrimary(isDark))),
        content: Text('将清除所有播放记录。',
            style: TextStyle(color: PearlColors.textSecondary(isDark))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('取消',
                style: TextStyle(color: PearlColors.textSecondary(isDark))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('确定',
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

  Song _toSong(PlayRecord r) => Song(
        id: r.songId,
        title: r.title,
        artist: r.artist,
        album: '',
        format: r.format,
        duration: r.duration,
        size: r.size,
        createdAt: r.playedAt,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('播放记录'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: _clearAll,
              tooltip: '清除记录',
            ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: PearlColors.accent(isDark),
              ),
            )
          : _records.isEmpty
              ? Center(
                  child: Text(
                    '暂无播放记录',
                    style: TextStyle(
                      color: PearlColors.textSecondary(isDark),
                      fontSize: 14,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _records.length,
                  itemBuilder: (ctx, i) {
                    final r = _records[i];
                    return SongTile(
                      song: _toSong(r),
                      onTap: () {
                        context.push('/player', extra: {
                          'id': r.songId,
                          'title': r.title,
                          'artist': r.artist,
                          'album': '',
                          'format': r.format,
                          'duration': r.duration,
                          'size': r.size,
                          'lyric_path': null,
                          'created_at': r.playedAt,
                          'lastPosition': r.positionSeconds,
                          'fromHistory': true,
                        });
                      },
                    );
                  },
                ),
    );
  }
}
