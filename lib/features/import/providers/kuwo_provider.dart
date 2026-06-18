import 'package:dio/dio.dart';
import '../models/song.dart';
import 'music_provider.dart';

class KuwoProvider implements MusicProvider {
  final Dio _dio;
  static const _search = 'https://www.qqmp3.vip/api/songs.php';
  static const _kw = 'https://www.qqmp3.vip/api/kw.php';
  KuwoProvider(this._dio);
  @override String get platform => 'kuwo';
  Options get _opt => Options(headers: {'Referer': 'https://www.qqmp3.vip/'});

  @override
  Future<List<Song>> search(String k, {int page = 1, int num = 20}) async {
    final r = await _dio.get(_search,
        queryParameters: {'type': 'search', 'keyword': k}, options: _opt);
    return ((r.data['data'] ?? []) as List).map((e) => Song(
      platform: 'kuwo', id: e['rid'].toString(),
      name: e['name'] ?? '', singer: e['artist'] ?? '', cover: e['pic'],
    )).toList();
  }

  @override
  Future<SongUrl?> getUrl(Song s, {String quality = 'exhigh'}) async {
    final r = await _dio.get(_kw, queryParameters: {
      'rid': s.id, 'type': 'json', 'level': quality, 'lrc': 'true',
    }, options: _opt);
    final d = r.data['data'];
    if (d == null || d['url'] == null) return null;
    final url = d['url'].toString();
    return SongUrl(url: url, lrc: d['lrc'],
        ext: url.contains('.flac') ? 'flac' : 'mp3');
  }
}
