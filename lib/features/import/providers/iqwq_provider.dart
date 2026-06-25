import 'package:dio/dio.dart';
import '../models/song.dart';

class IqwqProvider {
  final Dio _dio;
  final String _base;
  final String _origin;

  IqwqProvider(this._dio, {required String baseUrl})
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
        final url = item['url']?.toString();
        final lrc = item['lrc']?.toString();
        return Song(
          platform: musicType,
          source: 'iqwq',
          id: item['songid']?.toString() ?? '',
          name: item['title']?.toString() ?? '',
          singer: item['author']?.toString() ?? '',
          cover: item['pic']?.toString(),
          extra: {
            if (url != null && url.isNotEmpty) 'url': url,
            if (lrc != null && lrc.isNotEmpty) 'lrc': lrc,
          },
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<SongUrl?> getUrl(Song song) async {
    final url = song.extra?['url']?.toString();
    final lrc = song.extra?['lrc']?.toString();
    if (url == null || url.isEmpty) return null;
    return SongUrl(url: url, lrc: lrc, source: 'iqwq', ext: url.contains('.m4a') ? 'm4a' : url.contains('.flac') ? 'flac' : 'mp3');
  }
}
