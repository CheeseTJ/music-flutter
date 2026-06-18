import 'package:dio/dio.dart';
import '../models/song.dart';
import 'music_provider.dart';

class MiguProvider implements MusicProvider {
  final Dio _dio;
  static const _base = 'https://tonzhon.whamon.com';
  MiguProvider(this._dio);
  @override String get platform => 'migu';
  Options get _opt => Options(headers: {'Referer': '$_base/'});

  @override
  Future<List<Song>> search(String k, {int page = 1, int num = 20}) async {
    final r = await _dio.get('$_base/api/ss',
        queryParameters: {'keyword': k}, options: _opt);
    if (r.data['success'] != true) return [];
    return ((r.data['data'] ?? []) as List).map((e) {
      final art = (e['artists'] as List?)?.map((a) => a['name']).join('\u3001') ?? '';
      return Song(platform: 'migu', id: e['newId'] ?? '',
          name: e['name'] ?? '', singer: art,
          cover: e['cover'], album: e['album']?['name']);
    }).toList();
  }

  @override
  Future<SongUrl?> getUrl(Song s, {String quality = ''}) async {
    final r = await _dio.get('$_base/api/p/${s.id}', options: _opt);
    if (r.data['success'] != true) return null;
    final url = r.data['data']?.toString();
    if (url == null) return null;
    String? lrc;
    try {
      final lr = await _dio.get('$_base/api/l/${s.id}', options: _opt);
      if (lr.data is Map && lr.data['success'] == true) lrc = lr.data['data'];
    } catch (_) {}
    return SongUrl(url: url, lrc: lrc, ext: 'mp3');
  }
}
