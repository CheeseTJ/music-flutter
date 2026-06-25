import 'package:dio/dio.dart';
import '../models/song.dart';

class Netease90SvipProvider {
  final Dio _dio;
  final String _base;
  final String _origin;

  Netease90SvipProvider(this._dio, {required String baseUrl})
      : _base = baseUrl,
        _origin = Uri.parse(baseUrl).origin;

  Future<List<Song>> search(String keyword, {String musicType = 'netease', int page = 1}) async {
    try {
      final resp = await _dio.post(
        _base,
        data: {
          'input': keyword,
          'filter': 'name',
          'type': musicType,
          'page': page,
        },
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: {
            'x-requested-with': 'XMLHttpRequest',
            'origin': _origin,
            'referer': _base,
          },
        ),
      );

      final data = resp.data as Map<String, dynamic>?;
      final list = data?['data'] as List? ?? [];
      return list.map((item) {
        final lrcPath = item['lrc']?.toString();
        final urlPath = item['url']?.toString();
        final coverPath = item['cover']?.toString();
        return Song(
          platform: musicType,
          source: 'net90svip',
          id: item['songid']?.toString() ?? '',
          name: item['name']?.toString() ?? '',
          singer: item['artist']?.toString() ?? '',
          cover: coverPath != null && coverPath.isNotEmpty
              ? '$_base$coverPath'
              : null,
          extra: {
            if (lrcPath != null && lrcPath.isNotEmpty) 'lrc_url': '$_base$lrcPath',
            if (urlPath != null && urlPath.isNotEmpty) 'url_path': '$_base$urlPath',
          },
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<SongUrl?> getUrl(Song song) async {
    final urlPath = song.extra?['url_path']?.toString();
    if (urlPath == null || urlPath.isEmpty) return null;

    final ext = urlPath.contains('.m4a') ? 'm4a'
        : urlPath.contains('.flac') ? 'flac'
            : 'mp3';

    String? lrc;
    try {
      lrc = await _fetchLrc(song);
    } catch (_) {}

    return SongUrl(url: urlPath, lrc: lrc, source: 'net90svip', ext: ext);
  }

  Future<String?> fetchLrc(Song song) => _fetchLrc(song);

  Future<String?> _fetchLrc(Song song) async {
    final lrcUrl = song.extra?['lrc_url']?.toString();
    if (lrcUrl == null || lrcUrl.isEmpty) return null;

    try {
      final resp = await _dio.get(lrcUrl);
      final data = resp.data;
      if (data is Map) {
        return data['lyric']?.toString() ?? data['lrc']?.toString();
      }
      return data?.toString();
    } catch (_) {
      return null;
    }
  }
}
