import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:music_app/core/theme/pearl_colors.dart';
import 'package:music_app/core/theme/pearl_theme.dart';
import 'package:music_app/features/player/providers/player_provider.dart';
import 'package:music_app/features/collection/providers/song_list_provider.dart';
import 'package:music_app/features/import/models/song.dart';
import 'package:music_app/features/import/music_manager.dart';
import 'package:music_app/data/datasources/remote/api_client.dart';
import 'package:music_app/data/models/song.dart' as local_song;
import 'package:music_app/core/utils/settings.dart';
import 'package:music_app/shared/widgets/mini_player.dart';



/// 在线结果来自 music-api 聚合接口，provider 可能是 netease/qq/kuwo/kugou/...
/// 这里只负责按平台渲染图标与配色（不再作为筛选条件）。
class MusicPlatformMeta {
  static const neteaseColor = Color(0xFFEC4141);
  static const qqColor = Color(0xFF31C27C);

  static Color color(String platform, bool isDark) {
    switch (platform) {
      case 'netease':
        return neteaseColor;
      case 'qq':
        return qqColor;
      default:
        return const Color(0xFF7C8CF8);
    }
  }

  static Widget icon(String platform, double size, {bool isDark = true}) {
    final asset = switch (platform) {
      'netease' => 'assets/icons/网易云音乐.svg',
      'qq' => 'assets/icons/QQ音乐.svg',
      _ => null,
    };
    if (asset != null) {
      return SvgPicture.asset(asset, width: size, height: size, fit: BoxFit.contain);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color(platform, isDark).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(Icons.library_music_rounded,
          size: size * 0.7, color: color(platform, isDark)),
    );
  }

  static String label(String platform) {
    switch (platform) {
      case 'netease':
        return '网易云';
      case 'qq':
        return 'QQ';
      case 'kuwo':
        return '酷我';
      case 'kugou':
        return '酷狗';
      case 'migu':
        return '咪咕';
      default:
        return platform.toUpperCase();
    }
  }

  /// Memoised icon cache keyed by (platform, size).
  static final Map<(String, double), Widget> _iconCache = {};
  static Widget iconCached(String platform, double size) {
    return _iconCache.putIfAbsent((platform, size), () => icon(platform, size));
  }
}

class InternetSearchPage extends ConsumerStatefulWidget {
  final String initialQuery;
  const InternetSearchPage({super.key, this.initialQuery = ''});

  @override
  ConsumerState<InternetSearchPage> createState() => _InternetSearchPageState();
}

