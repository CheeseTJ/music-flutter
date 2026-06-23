import 'package:dio/dio.dart';
import '../models/song.dart';

/// Ausearcher 音乐搜索 API — ausearcher.com/music/
/// 搜索返回直接 mp3 URL 和内联歌词，无需二次请求
class AusearcherProvider {
  final Dio _dio;

  static const _base = 'https://ausearcher.com/music/';

  AusearcherProvider(this._dio);

  /// 搜索
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
            'origin': 'https://ausearcher.com',
            'referer': 'https://ausearcher.com/music/',
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
          source: 'ausearcher',
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

  /// 获取播放链接 — 搜索结果中已包含直链，直接从 extra 取
  Future<SongUrl?> getUrl(Song song) async {
    final url = song.extra?['url']?.toString();
    final lrc = song.extra?['lrc']?.toString();
    if (url == null || url.isEmpty) return null;
    return SongUrl(url: url, lrc: lrc, source: 'ausearcher', ext: url.contains('.m4a') ? 'm4a' : url.contains('.flac') ? 'flac' : 'mp3');
  }
}