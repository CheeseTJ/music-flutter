import 'package:dio/dio.dart';
import '../models/song.dart';

/// 冰豆音乐搜索 API — music.bingdou.xyz
/// 搜索返回直接 mp3 URL 和内联歌词，无需二次请求
class BingdouProvider {
  final Dio _dio;

  static const _base = 'https://music.bingdou.xyz/';

  BingdouProvider(this._dio);

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
            'origin': 'https://music.bingdou.xyz',
            'referer': 'https://music.bingdou.xyz/',
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
          source: 'bingdou',
          id: item['songid']?.toString() ?? '',
          name: item['title']?.toString() ?? '',
          singer: item['author']?.toString() ?? '',
          cover: _upgradeToHttps(item['pic']?.toString()),
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

  /// 将 HTTP 图片链接升级为 HTTPS，避免 Android/iOS 网络限制导致封图无法加载
  static String? _upgradeToHttps(String? url) {
    if (url == null || url.isEmpty) return url;
    if (url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  /// 获取播放链接 — 搜索结果中已包含直链，直接从 extra 取
  Future<SongUrl?> getUrl(Song song) async {
    final url = song.extra?['url']?.toString();
    final lrc = song.extra?['lrc']?.toString();
    if (url == null || url.isEmpty) return null;
    return SongUrl(url: url, lrc: lrc, source: 'bingdou', ext: url.endsWith('.flac') ? 'flac' : 'mp3');
  }
}