class _InternetSearchPageState extends ConsumerState<InternetSearchPage> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<Song> _results = [];
  List<local_song.Song> _localResults = [];
  bool _loading = false;
  String _error = '';
  /// Song currently being imported: key is "${platform}|${id}" so multiple
  /// tiles can be in different import states (one loading, one idle, one
  /// failed). `null` means no active import.
  String? _importingSongKey;
  List<String> _history = [];
  static const _historyKey = 'search_history';
  static const _maxHistory = 20;

  /// Debounce timer for [_doSearch] to avoid hammering the network on
  /// every keystroke (especially during CJK IME composition).
  Timer? _searchDebounce;

  /// Monotonic counter to discard stale search results: only the response
  /// from the most recent query is allowed to mutate state.
  int _searchSeq = 0;

  @override
  void initState() {
    super.initState();
    // Do NOT auto-focus: forcing the keyboard up during the page transition
    // triggers a layout pass that visibly janks the first frames.
    // Users can tap the field to bring up the IME.
    if (widget.initialQuery.isNotEmpty) {
      _searchCtrl.text = widget.initialQuery;
      _searchCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.initialQuery.length),
      );
    }
    _loadHistory();
    // If we have an initial query from the home page, kick off a search
    // once the providers are ready (post-frame).
    if (widget.initialQuery.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateLocalResults(widget.initialQuery);
          _doSearch(widget.initialQuery);
        }
      });
    }
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history = prefs.getStringList(_historyKey) ?? []);
  }

  Future<void> _saveHistory(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    _history.remove(q);
    _history.insert(0, q);
    if (_history.length > _maxHistory) _history = _history.sublist(0, _maxHistory);
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(_historyKey, _history);
  }

  Future<void> _clearHistory() async {
    _history.clear();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove(_historyKey);
    setState(() {});
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      _searchDebounce?.cancel();
      _searchDebounce = null;
      if (!mounted) return;
      setState(() {
        _results = <Song>[];
        _localResults = <local_song.Song>[];
        _error = '';
        _loading = false;
      });
      return;
    }

    // Local search is synchronous and cheap, so update it immediately
    // alongside the online request below.
    _updateLocalResults(q);

    // Stamp this search with a sequence id; if a newer keystroke supersedes
    // it, the response is dropped on the floor.
    final mySeq = ++_searchSeq;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = '';
      });
    }

    _saveHistory(q);

    try {
      final mgr = ref.read(musicManagerProvider);
      final results = await mgr.search(q);

      if (!mounted) return;
      if (mySeq != _searchSeq) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (mySeq != _searchSeq) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Filter the local song library by [query] (matches title / artist /
  /// album, case-insensitive). Runs synchronously against the cached
  /// song-list provider state, so it's free to call on every keystroke.
  void _updateLocalResults(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      if (_localResults.isNotEmpty) {
        setState(() => _localResults = <local_song.Song>[]);
      }
      return;
    }
    final songs = ref.read(songListProvider).valueOrNull;
    if (songs == null) {
      if (_localResults.isNotEmpty) {
        setState(() => _localResults = <local_song.Song>[]);
      }
      return;
    }
    final matches = songs.where((s) =>
      s.title.toLowerCase().contains(q) ||
      s.artist.toLowerCase().contains(q) ||
      s.album.toLowerCase().contains(q)
    ).toList();
    // Stable order: title, then artist, then id.
    matches.sort((a, b) {
      final t = a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (t != 0) return t;
      final ar = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
      if (ar != 0) return ar;
      return a.id.compareTo(b.id);
    });
    setState(() => _localResults = matches);
  }

  /// Debounce wrapper around [_doSearch].
  ///
  /// Cancels any in-flight debounce and starts a new 350ms timer. We do NOT
  /// trigger setState from here; the inner [_doSearch] decides when to
  /// mutate state (only on search start/complete/clear).
  ///
  /// Local results are filtered synchronously on every keystroke so they
  /// feel instant, while the (network-bound) online search is debounced.
  void _onQueryChanged(String value) {
    _updateLocalResults(value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _doSearch(value);
    });
  }

  Future<void> _doPlay(Song song) async {
    final playingUrlId = ref.read(playerProvider.notifier).playingUrlId;
    final songId = '${song.platform}|${song.id}';
    if (songId == playingUrlId) {
      ref.read(playerProvider.notifier).togglePlayPause();
      return;
    }

    try {
      final mgr = ref.read(musicManagerProvider);
      // 播放默认选最高音质：并发各档位取链，选实际 bitrate 最高的结果。
      final url = await mgr.getBestUrl(song);
      if (url == null || url.url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('\u83b7\u53d6\u64ad\u653e\u94fe\u63a5\u5931\u8d25'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }
      final notifier = ref.read(playerProvider.notifier);
      final lrc = await mgr.getLyric(song);
      await notifier.playUrl(url.url, song.name, song.singer,
          platform: song.platform, id: song.id, lyric: lrc.isEmpty ? null : lrc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('\u64ad\u653e\u5931\u8d25: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// 导入前弹出音质选择（来自搜索结果的 qualityOptions），
  /// 未提供音质选项时直接按默认档导入。
  Future<void> _doImport(Song song) async {
    final mgr = ref.read(musicManagerProvider);
    final options = mgr.qualityOptionsOf(song);
    String? quality;
    if (options.isNotEmpty) {
      quality = await _pickQuality(song, options);
      if (quality == null) return; // 用户取消
    }
    await _importWithQuality(song, quality);
  }

  Future<String?> _pickQuality(Song song, List<Map<String, dynamic>> options) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: PearlColors.bgSecondary(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '导入音质 · ${song.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PearlColors.textPrimary(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            ...options.map((opt) => ListTile(
                  dense: true,
                  leading: Icon(Icons.high_quality_rounded,
                      size: 20, color: PearlColors.accent(isDark)),
                  title: Text(
                    opt['label']?.toString() ?? opt['value']?.toString() ?? '未知',
                    style: TextStyle(
                        fontSize: 14, color: PearlColors.textPrimary(isDark)),
                  ),
                  trailing: Text(
                    '${opt['quality'] ?? ''} ${opt['format'] ?? ''}'.trim(),
                    style: TextStyle(
                        fontSize: 12, color: PearlColors.textDisabled(isDark)),
                  ),
                  onTap: () => Navigator.pop(ctx, opt['value']?.toString()),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _importWithQuality(Song song, String? quality) async {
    final key = '${song.platform}|${song.id}';
    // Re-tap the same tile or tap another tile while one is in flight:
    // the original behavior disabled all imports while one was running,
    // but the UI now shows a per-tile loading spinner so we keep the
    // single-active rule here.
    if (_importingSongKey != null) return;
    setState(() {
      _importingSongKey = key;
    });
    try {
      final mgr = ref.read(musicManagerProvider);
      final url = await mgr.getUrl(song, quality: quality);
      if (url == null || url.url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('\u83b7\u53d6\u4e0b\u8f7d\u94fe\u63a5\u5931\u8d25'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }

      // 下载到临时文件
      final ext = url.ext ?? (url.url.contains('.flac') ? 'flac' : url.url.contains('.m4a') ? 'm4a' : 'mp3');
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}import_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _downloadFile(url.url, tempPath);

      // 走现有的本地上传逻辑
      final api = ref.read(apiClientProvider);
      final result = await api.uploadSong(tempPath, '${song.singer} - ${song.name}.$ext', type: song.platform);
      final ok = result['ok'] == true;

      // 删除临时文件
      try { await File(tempPath).delete(); } catch (_) {}

      if (!ok) {
        throw Exception(result['error']?.toString() ?? '\u4e0a\u4f20\u5931\u8d25');
      }

      // 上传歌词（如有）
        final lrc = await mgr.getLyric(song);
        if (lrc.isNotEmpty) {
          final songData = result['song'] as Map<String, dynamic>?;
          final songId = songData?['id'] as int?;
          if (songId != null) {
            try { await api.uploadLyric(songId, lrc); } catch (_) {}
          }
        }

        // 刷新曲库列表
        ref.read(songListProvider.notifier).load();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${song.name} \u5df2\u6dfb\u52a0\u5230\u66f2\u5e93'), backgroundColor: const Color(0xFF2E7D32)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\u5bfc\u5165\u5931\u8d25: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _importingSongKey = null;
        });
      }
    }
  }

  Future<void> _downloadFile(String url, String savePath) async {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ));
    await dio.download(url, savePath);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.watch(playerProvider.notifier);
    final playingUrlId = notifier.playingUrlId;
    final playerPhase = ref.watch(playerProvider.select((v) => v.phase));
    final hasSong = playingUrlId != null && playerPhase != PlayerPhase.idle && playerPhase != PlayerPhase.error;
    final showMiniPlayer = ref.watch(showMiniPlayerProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomPadding = bottomInset + 24 + (hasSong && showMiniPlayer ? 80 : 0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: PearlColors.bgPrimary(isDark),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                // Search bar is wrapped in a RepaintBoundary so the result
                // list below can repaint independently during typing.
                RepaintBoundary(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20,
                              color: PearlColors.textPrimary(isDark)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _searchCtrl,
                              focusNode: _focusNode,
                              onChanged: _onQueryChanged,
                              textInputAction: TextInputAction.search,
                              decoration: InputDecoration(
                                hintText: '\u641c\u7d22\u6b4c\u66f2\u6216\u6b4c\u624b...',
                                prefixIcon: Icon(Icons.search_rounded, size: 20,
                                    color: PearlColors.textDisabled(isDark)),
                                filled: true,
                                fillColor: PearlColors.glassBg(isDark),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(PearlTheme.radiusMd),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              style: TextStyle(fontSize: 14, color: PearlColors.textPrimary(isDark)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
                // Result list is its own RepaintBoundary so the search bar
                // above is not re-rasterised when the body updates.
                Expanded(
                  child: RepaintBoundary(
                    child: _buildBody(isDark, bottomPadding, playingUrlId ?? '', playerPhase),
                  ),
                ),
              ],
            ),
            if (hasSong && showMiniPlayer)
              Positioned(
                left: 16,
                right: 16,
                bottom: bottomInset + 12,
                child: const MiniPlayer(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(bool isDark, double bottomPadding) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 12, 8),
          child: Row(
            children: [
              Text('\u641c\u7d22\u5386\u53f2',
                  style: TextStyle(fontSize: 13, color: PearlColors.textDisabled(isDark))),
              const Spacer(),
              GestureDetector(
                onTap: _clearHistory,
                child: Icon(Icons.delete_outline_rounded, size: 18,
                    color: PearlColors.textDisabled(isDark)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.only(bottom: bottomPadding),
            itemCount: _history.length,
            itemBuilder: (_, i) {
              return ListTile(
                dense: true,
                leading: Icon(Icons.history_rounded, size: 18,
                    color: PearlColors.textDisabled(isDark)),
                title: Text(_history[i],
                    style: TextStyle(fontSize: 14, color: PearlColors.textPrimary(isDark))),
                onTap: () {
                  _searchCtrl.text = _history[i];
                  _searchCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _history[i].length));
                  _doSearch(_history[i]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBody(bool isDark, double bottomPadding, String playingUrlId, PlayerPhase playerPhase) {
    final notifier = ref.read(playerProvider.notifier);
    final hasQuery = _searchCtrl.text.trim().isNotEmpty;
    final accent = PearlColors.accent(isDark);
    final hasLocal = _localResults.isNotEmpty;
    final hasOnline = _results.isNotEmpty;
    final showOnlineHeader = _loading || _error.isNotEmpty || hasOnline;

    // No query \u2192 history or idle hint. NEVER swap the whole body
    // for a global loading spinner: local results are filtered
    // synchronously by _updateLocalResults, and a full-body spinner
    // would wipe them and cause a visible flicker when the request
    // resolves.
    if (!hasQuery) {
      if (_history.isNotEmpty) {
        return _buildHistoryList(isDark, bottomPadding);
      }
      return Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.music_note_rounded, size: 56,
                  color: PearlColors.textDisabled(isDark)),
              const SizedBox(height: 16),
              Text('\u641c\u7d22\u672c\u5730 + \u5728\u7ebf\u6b4c\u66f2',
                  style: TextStyle(fontSize: 16, color: PearlColors.textSecondary(isDark))),
              const SizedBox(height: 4),
              Text('\u540c\u65f6\u5339\u914d\u66f2\u5e93\u548c\u5728\u7ebf\u5e73\u53f0',
                  style: TextStyle(fontSize: 13, color: PearlColors.textDisabled(isDark))),
            ],
          ),
        ),
      );
    }

    // Both lists empty and not loading \u2192 empty state.
    if (!hasLocal && !hasOnline && !_loading && _error.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48,
                color: PearlColors.textDisabled(isDark)),
            const SizedBox(height: 12),
            Text('\u6ca1\u6709\u627e\u5230\u76f8\u5173\u6b4c\u66f2',
                style: TextStyle(fontSize: 15, color: PearlColors.textSecondary(isDark))),
            const SizedBox(height: 4),
            Text('\u6362\u4e2a\u5173\u952e\u8bcd\u6216\u7ebf\u8def\u8bd5\u8bd5',
                style: TextStyle(fontSize: 13, color: PearlColors.textDisabled(isDark))),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
      children: [
        if (_localResults.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.library_music_rounded,
            iconColor: const Color(0xFF44D3FF),
            title: '\u672c\u5730\u6b4c\u66f2',
            count: _localResults.length,
            isDark: isDark,
          ),
          for (final s in _localResults)
            _LocalResultTile(
              song: s,
              isDark: isDark,
              isPlaying: notifier.currentSong?.id == s.id,
              playerPhase: playerPhase,
              onTap: () {
                // Update the playlist + start playback BEFORE pushing the
                // player page so the mini player at the bottom of the
                // search page reflects the new track immediately, and so
                // the player page's own initState sees the song as
                // current (its skip-if-current logic kicks in).
                notifier.setPlaylist(_localResults);
                notifier.play(s);
                context.push('/player', extra: s);
              },
            ),
          if (showOnlineHeader) const SizedBox(height: 12),
        ],
        if (showOnlineHeader) ...[
          _SectionHeader(
            icon: _loading ? Icons.cloud_sync_rounded : Icons.cloud_rounded,
            iconColor: PearlColors.accent(isDark),
            title: _loading ? '\u6b63\u5728\u641c\u7d22\u5728\u7ebf' : '\u5728\u7ebf\u7ed3\u679c',
            count: hasOnline ? _results.length : null,
            isDark: isDark,
            // Small inline spinner next to the header so the user
            // sees feedback before any rows land.
            trailing: _loading
                ? SizedBox(
                    width: 12, height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: accent,
                    ),
                  )
                : null,
          ),
          if (_loading)
            _OnlineLoadingPlaceholder(isDark: isDark)
          else if (_error.isNotEmpty)
            _OnlineErrorRow(message: _error, isDark: isDark)
          else
            for (final song in _results)
              _ResultTile(
                song: song,
                isDark: isDark,
                onTap: () => _doPlay(song),
                onImport: () => _doImport(song),
                isPlaying: '${song.platform}|${song.id}' == playingUrlId,
                playerPhase: playerPhase,
                coverFuture: Future.value(
                    (song.cover != null && song.cover!.isNotEmpty) ? song.cover : null),
                isImporting: _importingSongKey == '${song.platform}|${song.id}',
              ),
        ],
      ],
    );
  }
}

Widget _placeholderIcon(Color badgeColor, IconData icon) {
  return Container(
    decoration: BoxDecoration(
      color: badgeColor.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 22, color: badgeColor),
  );
}


class _ResultTile extends StatelessWidget {
  final Song song;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onImport;
  final bool isPlaying;
  final PlayerPhase playerPhase;
  final Future<String?> coverFuture;
  final bool isImporting;

  const _ResultTile({
    required this.song,
    required this.isDark,
    required this.onTap,
    required this.onImport,
    required this.playerPhase,
    required this.coverFuture,
    this.isPlaying = false,
    this.isImporting = false,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = MusicPlatformMeta.color(song.platform, isDark);
    final accentColor = PearlColors.accent(isDark);
    final platformIcon = MusicPlatformMeta.iconCached(song.platform, 22);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    FutureBuilder<String?>(
                      future: coverFuture,
                      builder: (_, snap) {
                        final hasCover = snap.hasData && snap.data != null;
                        return Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: hasCover
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(snap.data!, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _placeholderIcon(badgeColor, Icons.music_note_rounded)),
                                  ],
                                )
                              : _placeholderIcon(badgeColor, Icons.music_note_rounded),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  song.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: PearlColors.textPrimary(isDark),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              platformIcon,
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${song.singer}${song.album != null && song.album!.isNotEmpty ? " \u8def ${song.album}" : ""}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: PearlColors.textSecondary(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onTap,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                  isPlaying && playerPhase == PlayerPhase.playing
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 18, color: accentColor,
                                ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isImporting ? null : onImport,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF44D3FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: isImporting
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF44D3FF),
                                      ),
                                    )
                                  : const Icon(Icons.download_rounded, size: 16, color: Color(0xFF44D3FF)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 1,
              child: Container(
                margin: const EdgeInsets.only(left: 72),
                color: PearlColors.textDisabled(isDark).withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final int? count;
  final bool isDark;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.count,
    required this.isDark,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PearlColors.textSecondary(isDark),
                letterSpacing: 0.2,
              )),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text('· $count',
                style: TextStyle(
                  fontSize: 12,
                  color: PearlColors.textDisabled(isDark),
                )),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Three small dots under the "正在搜索在线" header to give the user
/// feedback while a network request is in flight. Stays at a fixed
/// height so the layout doesn't shift when results arrive.
class _OnlineLoadingPlaceholder extends StatefulWidget {
  final bool isDark;
  const _OnlineLoadingPlaceholder({required this.isDark});

  @override
  State<_OnlineLoadingPlaceholder> createState() =>
      _OnlineLoadingPlaceholderState();
}

class _OnlineLoadingPlaceholderState extends State<_OnlineLoadingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          // Three dots that fade in/out with staggered phases.
          Widget dot(double phase) {
            final t = (_ctrl.value + phase) % 1.0;
            // Smooth bell curve: peaks at 0.5, falls off at the ends.
            final a = 0.25 + 0.75 * (1 - (2 * t - 1).abs());
            return Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: PearlColors.textSecondary(widget.isDark)
                    .withValues(alpha: a * 0.8),
                shape: BoxShape.circle,
              ),
            );
          }

          return Row(
            children: [
              dot(0.0),
              const SizedBox(width: 6),
              dot(0.33),
              const SizedBox(width: 6),
              dot(0.66),
            ],
          );
        },
      ),
    );
  }
}

