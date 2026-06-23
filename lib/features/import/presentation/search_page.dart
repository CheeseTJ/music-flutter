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
import 'package:music_app/core/network/platform_cover_service.dart';
import 'package:music_app/shared/widgets/mini_player.dart';



enum _MusicPlatform {
  netease,
  qq;

  String get label {
    switch (this) {
      case _MusicPlatform.netease: return '\u7f51\u6613\u4e91';
      case _MusicPlatform.qq: return 'QQ\u97f3\u4e50';
    }
  }

  IconData get icon {
    switch (this) {
      case _MusicPlatform.netease: return Icons.cloud_rounded;
      case _MusicPlatform.qq: return Icons.music_note_rounded;
    }
  }

  Color color(bool isDark) {
    switch (this) {
      case _MusicPlatform.netease: return const Color(0xFFEC4141);
      case _MusicPlatform.qq: return const Color(0xFF31C27C);
    }
  }

  String get typeKey {
    switch (this) {
      case _MusicPlatform.netease: return 'netease';
      case _MusicPlatform.qq: return 'qq';
    }
  }

  Widget platformIcon(double size) {
    final asset = switch (this) {
      _MusicPlatform.netease => 'assets/icons/网易云音乐.svg',
      _MusicPlatform.qq => 'assets/icons/QQ音乐.svg',
    };
    return SvgPicture.asset(asset, width: size, height: size, fit: BoxFit.contain);
  }

  /// Memoised icon cache keyed by (platform, size). Without this, the
  /// dropdown trigger and menu item re-create the SvgPicture on every
  /// rebuild, which forces the SVG parser to re-evaluate.
  static final Map<(int, double), Widget> _iconCache = {};
  Widget platformIconCached(double size) {
    final key = (index, size);
    return _iconCache.putIfAbsent(key, () => platformIcon(size));
  }
}
enum _SearchSource {
  net90svip,
  bingdou,
  iqwq,
  ausearcher,
  meting;

  String get label {
    switch (this) {
      case _SearchSource.net90svip: return '90Svip';
      case _SearchSource.bingdou: return 'BingDou';
      case _SearchSource.iqwq: return 'Iwqw';
      case _SearchSource.ausearcher: return 'AuSearch';
      case _SearchSource.meting: return 'meting';
    }
  }

  IconData get icon {
    switch (this) {
      case _SearchSource.net90svip: return Icons.language_rounded;
      case _SearchSource.bingdou: return Icons.ac_unit_rounded;
      case _SearchSource.iqwq: return Icons.waves_rounded;
      case _SearchSource.ausearcher: return Icons.travel_explore_rounded;
      case _SearchSource.meting: return Icons.cloud_rounded;
    }
  }

  Color color(bool isDark) {
    switch (this) {
      case _SearchSource.net90svip: return const Color(0xFF26A69A);
      case _SearchSource.bingdou: return const Color(0xFF4FC3F7);
      case _SearchSource.iqwq: return const Color(0xFFAB47BC);
      case _SearchSource.ausearcher: return const Color(0xFFFF7043);
      case _SearchSource.meting: return const Color(0xFFEC4141);
    }
  }

  String get sourceKey {
    switch (this) {
      case _SearchSource.net90svip: return 'net90svip';
      case _SearchSource.bingdou: return 'bingdou';
      case _SearchSource.iqwq: return 'iqwq';
      case _SearchSource.ausearcher: return 'ausearcher';
      case _SearchSource.meting: return 'netease';
    }
  }

  Widget platformIcon(double size) {
    final asset = switch (this) {
      _SearchSource.net90svip => null,
      _SearchSource.bingdou => null,
      _SearchSource.iqwq => null,
      _SearchSource.ausearcher => null,
      _SearchSource.meting => 'assets/icons/\u7f51\u6613\u4e91\u97f3\u4e50.svg',
    };
    if (asset != null) {
      return SvgPicture.asset(asset, width: size, height: size, fit: BoxFit.contain);
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color(true).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Icon(icon, size: size * 0.7, color: color(true)),
    );
  }

  /// Memoised icon cache keyed by (source, size).
  static final Map<(int, double), Widget> _iconCache = {};
  Widget platformIconCached(double size) {
    final key = (index, size);
    return _iconCache.putIfAbsent(key, () => platformIcon(size));
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
  _SearchSource _activeSource = _SearchSource.meting;
  _MusicPlatform _activePlatform = _MusicPlatform.netease;
  /// Song currently being imported: key is "${platform}|${id}" so multiple
  /// tiles can be in different import states (one loading, one idle, one
  /// failed). `null` means no active import.
  String? _importingSongKey;
  final _platformCover = const PlatformCoverService();
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
    _loadSavedSource();
    _loadSavedPlatform();
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

  Future<void> _loadSavedSource() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('search_source');
    if (saved != null) {
      final src = _SearchSource.values.where((s) => s.sourceKey == saved).firstOrNull;
      if (src != null && mounted) setState(() => _activeSource = src);
    }
  }

