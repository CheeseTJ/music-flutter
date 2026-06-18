import 'package:dio/dio.dart';
import '../models/song.dart';

/// 90svip 网易云音乐 API Provider
/// 搜索 + 播放一站式，无需 EAPI 加密
class Netease90svipProvider {
  final Dio _dio;

  static const _baseUrl = 'https://music.90svip.cn/api.php';
  static const _cookie = 'server_name_session=c0bd6e57c1ff2c4ee4383925e8f76b28';

  Netease90svipProvider(this._dio);

  final Map<String, String> _headers = {
    'Accept': 'application/json',
    'X-Requested-With': 'XMLHttpRequest',
    'Referer': 'https://music.90svip.cn/',
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  };

  /// 搜索歌曲，返回 Song 列表
  Future<List<Song>> search(String keyword, {int page = 1}) async {
    try {
      final resp = await _dio.post(
        _baseUrl,
        data: {
          'input': keyword,
          'filter': 'name',
          'type': 'netease',
          'page': page.toString(),
        },
        options: Options(
          headers: {..._headers, 'Cookie': _cookie},
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      final data = resp.data;
      if (data['code'] != 200) return [];
      final list = data['data'] as List? ?? [];
      return list.map((item) {
        return Song(
          platform: 'netease',
          source: '90svip',
          id: item['songid'].toString(),
          name: item['name']?.toString() ?? '',
          singer: item['artist']?.toString() ?? '',
          album: '',
          cover: (() {
            final c = item['cover']?.toString() ?? '';
            return c.startsWith('/') ? 'https://music.90svip.cn$c' : c;
          })(),
          // 把 sign 信息存到 extra 字段，播放时用
          extra: {
            'url_sign': item['url']?.toString() ?? '',
            'lrc_sign': item['lrc']?.toString() ?? '',
          },
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取播放链接（302 重定向）
  Future<SongUrl?> getUrl(Song song) async {
    try {
      final urlSign = song.extra?['url_sign'] as String?;
      if (urlSign == null || urlSign.isEmpty) return null;

      // url_sign 格式: "api.php?get=url&type=wy&id=xxx&sign=xxx&t=xxx"
      final resp = await _dio.get(
        '$_baseUrl$urlSign',
        options: Options(
          headers: {..._headers, 'Cookie': _cookie},
          followRedirects: false, // 不跟随重定向，手动提取 Location
        ),
      );

      // 检查 302 Location 头
      final location = resp.headers.value('location');
      if (location != null && location.isNotEmpty) {
        final ext = location.contains('.flac') ? 'flac'
            : location.contains('.m4a') ? 'm4a'
                : 'mp3';
        return SongUrl(url: location, source: '90svip', ext: ext);
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
