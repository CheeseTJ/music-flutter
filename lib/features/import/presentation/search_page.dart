import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/theme/pearl_theme.dart';
import '../../player/providers/player_provider.dart';

enum _SearchSource {
  itunes,
  migu,
  netease,
  qq;

  String get label {
    switch (this) {
      case _SearchSource.itunes:
        return 'iTunes';
      case _SearchSource.migu:
        return '咪咕';
      case _SearchSource.netease:
        return '网易云';
      case _SearchSource.qq:
        return 'QQ';
    }
  }

  IconData get icon {
    switch (this) {
      case _SearchSource.itunes:
        return Icons.apple_rounded;
      case _SearchSource.migu:
        return Icons.music_note_rounded;
      case _SearchSource.netease:
        return Icons.cloud_rounded;
      case _SearchSource.qq:
        return Icons.chat_bubble_outline_rounded;
    }
  }

  Color color(bool isDark) {
    switch (this) {
      case _SearchSource.itunes:
        return const Color(0xFFFC3C44);
      case _SearchSource.migu:
        return const Color(0xFF00B4FF);
      case _SearchSource.netease:
        return const Color(0xFFEC4141);
      case _SearchSource.qq:
        return const Color(0xFF31C27C);
    }
  }
}

class _SearchResult {
  final String trackName;
  final String artistName;
  final String collectionName;
  final int durationMs;
  final String artworkUrl;
  final String? previewUrl;
  final _SearchSource source;
  Uint8List? artwork;

  _SearchResult({
    required this.trackName,
    required this.artistName,
    required this.collectionName,
    required this.durationMs,
    required this.artworkUrl,
    required this.source,
    this.previewUrl,
  });

  String get durationFormatted {
    final totalSec = durationMs ~/ 1000;
    final m = totalSec ~/ 60;
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  factory _SearchResult.fromJson(Map<String, dynamic> json, _SearchSource source) {
    return _SearchResult(
      trackName: json['trackName'] as String? ?? '',
      artistName: json['artistName'] as String? ?? '',
      collectionName: json['collectionName'] as String? ?? '',
      durationMs: json['trackTimeMillis'] as int? ?? 0,
      artworkUrl: (json['artworkUrl100'] as String? ?? '').replaceAll('100x100bb', '600x600bb'),
      previewUrl: json['previewUrl'] as String?,
      source: source,
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
  List<_SearchResult> _results = [];
  bool _loading = false;
  String _error = '';
  _SearchSource _activeSource = _SearchSource.itunes;

  static final Map<int, Uint8List> _artCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
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
      final results = await _searchSource(query);
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

  Future<List<_SearchResult>> _searchSource(String term) async {
    switch (_activeSource) {
      case _SearchSource.itunes:
        return _searchITunes(term);
      case _SearchSource.migu:
      case _SearchSource.netease:
      case _SearchSource.qq:
        throw Exception('${_activeSource.label}搜索暂未接入');
    }
  }

  Future<List<_SearchResult>> _searchITunes(String term) async {
    final encoded = Uri.encodeComponent(term);
    final url = 'https://itunes.apple.com/search?term=$encoded&limit=30&country=cn&media=music';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'MusicApp/1.0');
      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) {
        throw Exception('搜索服务异常 (${resp.statusCode})');
      }

      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final list = data['results'] as List? ?? [];

      return list
          .map((e) => _SearchResult.fromJson(e as Map<String, dynamic>, _SearchSource.itunes))
          .where((r) => r.trackName.isNotEmpty)
          .toList();
    } finally {
      client.close();
    }
  }

  Future<void> _fetchArtwork(_SearchResult result) async {
    if (result.artworkUrl.isEmpty) return;
    final key = result.artworkUrl.hashCode;
    if (_artCache.containsKey(key)) {
      result.artwork = _artCache[key];
      return;
    }

    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      try {
        final req = await client.getUrl(Uri.parse(result.artworkUrl));
        final resp = await req.close().timeout(const Duration(seconds: 6));
        if (resp.statusCode != 200) return;

        final sink = BytesBuilder(copy: false);
        await for (final chunk in resp) {
          sink.add(chunk);
          if (sink.length > 262144) break;
        }
        final bytes = sink.takeBytes();
        _artCache[key] = bytes;
        result.artwork = bytes;
      } finally {
        client.close();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: PearlColors.bgPrimary(isDark),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
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
                          hintText: '搜索歌曲或歌手...',
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
                ],
              ),
            ),
            _SourceBar(
              activeSource: _activeSource,
              isDark: isDark,
              onChanged: (src) {
                setState(() => _activeSource = src);
                _doSearch(_searchCtrl.text);
              },
            ),
            Expanded(
              child: _buildBody(isDark, bottomPadding),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, double bottomPadding) {
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
              Text('搜索你喜欢的音乐',
                  style: TextStyle(fontSize: 16, color: PearlColors.textSecondary(isDark))),
              const SizedBox(height: 4),
              Text('切换线路搜索不同平台的歌曲',
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
            Text('没有找到相关歌曲',
                style: TextStyle(fontSize: 15, color: PearlColors.textSecondary(isDark))),
            const SizedBox(height: 4),
            Text('换个关键词或线路试试',
                style: TextStyle(fontSize: 13, color: PearlColors.textDisabled(isDark))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8, bottom: bottomPadding),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final result = _results[i];
        _fetchArtwork(result);
        return _ResultTile(
          result: result,
          isDark: isDark,
          onTap: () {
            final notifier = ref.read(playerProvider.notifier);
            if (result.previewUrl != null) {
              notifier.playUrl(result.previewUrl!, result.trackName, result.artistName);
            }
          },
        );
      },
    );
  }
}

class _SourceBar extends StatelessWidget {
  final _SearchSource activeSource;
  final bool isDark;
  final ValueChanged<_SearchSource> onChanged;

  const _SourceBar({
    required this.activeSource,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _SearchSource.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final source = _SearchSource.values[i];
          final active = source == activeSource;
          final color = source.color(isDark);

          return GestureDetector(
            onTap: () => onChanged(source),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? color.withValues(alpha: 0.15) : PearlColors.glassBg(isDark),
                borderRadius: BorderRadius.circular(20),
                border: active ? Border.all(color: color.withValues(alpha: 0.4), width: 1) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(source.icon, size: 14, color: active ? color : PearlColors.textDisabled(isDark)),
                  const SizedBox(width: 6),
                  Text(
                    source.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? color : PearlColors.textSecondary(isDark),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final _SearchResult result;
  final bool isDark;
  final VoidCallback onTap;

  const _ResultTile({
    required this.result,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sourceColor = result.source.color(isDark);

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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: result.artwork != null
                          ? Image.memory(result.artwork!, width: 48, height: 48, fit: BoxFit.cover)
                          : Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: PearlColors.glassBg(isDark),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.music_note_rounded, size: 22,
                                  color: PearlColors.textDisabled(isDark)),
                            ),
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
                                  result.trackName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: PearlColors.textPrimary(isDark),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: sourceColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  result.source.label,
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: sourceColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${result.artistName}${result.collectionName.isNotEmpty ? " · ${result.collectionName}" : ""}',
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
                    Text(
                      result.durationFormatted,
                      style: TextStyle(
                        fontSize: 11,
                        color: PearlColors.textDisabled(isDark),
                      ),
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
