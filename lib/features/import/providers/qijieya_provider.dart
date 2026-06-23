import 'package:dio/dio.dart';
import '../models/song.dart';

/// qijieya Meting API — 多平台音乐搜索+播放
/// 无需鉴权，URL 端点返回 302 真实直链
class NeteaseQijieyaProvider {
  final Dio _dio;

  static const _base = 'https://api.qijieya.cn/meting/';

  NeteaseQijieyaProvider(this._dio);

  /// musicType -> meting server name
  static String _serverFor(String musicType) {
    switch (musicType) {
      case 'netease': return 'netease';
      case 'qq': return 'tencent';
      case 'kugou': return 'kugou';
      case 'kuwo': return 'kuwo';
      default: return 'netease';
    }
  }

  /// 搜索
  Future<List<Song>> search(String keyword, {String musicType = 'netease', int page = 1, int limit = 30}) async {
    try {
      final server = _serverFor(musicType);
      final resp = await _dio.get(_base, queryParameters: {
        'server': server,
        'type': 'search',
        'id': keyword,
        'limit': limit,
        'page': page,
      });

      final list = resp.data as List? ?? [];
      return list.map((item) {
        return Song(
          platform: musicType,
          source: 'qijieya',
          id: _extractId(item['url']),
          name: item['name']?.toString() ?? '',
          singer: item['artist']?.toString() ?? '',
          album: '',
          cover: item['pic']?.toString(),
          extra: {'server': server},
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 获取播放链接 — Dio 不跟随 302，取 Location 头
  Future<SongUrl?> getUrl(String songId, {String server = 'netease', int br = 320}) async {
    try {
      final resp = await _dio.get(_base, queryParameters: {
        'server': server,
        'type': 'url',
        'id': songId,
        'br': br,
      }, options: Options(
        followRedirects: false,
      ));

      // 302 Location 头即真实 mp3 地址
      final location = resp.headers.value('location');
      if (location != null && location.isNotEmpty) {
        final ext = location.contains('.flac') ? 'flac'
            : location.contains('.m4a') ? 'm4a'
                : 'mp3';
        return SongUrl(url: location, source: 'qijieya', ext: ext);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 从 url 字段提取 songId
  /// 格式: "/?server=netease&type=url&id=5257138" → "5257138"
  String _extractId(dynamic url) {
    final s = url?.toString() ?? '';
    final match = RegExp(r'id=(\d+)').firstMatch(s);
    return match?.group(1) ?? '';
  }
}