  Future<String?> _resolveCover(String title, String artist, String? coverUrl, String type) async {
    if (coverUrl != null && coverUrl.isNotEmpty) {
      try {
        final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 2)));
        final resp = await dio.head(coverUrl);
        if (resp.statusCode == 200) return coverUrl;
      } catch (_) {}
    }
    return _platformCover.fetchUrl(type, title, artist);
  }

  Future<void> _loadSavedPlatform() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('music_platform');
    if (saved != null) {
      final plat = _MusicPlatform.values.where((p) => p.typeKey == saved).firstOrNull;
      if (plat != null && mounted) setState(() => _activePlatform = plat);
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

  Future<void> _onPlatformChanged(_MusicPlatform plat) async {
    if (plat == _activePlatform) return;
    setState(() => _activePlatform = plat);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('music_platform', plat.typeKey);
    _doSearch(_searchCtrl.text);
  }
  Future<void> _onSourceChanged(_SearchSource src) async {
    setState(() => _activeSource = src);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('search_source', src.sourceKey);
    _doSearch(_searchCtrl.text);
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
      final source = _activeSource.sourceKey;
      final musicType = _activePlatform.typeKey;
      final results = await mgr.search(source, musicType, q);

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
      final url = await mgr.getUrl(song);
      if (url == null || url.url.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('\u83b7\u53d6\u64ad\u653e\u94fe\u63a5\u5931\u8d25'), backgroundColor: Colors.redAccent),
          );
        }
        return;
      }
      final notifier = ref.read(playerProvider.notifier);
      await notifier.playUrl(url.url, song.name, song.singer,
          platform: song.platform, id: song.id, lyric: url.lrc);
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

  Future<void> _doImport(Song song) async {
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
      final url = await mgr.getUrl(song);
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
        if (url.lrc != null && url.lrc!.isNotEmpty) {
          final songData = result['song'] as Map<String, dynamic>?;
          final songId = songData?['id'] as int?;
          if (songId != null) {
            try { await api.uploadLyric(songId, url.lrc!); } catch (_) {}
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
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bottomPadding = bottomInset + 24 + (hasSong ? 80 : 0);

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
                        _MusicPlatformDropdown(
                          activePlatform: _activePlatform,
                          isDark: isDark,
                          onChanged: _onPlatformChanged,
                        ),
                        const SizedBox(width: 8),
                        _PlatformDropdown(
                          activeSource: _activeSource,
                          isDark: isDark,
                          onChanged: _onSourceChanged,
                        ),
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
            if (hasSong)
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
                coverFuture: _resolveCover(song.name, song.singer, song.cover, song.platform),
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


class _MusicPlatformDropdown extends StatelessWidget {
  final _MusicPlatform activePlatform;
  final bool isDark;
  final ValueChanged<_MusicPlatform> onChanged;

  const _MusicPlatformDropdown({
    required this.activePlatform,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // PopupMenuButton has built-in hit-testing and a smoother Material
    // transition than GestureDetector + showMenu, so it removes the
    // adjacent-tap misfires that made the previous implementation feel
    // janky.
    return PopupMenuButton<_MusicPlatform>(
      tooltip: '',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      elevation: 8,
      color: PearlColors.bgSecondary(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onChanged,
      itemBuilder: (_) => _MusicPlatform.values.map((plat) {
        final active = plat == activePlatform;
        return PopupMenuItem<_MusicPlatform>(
          value: plat,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              plat.platformIconCached(22),
              const SizedBox(width: 8),
              Text(plat.label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: active ? plat.color(isDark) : PearlColors.textPrimary(isDark),
              )),
            ],
          ),
        );
      }).toList(),
      child: activePlatform.platformIconCached(30),
    );
  }
}
class _PlatformDropdown extends StatelessWidget {
  final _SearchSource activeSource;
  final bool isDark;
  final ValueChanged<_SearchSource> onChanged;

  const _PlatformDropdown({
    required this.activeSource,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SearchSource>(
      tooltip: '',
      position: PopupMenuPosition.under,
      offset: const Offset(0, 6),
      elevation: 8,
      color: PearlColors.bgSecondary(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onChanged,
      itemBuilder: (_) => _SearchSource.values.map((src) {
        final active = src == activeSource;
        return PopupMenuItem<_SearchSource>(
          value: src,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              src.platformIconCached(22),
              const SizedBox(width: 8),
              Text(src.label, style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: active ? src.color(isDark) : PearlColors.textPrimary(isDark),
              )),
            ],
          ),
        );
      }).toList(),
      child: activeSource.platformIconCached(30),
    );
  }
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
    final platformEnum = _SearchSource.values.firstWhere(
      (s) => s.sourceKey == song.platform,
      orElse: () => _SearchSource.meting,
    );
    final platformColor = platformEnum.color(isDark);
    final isMeting = song.source == 'meting';
    final badgeColor = isMeting ? PearlColors.textSecondary(isDark) : platformColor;
    final accentColor = PearlColors.accent(isDark);

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
                                      errorBuilder: (_, __, ___) => _placeholderIcon(badgeColor, platformEnum.icon)),
                                  ],
                                )
                              : _placeholderIcon(badgeColor, platformEnum.icon),
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

