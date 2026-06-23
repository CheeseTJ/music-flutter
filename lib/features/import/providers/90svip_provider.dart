import 'package:dio/dio.dart';
import '../models/song.dart';

/// 90Svip 音乐搜索 API — music.90svip.cn
/// 搜索返回子接口相对路径，url 子接口直接返回音频流（无需 302 跳转）
/// lrc 子接口直接返回纯文本歌词
class Netease90SvipProvider {
  final Dio _dio;

  static const _base = 'https://music.90svip.cn/';

  Netease90SvipProvider(this._dio);

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
            'origin': 'https://music.90svip.cn',
            'referer': 'https://music.90svip.cn/',
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

  /// 获取播放链接 — url 子接口直接返回 mp3 音频流，直接用 url_path 即可
  Future<SongUrl?> getUrl(Song song) async {
    final urlPath = song.extra?['url_path']?.toString();
    if (urlPath == null || urlPath.isEmpty) return null;

    // url_path 本身就是直链（api.php?get=url 返回 audio/mpeg）
    final ext = urlPath.contains('.m4a') ? 'm4a'
        : urlPath.contains('.flac') ? 'flac'
            : 'mp3';

    // 尝试获取歌词
    String? lrc;
    try {
      lrc = await _fetchLrc(song);
    } catch (_) {}

    return SongUrl(url: urlPath, lrc: lrc, source: 'net90svip', ext: ext);
  }

  /// 获取歌词文本 — lrc 子接口直接返回纯文本
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