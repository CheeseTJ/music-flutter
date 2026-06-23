import 'dart:convert';
import 'dart:io';

import 'itunes_cover_service.dart';

/// 根据音乐平台 type 获取封图 URL
/// type 为空默认用 netease，取不到回退 iTunes
class PlatformCoverService {
  static final Map<String, String?> _cache = {};

  const PlatformCoverService();

  /// [type] 音乐平台: netease / qq / kugou / kuwo
  /// [title] 歌曲名
  /// [artist] 歌手名
  Future<String?> fetchUrl(String type, String title, String artist) async {
    final server = _serverFor(type);
    final key = '${server}_${title}_$artist';
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final picUrl = await _searchMeting(server, title, artist);
      if (picUrl != null) {
        _cache[key] = picUrl;
        return picUrl;
      }
    } catch (_) {}

    // 回退 iTunes
    return const ITunesCoverService().fetchUrl(title, artist);
  }

  static String _serverFor(String type) {
    switch (type) {
      case 'netease': return 'netease';
      case 'qq': return 'tencent';
      default: return 'netease';
    }
  }

  Future<String?> _searchMeting(String server, String title, String artist) async {
    final query = Uri.encodeComponent('$title $artist');
    final url = 'https://api.qijieya.cn/meting/?server=$server&type=search&id=$query&limit=1';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'MusicApp/1.0');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      final list = jsonDecode(body) as List?;
      if (list == null || list.isEmpty) return null;

      final pic = (list.first as Map<String, dynamic>)['pic']?.toString();
      return pic;
    } finally {
      client.close();
    }
  }
}
