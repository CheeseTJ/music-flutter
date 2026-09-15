import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/remote/music_api.dart';
import 'models/song.dart';

/// 在线搜索/取链统一走 music-api（聚合接口），不再区分线路。
class MusicManager {
  final MusicApi _api = MusicApi();

  Future<List<OnlineSong>> search(String keyword, {int num = 30}) {
    return _api.search(keyword, limit: num);
  }

  /// [quality] 为空 = 播放场景（默认最高音质）；导入场景由调用方传入用户所选档位。
  Future<SongUrl?> getUrl(OnlineSong song, {String? quality}) async {
    return await _api.getUrl(song, quality: quality);
  }

  Future<String> getLyric(OnlineSong song) {
    return _api.getLyric(song);
  }

  /// 播放场景：拿真实最高音质的直链。
  ///
  /// 高档位在后端可能因无资源降级（如 jymaster 档降成 mp3 128k，而 hires 档
  /// 反而是 flac），所以并发请求所有档位，选 bitrate 最高的实际结果；
  /// 试听片段（trial）的档位排到最后，仅当全部试听时才用；
  /// 全部失败时回退默认档。音质选项缺失时只请求一次默认档。
  Future<SongUrl?> getBestUrl(OnlineSong song) async {
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
    // 排序：完整版优先于试听，再按码率从高到低
    ok.sort((a, b) {
      if (a.trial != b.trial) return a.trial ? 1 : -1;
      return (b.bitrate ?? 0).compareTo(a.bitrate ?? 0);
    });
    return ok.first;
  }

  /// 导入场景：优先使用用户所选档位；若该档是 30s 试听片段，
  /// 自动回退到其余档位中最高的完整版（全部试听时才用当前档）。
  Future<SongUrl?> getUrlForImport(OnlineSong song, String? quality) async {
    SongUrl? chosen;
    try {
      chosen = await _api.getUrl(song, quality: quality);
    } catch (_) {
      chosen = null;
    }
    if (chosen != null && chosen.url.isNotEmpty && !chosen.trial) {
      return chosen;
    }

    // 所选档不可用或为试听：并发其余档位找完整版
    final opts = qualityOptionsOf(song);
    final fallbackOpts = opts
        .where((o) => o['value']?.toString() != quality)
        .toList();
    final results = await Future.wait(
      fallbackOpts.map((o) async {
        try {
          return await _api.getUrl(song, quality: o['value']?.toString());
        } catch (_) {
          return null;
        }
      }),
    );
    final ok = results.whereType<SongUrl>().where((r) => r.url.isNotEmpty && !r.trial).toList()
      ..sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
    if (ok.isNotEmpty) {
      return SongUrl(
        url: ok.first.url,
        lrc: ok.first.lrc,
        ext: ok.first.ext,
        bitrate: ok.first.bitrate,
        trial: false,
        source: ok.first.source,
        reason: 'trial_fallback', // 所选档为试听，已自动改用完整版
      );
    }

    // 全部为试听或失败：退回所选档（至少能导出）或默认档
    if (chosen != null && chosen.url.isNotEmpty) return chosen;
    return await _api.getUrl(song);
  }

  /// 该歌曲可选的音质档位列表（来自搜索结果的 qualityOptions），
  /// 形如 [{value, label, quality, format}]；后端未提供时返回空。
  List<Map<String, dynamic>> qualityOptionsOf(OnlineSong song) {
    final opts = song.extra?['qualityOptions'];
    if (opts is List) {
      return opts.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  /// 默认最高音质：qualityOptions 的最后一档；未知结构时回退 null（后端默认档）。
  String? bestQualityOf(OnlineSong song) {
    final opts = qualityOptionsOf(song);
    if (opts.isNotEmpty) {
      return opts.last['value']?.toString();
    }
    return null;
  }
}

final musicManagerProvider = Provider<MusicManager>((ref) => MusicManager());
