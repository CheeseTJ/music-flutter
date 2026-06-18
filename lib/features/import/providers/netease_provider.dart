import 'package:dio/dio.dart';
import '../models/song.dart';
import 'music_provider.dart';

class NeteaseProvider implements MusicProvider {
  final Dio _dio;
  static const _vk = 'https://api.vkeys.cn/v2/music/netease';
  static const _mt = 'https://api.qijieya.cn/meting/';
  NeteaseProvider(this._dio);
  @override String get platform => 'netease';

  @override
  Future<List<Song>> search(String k, {int page = 1, int num = 20}) async {
    final r = await _dio.get(_vk,
        queryParameters: {'word': k, 'page': page, 'num': num});
    return ((r.data['data'] ?? []) as List).map((e) => Song(
      platform: 'netease', id: e['id'].toString(),
      name: e['song'] ?? '', singer: e['singer'] ?? '',
      album: e['album'], cover: e['cover'], quality: e['quality'],
    )).toList();
  }

  @override
  Future<SongUrl?> getUrl(Song s, {String quality = ''}) async {
    final urlApi = '$_mt?server=netease&type=url&id=${s.id}';
    String real = urlApi;
    final resp = await _dio.get(urlApi, options: Options(
      followRedirects: false, validateStatus: (x) => x != null && x < 400));
    real = resp.headers.value('location') ?? urlApi;
    String? lrc;
    try {
      final lr = await _dio.get('$_vk/lyric', queryParameters: {'id': s.id});
      lrc = lr.data['data']?['lrc'];
    } catch (_) {}
    if (real == urlApi) return null;
    return SongUrl(url: real, lrc: lrc,
        ext: real.contains('.flac') ? 'flac' : 'mp3');
  }
}
