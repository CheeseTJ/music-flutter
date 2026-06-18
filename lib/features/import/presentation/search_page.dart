import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:music_app/core/theme/pearl_colors.dart';
import 'package:music_app/core/theme/pearl_theme.dart';
import 'package:music_app/features/player/providers/player_provider.dart';
import 'package:music_app/features/import/models/song.dart';
import 'package:music_app/features/import/music_manager.dart';
import 'package:music_app/data/datasources/remote/api_client.dart';
import 'package:music_app/core/network/itunes_cover_service.dart';
import 'package:music_app/shared/widgets/mini_player.dart';

enum _SearchSource {
  netease,
  qq,
  kuwo,
  kugou;

  String get label {
    switch (this) {
      case _SearchSource.netease:
        return '\u7f51\u6613\u4e91';
      case _SearchSource.qq:
        return 'QQ';
      case _SearchSource.kuwo: return '\u9177\u6211';
      case _SearchSource.kugou: return '\u9177\u72d7';
    }
  }

  IconData get icon {
    switch (this) {
      case _SearchSource.netease: return Icons.cloud_rounded;
      case _SearchSource.qq: return Icons.chat_bubble_outline_rounded;
      case _SearchSource.kuwo: return Icons.headphones_rounded;
      case _SearchSource.kugou: return Icons.surround_sound_rounded;
    }
  }

  Color color(bool isDark) {
    switch (this) {
      case _SearchSource.netease: return const Color(0xFFEC4141);
      case _SearchSource.qq: return const Color(0xFF31C27C);
      case _SearchSource.kuwo: return const Color(0xFFFFCC00);
      case _SearchSource.kugou: return const Color(0xFF2D8CF0);
    }
  }

  String get platformKey {
    switch (this) {
      case _SearchSource.netease: return 'netease';
      case _SearchSource.qq: return 'qq';
      case _SearchSource.kuwo: return 'kuwo';
      case _SearchSource.kugou: return 'kugou';
    }
  }

  Widget platformIcon(double size) {
    final asset = switch (this) {
      _SearchSource.netease => 'assets/icons/\u7f51\u6613\u4e91\u97f3\u4e50.svg',
      _SearchSource.qq => 'assets/icons/QQ\u97f3\u4e50.svg',
      _SearchSource.kuwo => 'assets/icons/kuwo.svg',
      _SearchSource.kugou => 'assets/icons/\u9177\u72d7.svg',
    };
    return SvgPicture.asset(asset, width: size, height: size, fit: BoxFit.contain);
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
  bool _importingSong = false;
  final _coverService = const ITunesCoverService();
  final Map<String, String?> _coverCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
    _loadSavedSource();
  }

  Future<void> _loadSavedSource() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('search_source');
    if (saved != null) {
      final src = _SearchSource.values.where((s) => s.platformKey == saved).firstOrNull;
      if (src != null && mounted) setState(() => _activeSource = src);
    }
  }

  Future<String?> _loadCover(String title, String artist) {
    final key = '${title}_$artist';
    if (_coverCache.containsKey(key)) return Future.value(_coverCache[key]);
    return _coverService.fetchUrl(title, artist).then((url) {
      _coverCache[key] = url;
      return url;
    });
  }

  Future<void> _onSourceChanged(_SearchSource src) async {
    setState(() => _activeSource = src);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('search_source', src.platformKey);
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

    try {
      final mgr = ref.read(musicManagerProvider);
      final platform = _activeSource.platformKey;
      final results = await mgr.search(platform, query);

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
            SnackBar(
              content: Text('\u83b7\u53d6\u64ad\u653e\u94fe\u63a5\u5931\u8d25'),
              backgroundColor: Colors.redAccent,
            ),
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
      final api = ref.read(apiClientProvider);
      await api.downloadFromUrl(url.url, song.name, song.singer);
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
          coverFuture: song.cover != null && song.cover!.isNotEmpty
              ? Future.value(song.cover)
              : _loadCover(song.name, song.singer),
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
      (s) => s.platformKey == song.platform,
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

