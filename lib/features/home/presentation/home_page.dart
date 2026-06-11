import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/crypto/krc_decoder.dart';
import '../../../data/models/song.dart';
import '../../../data/datasources/remote/api_client.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../home/providers/song_list_provider.dart';
import '../../player/providers/player_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _refreshing = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _doRefresh(WidgetRef ref) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await ref.read(songListProvider.notifier).load();
    if (mounted) setState(() => _refreshing = false);
  }

  List<Song> _filter(List<Song> songs) {
    if (_query.isEmpty) return songs;
    final q = _query.toLowerCase();
    return songs.where((s) =>
        s.title.toLowerCase().contains(q) ||
        s.artist.toLowerCase().contains(q) ||
        s.album.toLowerCase().contains(q)).toList();
  }

  void _playAll(List<Song> songs, WidgetRef ref) {
    if (songs.isEmpty) return;
    final notifier = ref.read(playerProvider.notifier);
    notifier.setPlaylist(songs);
    notifier.play(songs.first);
    context.push('/player', extra: songs.first);
  }

  @override
  Widget build(BuildContext context) {
    final songsAsync = ref.watch(songListProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: '搜索歌曲...',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.playlist_play_rounded, color: AppColors.accent),
                tooltip: '播放全部',
                onPressed: () {
                  final provider = ref.read(songListProvider);
                  provider.whenData((songs) => _playAll(songs, ref));
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: songsAsync.when(
            loading: () => const Center(child: SizedBox(
              width: 24, height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
            )),
            error: (e, _) => _ErrorView(onRetry: () => ref.read(songListProvider.notifier).load()),
            data: (songs) {
              final filtered = _filter(songs);
              if (filtered.isEmpty) {
                return _EmptyView(hasSearch: _query.isNotEmpty);
              }
              final noLyricCount = filtered.where((s) => !s.hasLyric).length;
              return RefreshIndicator(
                color: AppColors.accent,
                backgroundColor: AppColors.elevated,
                onRefresh: () => _doRefresh(ref),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length + 1,
                  itemBuilder: (_, i) {
                    if (i == 0) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_refreshing) const _RefreshBar(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: Row(
                              children: [
                                Text('共 ${filtered.length} 首',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                                if (noLyricCount > 0) ...[
                                  const SizedBox(width: 12),
                                  Icon(Icons.lyrics_outlined, size: 14, color: AppColors.muted.withOpacity(0.5)),
                                  const SizedBox(width: 4),
                                  Text('$noLyricCount 首缺歌词',
                                      style: TextStyle(color: AppColors.muted.withOpacity(0.6), fontSize: 12)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    }
                    final song = filtered[i - 1];
                    return SongTile(
                      song: song,
                      onTap: () {
                        ref.read(playerProvider.notifier).setPlaylist(songs);
                        context.push('/player', extra: song);
                      },
                      onLongPress: () => _showDeleteDialog(context, ref, song),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasSearch;
  const _EmptyView({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasSearch ? Icons.search_off_rounded : Icons.headphones_rounded, size: 56, color: AppColors.subtle),
          const SizedBox(height: 16),
          Text(hasSearch ? '没有找到匹配的歌曲' : '还没有歌曲', style: const TextStyle(color: AppColors.muted, fontSize: 16)),
          const SizedBox(height: 6),
          Text(hasSearch ? '换个关键词试试' : '上传你的第一首歌吧', style: const TextStyle(color: AppColors.subtle, fontSize: 13)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.error),
          const SizedBox(height: 16),
          const Text('加载失败', style: TextStyle(color: AppColors.muted, fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.deep),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

void _showDeleteDialog(BuildContext context, WidgetRef ref, Song song) {
  final hasLyric = song.hasLyric;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.subtle, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text('管理「${song.title}」',
                  style: const TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('${song.artist}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text('上传', style: TextStyle(color: AppColors.subtle, fontSize: 12)),
            ),
            _ManageOption(
              icon: Icons.text_snippet_outlined,
              label: '上传歌词',
              color: const Color(0xFF3399FF),
              onTap: () => _uploadLyricForSong(ctx, ref, song),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 4),
              child: Text('删除', style: TextStyle(color: AppColors.subtle, fontSize: 12)),
            ),
            _ManageOption(
              icon: Icons.delete_forever_rounded,
              label: '删除歌曲',
              color: AppColors.error,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  if (hasLyric) await ref.read(songListProvider.notifier).removeLyric(song.id);
                  await ref.read(songListProvider.notifier).removeSong(song.id);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                }
              },
            ),
            _ManageOption(
              icon: Icons.text_snippet_outlined,
              label: '删除歌词',
              color: AppColors.error,
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(songListProvider.notifier).removeLyric(song.id);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除歌词失败: $e')));
                }
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消', style: TextStyle(color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
      ),
    ),
  );
}

void _uploadLyricForSong(BuildContext ctx, WidgetRef ref, Song song) async {
  Navigator.pop(ctx);
  final result = await FilePicker.platform.pickFiles(type: FileType.any);
  if (result == null || result.files.isEmpty || result.files.first.path == null) return;

  final file = result.files.first;
  if (!file.name.toLowerCase().endsWith('.krc')) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('请选择 KRC 格式的歌词文件')));
    return;
  }

  try {
    final lrc = await KrcDecoder.decodeToString(file.path!);
    final api = ref.read(apiClientProvider);
    await api.uploadLyric(song.id, lrc);
    await ref.read(songListProvider.notifier).load();
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('歌词上传成功')));
    }
  } catch (e) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('上传失败: $e')));
    }
  }
}

class _RefreshBar extends StatefulWidget {
  const _RefreshBar();

  @override
  State<_RefreshBar> createState() => _RefreshBarState();
}

class _RefreshBarState extends State<_RefreshBar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) => SizedBox(
        height: 2,
        child: LinearProgressIndicator(
          minHeight: 2,
          value: _controller.value,
          backgroundColor: Colors.transparent,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
        ),
      ),
    );
  }
}

class _ManageOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ManageOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: color.withOpacity(0.1),
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
