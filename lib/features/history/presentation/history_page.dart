import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
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
    setState(() { _records = records; _loading = false; });
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('清除记录', style: TextStyle(color: AppColors.text)),
        content: const Text('将清除所有播放记录。', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消', style: TextStyle(color: AppColors.muted))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定', style: TextStyle(color: AppColors.error))),
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
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _records.isEmpty
              ? const Center(child: Text('暂无播放记录', style: TextStyle(color: AppColors.muted, fontSize: 14)))
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
