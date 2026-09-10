import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../features/import/models/song.dart';

/// music-api（music.june-t.top）客户端：聚合搜索 / 取链 / 歌词。
///
/// 接口形状（统一 envelope `{code, message, data}`）：
/// - GET /api/search?q=&limit=        → MusicItem[]（含 token、extra.qualityOptions）
/// - GET /api/url?token=&quality=     → {url, type, bitrate, cover}
/// - GET /api/lyric?token=            → {lrc, lyric, lines, ...}
class MusicApi {
  late final Dio _dio;

  MusicApi() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
    ));
  }

  /// 聚合搜索（后端已做多源聚合，无需指定 provider / 线路）。
  Future<List<Song>> search(String keyword, {int limit = 30}) async {
    final resp = await _dio.get('/api/search', queryParameters: {
      'q': keyword,
      'limit': limit,
    });
    final data = _unwrap(resp);
    final items = (data as List).cast<Map<String, dynamic>>();
    return items.map(_toSong).toList();
  }

  /// 获取播放直链。
  ///
  /// [quality] 为空时使用后端默认档（搜索时的 selectedLevel）；
  /// 传 qualityOptions 里的 value（如 standard/exhigh/lossless/hires/jymaster...）覆盖。
  Future<SongUrl> getUrl(Song song, {String? quality}) async {
    final token = _tokenOf(song);
    final params = <String, dynamic>{'token': token};
    if (quality != null && quality.isNotEmpty) params['quality'] = quality;
    final resp = await _dio.get('/api/url', queryParameters: params);
    final data = _unwrap(resp) as Map<String, dynamic>;
    return SongUrl(
      url: data['url'] as String? ?? '',
      ext: (data['type'] as String?)?.split('/').last,
      bitrate: _normalizeBitrate(data['bitrate']),
      source: song.platform,
    );
  }

  /// 上游 bitrate 单位混乱：mp3 常给 bps（如 128012），flac 常给 kbps（如 2000）。
  /// 统一归一成 kbps（>100000 视为 bps；kbps 语义下实际最高也就 ~20000，不会误判）。
  int? _normalizeBitrate(dynamic raw) {
    final v = int.tryParse(raw?.toString() ?? '');
    if (v == null || v <= 0) return null;
    return v > 100000 ? v ~/ 1000 : v;
  }

  /// 获取歌词（LRC 文本），无歌词时返回空字符串。
  Future<String> getLyric(Song song) async {
    final resp = await _dio.get('/api/lyric', queryParameters: {
      'token': _tokenOf(song),
    });
    final data = _unwrap(resp) as Map<String, dynamic>;
    return (data['lyric'] ?? data['lrc'] ?? '') as String;
  }

  // ── helpers ──

  Map<String, dynamic> _toSong(Map<String, dynamic> item) {
    final extra = (item['extra'] as Map<String, dynamic>?) ?? const {};
    return Song(
      platform: (item['provider'] as String?) ?? '',
      id: (item['id'] as String?) ?? '',
      name: (item['title'] as String?) ?? '',
      singer: (item['artist'] as String?) ?? '',
      album: (item['album'] as String?)?.isEmpty == true ? null : item['album'] as String?,
      cover: (item['cover'] as String?)?.isEmpty == true ? null : item['cover'] as String?,
      source: 'music-api',
      extra: {
        'token': item['token'],
        if (extra['qualityOptions'] != null) 'qualityOptions': extra['qualityOptions'],
        if (extra['selectedLevel'] != null) 'selectedLevel': extra['selectedLevel'],
        if (extra['hasLossless'] != null) 'hasLossless': extra['hasLossless'],
        if (extra['cover'] != null && item['cover'] == null) 'cover': extra['cover'],
      },
    );
  }

  String _tokenOf(Song song) {
    final token = song.extra?['token'];
    if (token is String && token.isNotEmpty) return token;
    throw Exception('缺少歌曲 token，请重新搜索');
  }

  /// 统一 envelope：code != 0 时抛出，成功返回 data。
  dynamic _unwrap(Response resp) {
    final body = resp.data;
    if (body is! Map<String, dynamic>) {
      throw Exception('接口返回格式异常');
    }
    final code = body['code'];
    if (code != 0) {
      throw Exception(body['message']?.toString() ?? '请求失败(code=$code)');
    }
    return body['data'];
  }
}
