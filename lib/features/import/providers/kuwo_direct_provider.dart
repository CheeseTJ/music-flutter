import 'package:dio/dio.dart';
import '../models/song.dart';
import 'music_provider.dart';

/// 酷我直连 URL Provider — 绕过 Cloudflare Worker IP 封锁
/// 直接从用户手机请求 antiserver.kuwo.cn
class KuwoDirectProvider implements MusicProvider {
  final Dio _dio;

  KuwoDirectProvider(this._dio);

  @override
  String get platform => 'kuwo_direct';

  @override
  Future<List<Song>> search(String keyword, {int page = 1, int num = 20}) async {
    // 搜索仍走 Worker，此方法不会被调用
    return [];
  }

  @override
  Future<SongUrl?> getUrl(Song song, {String quality = ''}) async {
    try {
      // rid 格式: "MUSIC_154737010"
      final rid = song.id;

      final resp = await _dio.get(
        'http://antiserver.kuwo.cn/anti.s',
        queryParameters: {
          'format': 'mp3|aac',
          'rid': rid,
          'type': 'convert_url',
          'response': 'url',
        },
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 10),
          headers: {
            'User-Agent': 'Mozilla/5.0',
            'Referer': 'http://www.kuwo.cn/',
          },
        ),
      );

      final url = (resp.data as String).trim();
      if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
        return SongUrl(
          url: url,
          source: 'kuwo_direct',
          ext: url.contains('.mp3') ? 'mp3' : 'aac',
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
