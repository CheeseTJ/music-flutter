import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../home/providers/song_list_provider.dart';
import '../../player/providers/player_provider.dart';

enum _Filter { all, online, local, recent, liked }

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _refreshing = false;
  _Filter _filter = _Filter.all;

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

  List<Song> _applyFilter(List<Song> songs) {
    final q = _query.toLowerCase();
    var filtered = songs;
    if (q.isNotEmpty) {
      filtered = filtered.where((s) =>
          s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q)).toList();
    }

    switch (_filter) {
      case _Filter.all:
        break;
      case _Filter.online:
        filtered = filtered.where((s) => !_isLocal(s)).toList();
        break;
      case _Filter.local:
        filtered = filtered.where((s) => _isLocal(s)).toList();
        break;
      case _Filter.recent:
        filtered = filtered.take(20).toList();
        break;
      case _Filter.liked:
        break;
    }
    return filtered;
  }

  bool _isLocal(Song s) => s.format == 'mp3';

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
    final isDark = ref.watch(themeProvider).isDark;
        final filterLabels = ['All', 'Online', 'Local', 'Recent', 'Liked'];
    const filterValues = _Filter.values;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Text('Library',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary,
                  )),
              const Spacer(),
              Text('24.7GB / 50GB',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: (isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary).withValues(alpha: 0.7),
                  )),

            ],
          ),
        ),
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            height: 52,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search music...',
                prefixIcon: Icon(Icons.search_rounded, size: 22,
                    color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
                filled: true,
                fillColor: isDark ? AuroraColors.bgSecondary : HarmoniqColors.aux,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                hintStyle: TextStyle(
                  color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary,
                  fontSize: 15,
                ),
              ),
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary,
              ),
            ),
          ),
        ),
        // Filter
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filterLabels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final selected = filterValues[i] == _filter;
              return GestureDetector(
                onTap: () => setState(() => _filter = filterValues[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? (isDark ? AuroraColors.gradientStart : HarmoniqColors.blue)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: selected
                        ? null
                        : Border.all(color: isDark ? AuroraColors.bgSecondary : HarmoniqColors.aux, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      filterLabels[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : isDark
                                ? AuroraColors.textSecondary
                                : HarmoniqColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        // Music List
        Expanded(
          child: songsAsync.when(
            loading: () => Center(
              child: SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? AuroraColors.gradientStart : HarmoniqColors.blue,
                ),
              ),
            ),
            error: (e, _) => _ErrorView(isDark: isDark, onRetry: () => ref.read(songListProvider.notifier).load()),
            data: (songs) {
              final filtered = _applyFilter(songs);
              if (filtered.isEmpty) {
                return _EmptyView(hasSearch: _query.isNotEmpty, isDark: isDark);
              }
              return RefreshIndicator(
                color: isDark ? AuroraColors.gradientStart : HarmoniqColors.blue,
                backgroundColor: isDark ? AuroraColors.bgSecondary : HarmoniqColors.card,
                onRefresh: () => _doRefresh(ref),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final song = filtered[i];
                    return SongTile(
                      song: song,
                      onTap: () {
                        ref.read(playerProvider.notifier).setPlaylist(songs);
                        context.push('/player', extra: song);
                      },
                      onLongPress: () => _showSongMenu(context, ref, song),
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

void _showSongMenu(BuildContext context, WidgetRef ref, Song song) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: AuroraColors.bgSecondary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AuroraColors.textDisabled, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(song.title,
                style: const TextStyle(color: AuroraColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(song.artist,
                style: const TextStyle(color: AuroraColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            _MenuTile(icon: Icons.delete_outline_rounded, label: 'Delete Song',
                color: AuroraColors.danger, onTap: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(songListProvider.notifier).removeSong(song.id);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                }
              }
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
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
    return Material(
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
    );
  }
}

class _EmptyView extends StatelessWidget {
  final bool hasSearch;
  final bool isDark;
  const _EmptyView({required this.hasSearch, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(hasSearch ? Icons.search_off_rounded : Icons.headphones_rounded,
              size: 56,
              color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
          const SizedBox(height: 16),
          Text(hasSearch ? 'No results found' : 'No music yet',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary,
              )),
          const SizedBox(height: 6),
          Text(hasSearch ? 'Try a different keyword' : 'Upload your first song',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary,
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
              color: isDark ? AuroraColors.danger : Colors.red[300]),
          const SizedBox(height: 16),
          Text('Load failed',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary,
              )),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AuroraColors.gradientStart : HarmoniqColors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
