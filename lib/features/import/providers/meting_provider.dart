import 'package:dio/dio.dart';
import '../models/song.dart';
import 'music_provider.dart';

class MetingProvider implements MusicProvider {
  final Dio _dio;
  final String server;
  // Custom domain: api.june-t.top
  static const _base = 'https://api.june-t.top/';
  static const _token = 'mT8kL2pQ5vX1nR7wY3jF9d';

  MetingProvider(this._dio, {required this.server});
  @override String get platform => 'meting_$server';

  @override
  Future<List<Song>> search(String k, {int page = 1, int num = 20}) async {
    try {
      final r = await _dio.get(_base,
          queryParameters: {'server': server, 'type': 'search', 'keyword': k, 'token': _token});
      final data = r.data;

      // 新 Worker 返回 { songs: [...] } 格式
      List list;
      if (data is Map && data['songs'] != null) {
        list = data['songs'] as List;
      } else if (data is Map && data['data'] != null) {
        list = data['data'] is List ? data['data'] as List : [];
      } else if (data is List) {
        list = data;
      } else {
        list = [];
      }

      return list.map((e) {
        if (e is! Map) return _emptySong('');
        final id = (e['id']?.toString().isNotEmpty == true)
            ? e['id'].toString()
            : '';
        return Song(
          platform: platform,
          source: 'meting',
          id: id,
          name: (e['name'] ?? e['title'] ?? '').toString(),
          singer: (e['artist'] ?? e['author'] ?? '').toString(),
          cover: (e['cover'] ?? e['pic'] ?? e['pic_id'] ?? '').toString(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<SongUrl?> getUrl(Song s, {String quality = ''}) async {
    try {
      final results = await Future.wait([
        _dio.get(_base,
            queryParameters: {'server': server, 'type': 'url', 'id': s.id, 'token': _token}),
        _dio.get(_base,
            queryParameters: {'server': server, 'type': 'lyric', 'id': s.id, 'token': _token}),
      ]);

      final urlResp = results[0];
      final lrcResp = results[1];

      String? url;
      String? reason;
      if (urlResp.data is Map) {
        url = urlResp.data['url']?.toString();
        reason = urlResp.data['reason']?.toString();
      }
      if (url == null || url.isEmpty) {
        final location = urlResp.headers.value('location');
        if (location != null && location.isNotEmpty) url = location;
      }
      if (url == null || url.isEmpty) return SongUrl(url: '', reason: reason);

      String? lrc;
      if (lrcResp.data is Map) {
        lrc = lrcResp.data['lyric']?.toString();
        if (lrc != null && lrc.isEmpty) lrc = null;
      }

      return SongUrl(
        url: url,
        lrc: lrc,
        source: 'meting',
        ext: url.contains('.flac') ? 'flac'
            : (url.contains('.m4a') ? 'm4a' : 'mp3'),
      );
    } catch (_) {
      return null;
    }
  }

  Song _emptySong(String id) => Song(
    platform: platform, source: 'meting', id: id, name: '', singer: '');
}
