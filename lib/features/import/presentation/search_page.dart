import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/core/theme/pearl_colors.dart';
import 'package:music_app/core/theme/pearl_theme.dart';
import 'package:music_app/features/player/providers/player_provider.dart';
import 'package:music_app/features/collection/providers/song_list_provider.dart';
import 'package:music_app/features/import/models/song.dart';
import 'package:music_app/features/import/music_manager.dart';
import 'package:music_app/data/datasources/remote/api_client.dart';
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
}
enum _SearchSource {
  netease,
  bingdou,
  net90svip,
  ausearcher,
  iqwq;

  String get label {
    switch (this) {
      case _SearchSource.netease: return 'netease';
      case _SearchSource.bingdou: return '\u51b0\u8c46';
      case _SearchSource.net90svip: return '90Svip';
      case _SearchSource.ausearcher: return 'AuSearch';
      case _SearchSource.iqwq: return 'iwqw';
    }
  }

  IconData get icon {
    switch (this) {
      case _SearchSource.netease: return Icons.cloud_rounded;
      case _SearchSource.bingdou: return Icons.ac_unit_rounded;
      case _SearchSource.net90svip: return Icons.language_rounded;
      case _SearchSource.ausearcher: return Icons.travel_explore_rounded;
      case _SearchSource.iqwq: return Icons.waves_rounded;
    }
  }

  Color color(bool isDark) {
    switch (this) {
      case _SearchSource.netease: return const Color(0xFFEC4141);
      case _SearchSource.bingdou: return const Color(0xFF4FC3F7);
      case _SearchSource.net90svip: return const Color(0xFF26A69A);
      case _SearchSource.ausearcher: return const Color(0xFFFF7043);
      case _SearchSource.iqwq: return const Color(0xFFAB47BC);
    }
  }

  String get sourceKey {
    switch (this) {
      case _SearchSource.netease: return 'netease';
      case _SearchSource.bingdou: return 'bingdou';
      case _SearchSource.net90svip: return 'net90svip';
      case _SearchSource.ausearcher: return 'ausearcher';
      case _SearchSource.iqwq: return 'iqwq';
    }
  }

  Widget platformIcon(double size) {
    final asset = switch (this) {
      _SearchSource.netease => 'assets/icons/\u7f51\u6613\u4e91\u97f3\u4e50.svg',
      _SearchSource.bingdou => null,
      _SearchSource.net90svip => null,
      _SearchSource.ausearcher => null,
      _SearchSource.iqwq => null,
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
}

class InternetSearchPage extends ConsumerStatefulWidget {
  const InternetSearchPage({super.key});

  @override
  ConsumerState<InternetSearchPage> createState() => _InternetSearchPageState();
}

class _InternetSearchPageState extends ConsumerState<InternetSearchPage> {
  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  List<Song> _results = [];
  bool _loading = false;
  String _error = '';
  _SearchSource _activeSource = _SearchSource.netease;
  _MusicPlatform _activePlatform = _MusicPlatform.netease;
  bool _importingSong = false;
  final _platformCover = const PlatformCoverService();
  List<String> _history = [];
  static const _historyKey = 'search_history';
  static const _maxHistory = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _loadSavedSource();
    _loadSavedPlatform();
    _loadHistory();
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
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = '';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
      _results = [];
    });

    _saveHistory(query);

    try {
      final mgr = ref.read(musicManagerProvider);
      final source = _activeSource.sourceKey;
      final musicType = _activePlatform.typeKey;
      final results = await mgr.search(source, musicType, query);

      if (mounted) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
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
    if (_importingSong) return;
    setState(() => _importingSong = true);
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
      if (mounted) setState(() => _importingSong = false);
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
    final playingUrlId = ref.watch(playerProvider.notifier).playingUrlId;
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
                Padding(
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
                            onChanged: (v) => _doSearch(v),
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
                      const SizedBox(width: 2),
                      _PlatformDropdown(
                        activeSource: _activeSource,
                        isDark: isDark,
                        onChanged: _onSourceChanged,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildBody(isDark, bottomPadding, playingUrlId ?? '', playerPhase),
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
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PearlColors.accent(isDark),
          ),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48,
                  color: PearlColors.textDisabled(isDark)),
              const SizedBox(height: 12),
              Text(_error, textAlign: TextAlign.center,
                  style: TextStyle(color: PearlColors.textSecondary(isDark), fontSize: 14)),
            ],
          ),
        ),
      );
    }

    if (_searchCtrl.text.trim().isEmpty) {
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
              Text('\u641c\u7d22\u4f60\u559c\u6b22\u7684\u97f3\u4e50',
                  style: TextStyle(fontSize: 16, color: PearlColors.textSecondary(isDark))),
              const SizedBox(height: 4),
              Text('\u5207\u6362\u7ebf\u8def\u641c\u7d22\u4e0d\u540c\u5e73\u53f0\u7684\u6b4c\u66f2',
                  style: TextStyle(fontSize: 13, color: PearlColors.textDisabled(isDark))),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
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

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final song = _results[i];
        final songId = '${song.platform}|${song.id}';
        return _ResultTile(
          song: song,
          isDark: isDark,
          onTap: () => _doPlay(song),
          onImport: () => _doImport(song),
          isPlaying: songId == playingUrlId,
          playerPhase: playerPhase,
          coverFuture: _resolveCover(song.name, song.singer, song.cover, song.platform),
        );
      },
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
    return GestureDetector(
      onTapDown: (d) => _showMenu(context, d.globalPosition),
      child: activePlatform.platformIcon(30),
    );
  }

  void _showMenu(BuildContext context, Offset position) {
    final items = _MusicPlatform.values.map((plat) {
      final active = plat == activePlatform;
      return PopupMenuItem<_MusicPlatform>(
        value: plat,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            plat.platformIcon(22),
            const SizedBox(width: 8),
            Text(plat.label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: active ? plat.color(isDark) : PearlColors.textPrimary(isDark),
            )),
          ],
        ),
      );
    }).toList();

    showMenu<_MusicPlatform>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy + 4, position.dx, position.dy),
      elevation: 4,
      color: PearlColors.bgSecondary(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: items,
    ).then((value) {
      if (value != null) onChanged(value);
    });
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
    return GestureDetector(
      onTapDown: (d) => _showMenu(context, d.globalPosition),
      child: activeSource.platformIcon(30),
    );
  }

  void _showMenu(BuildContext context, Offset position) {
    final items = _SearchSource.values.map((src) {
      final active = src == activeSource;
      return PopupMenuItem<_SearchSource>(
        value: src,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            src.platformIcon(22),
            const SizedBox(width: 8),
            Text(src.label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: active ? src.color(isDark) : PearlColors.textPrimary(isDark),
            )),
          ],
        ),
      );
    }).toList();

    showMenu<_SearchSource>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy + 4, position.dx, position.dy),
      elevation: 4,
      color: PearlColors.bgSecondary(isDark),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: items,
    ).then((value) {
      if (value != null) onChanged(value);
    });
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

  const _ResultTile({
    required this.song,
    required this.isDark,
    required this.onTap,
    required this.onImport,
    required this.playerPhase,
    required this.coverFuture,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context) {
    final platformEnum = _SearchSource.values.firstWhere(
      (s) => s.sourceKey == song.platform,
      orElse: () => _SearchSource.netease,
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
                            onTap: onImport,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF44D3FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF44D3FF)),
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

