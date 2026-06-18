import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/song.dart';
import 'music_provider.dart';

class QQProvider implements MusicProvider {
  final Dio _dio;
  static const _base = 'https://tang.api.s01s.cn/music_open_api.php';
  QQProvider(this._dio);
  @override String get platform => 'qq';

  Options get _opt => Options(
    responseType: ResponseType.plain,
    headers: {
      'accept': '*/*',
      'origin': 'http://qjjlb.quanjian.com.cn',
      'referer': 'http://qjjlb.quanjian.com.cn/',
    },
  );

  dynamic _decode(dynamic raw) {
    if (raw is String) {
      try { return jsonDecode(raw); } catch (_) { return null; }
    }
    return raw;
  }

  @override
  Future<List<Song>> search(String k, {int page = 1, int num = 20}) async {
    final r = await _dio.get(_base,
        queryParameters: {'msg': k, 'type': 'json'}, options: _opt);
    final data = _decode(r.data);
    if (data is! List) return [];
    return data.map<Song>((e) => Song(
      platform: 'qq',
      id: (e['song_mid'] ?? '').toString(),
      name: (e['song_title'] ?? '').toString(),
      singer: (e['singer_name'] ?? '').toString(),
      cover: (e['album_pic'] ?? e['song_pic'] ?? '').toString(),
      quality: (e['pay'] ?? '').toString(),
    )).toList();
  }

  @override
  Future<SongUrl?> getUrl(Song s, {String quality = 'sq'}) async {
    final r = await _dio.get(_base, queryParameters: {
      'msg': s.name, 'type': 'json', 'mid': s.id,
    }, options: _opt);

    final d = _decode(r.data);
    if (d is! Map) {
      if (d is List && d.isNotEmpty && d.first is Map) {
        return _fromMap(d.first as Map, quality);
      }
      return null;
    }
    return _fromMap(d, quality);
  }

  SongUrl? _fromMap(Map d, String quality) {
    final candidates = <String, dynamic>{
      'sq': d['song_play_url_sq'],
      'hq': d['song_play_url_hq'],
      'standard': d['song_play_url_standard'],
      'fq': d['song_play_url_fq'],
      'default': d['song_play_url'],
    };

    String? url = _nonEmpty(candidates[quality]);
    url ??= _nonEmpty(candidates['sq']);
    url ??= _nonEmpty(candidates['hq']);
    url ??= _nonEmpty(candidates['default']);
    url ??= _nonEmpty(candidates['standard']);
    url ??= _nonEmpty(candidates['fq']);
    if (url == null) return null;

    return SongUrl(
      url: url,
      lrc: _nonEmpty(d['song_lyric']),
      ext: url.contains('.flac') ? 'flac' : 'm4a',
    );
  }

  String? _nonEmpty(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }
}
