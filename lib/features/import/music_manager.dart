import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/music_api.dart';
import 'models/song.dart';

/// 在线搜索/取链统一走 music-api（聚合接口），不再区分线路。
class MusicManager {
  final MusicApi _api = MusicApi();

  Future<List<Song>> search(String keyword, {int num = 30}) {
    return _api.search(keyword, limit: num);
  }

  /// [quality] 为空 = 播放场景（默认最高音质）；导入场景由调用方传入用户所选档位。
  Future<SongUrl?> getUrl(Song song, {String? quality}) async {
    return await _api.getUrl(song, quality: quality);
  }

  Future<String> getLyric(Song song) {
    return _api.getLyric(song);
  }

  /// 播放场景：拿真实最高音质的直链。
  ///
  /// 高档位在后端可能因无资源降级（如 jymaster 档降成 mp3 128k，而 hires 档
  /// 反而是 flac），所以并发请求所有档位，选 bitrate 最高的实际结果；
  /// 全部失败时回退默认档。音质选项缺失时只请求一次默认档。
  Future<SongUrl?> getBestUrl(Song song) async {
    final opts = qualityOptionsOf(song);
    if (opts.length < 2) {
      return await _api.getUrl(song, quality: bestQualityOf(song));
    }
    final results = await Future.wait(
      opts.map((o) async {
        try {
          return await _api.getUrl(song, quality: o['value']?.toString());
        } catch (_) {
          return null;
        }
      }),
    );
    final ok = results.whereType<SongUrl>().where((r) => r.url.isNotEmpty).toList();
    if (ok.isEmpty) return await _api.getUrl(song);
    ok.sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
    return ok.first;
  }

  /// 该歌曲可选的音质档位列表（来自搜索结果的 qualityOptions），
  /// 形如 [{value, label, quality, format}]；后端未提供时返回空。
  List<Map<String, dynamic>> qualityOptionsOf(Song song) {
    final opts = song.extra?['qualityOptions'];
    if (opts is List) {
      return opts.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// 默认最高音质：qualityOptions 的最后一档；未知结构时回退 null（后端默认档）。
  String? bestQualityOf(Song song) {
    final opts = qualityOptionsOf(song);
    if (opts.isNotEmpty) {
      return opts.last['value']?.toString();
    }
    return null;
  }
}

final musicManagerProvider = Provider<MusicManager>((ref) => MusicManager());