/// Compact error row shown under the online header when the request
/// failed. The local section above it remains visible, so the user
/// keeps their instant feedback even if the network is down.
class _OnlineErrorRow extends StatelessWidget {
  final String message;
  final bool isDark;
  const _OnlineErrorRow({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: 16,
              color: PearlColors.textDisabled(isDark)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: PearlColors.textSecondary(isDark),
                )),
          ),
        ],
      ),
    );
  }
}

class _LocalResultTile extends StatelessWidget {
  final local_song.Song song;
  final bool isDark;
  final VoidCallback onTap;
  final bool isPlaying;
  final PlayerPhase playerPhase;

  const _LocalResultTile({
    required this.song,
    required this.isDark,
    required this.onTap,
    this.isPlaying = false,
    this.playerPhase = PlayerPhase.idle,
  });

  @override
  Widget build(BuildContext context) {
    final textP = PearlColors.textPrimary(isDark);
    final textS = PearlColors.textSecondary(isDark);
    final textD = PearlColors.textDisabled(isDark);
    const accent = Color(0xFF44D3FF);
    final highlight = isPlaying;
    final titleColor = highlight ? accent : textP;
    final iconBg = highlight
        ? accent.withValues(alpha: 0.22)
        : accent.withValues(alpha: 0.12);
    // Match the online tile's behaviour: show pause when this is the
    // current track and the player is actively playing, otherwise show
    // play.
    final showPause = highlight && playerPhase == PlayerPhase.playing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: highlight ? accent.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.music_note_rounded,
                      size: 22, color: accent.withValues(alpha: 0.85)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 15,
                            fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                          )),
                      const SizedBox(height: 2),
                      Text('${song.artist} · ${song.durationFormatted}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: textS, fontSize: 12)),
                    ],
                  ),
                ),
                if (!song.hasLyric)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(Icons.lyrics_outlined, size: 14, color: textD),
                  ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    showPause
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 18,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

