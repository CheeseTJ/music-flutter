import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/song.dart';
import 'providers/music_provider.dart';
import 'providers/meting_provider.dart';

class MusicManager {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    },
  ));

  late final MusicProvider _mNetease, _mKuwo, _mKugou;

  MusicManager() {
    _mNetease = MetingProvider(_dio, server: 'netease');
    _mKuwo    = MetingProvider(_dio, server: 'kuwo');
    _mKugou   = MetingProvider(_dio, server: 'kugou');
  }

  /// 搜索
  Future<List<Song>> search(String platform, String keyword, {int num = 20}) async {
    final p = switch (platform) {
      'netease' => _mNetease,
      'kuwo' => _mKuwo,
      'kugou' => _mKugou,
      _ => null,
    };
    if (p == null) return [];

    try {
      final results = await p.search(keyword, num: num);
      // 归一化 platform 名称
      return results.map((s) => Song(
        platform: platform,
        source: 'meting',
        id: s.id,
        name: s.name,
        singer: s.singer,
        album: s.album,
        cover: s.cover,
        quality: s.quality,
      )).toList();
    } catch (_) {
      return [];
    }
  }

  /// 取播放链接
  Future<SongUrl?> getUrl(Song song, {String quality = 'sq'}) async {
    final p = switch (song.platform) {
      'netease' => _mNetease,
      'kuwo' => _mKuwo,
      'kugou' => _mKugou,
      _ => null,
    };
    if (p == null) return null;

    try {
      return await p.getUrl(song, quality: quality);
    } catch (_) {
      return null;
    }
  }
}

final musicManagerProvider = Provider<MusicManager>((ref) => MusicManager());
