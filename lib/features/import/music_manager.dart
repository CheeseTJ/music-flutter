import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/song.dart';
import 'providers/meting_provider.dart';
import 'providers/kuwo_direct_provider.dart';
import 'providers/netease_direct_provider.dart';

class MusicManager {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 12),
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
          'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
    },
  ));

  late final MetingProvider     _mNetease, _mKuwo;
  late final KuwoDirectProvider    _kuwoUrl;
  late final NeteaseDirectProvider _neteaseUrl;

  MusicManager() {
    _mNetease   = MetingProvider(_dio, server: 'netease');
    _mKuwo      = MetingProvider(_dio, server: 'kuwo');
    _kuwoUrl    = KuwoDirectProvider(_dio);
    _neteaseUrl = NeteaseDirectProvider(_dio);
  }

  /// 搜索（走 Worker）
  Future<List<Song>> search(String platform, String keyword, {int num = 20}) async {
    final p = switch (platform) {
      'netease' => _mNetease,
      'kuwo'    => _mKuwo,
      _         => null,
    };
    if (p == null) return [];

    try {
      final results = await p.search(keyword, num: num);
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

  /// 取播放链接（App 直连，不经过 Worker）
  Future<SongUrl?> getUrl(Song song, {String quality = 'sq'}) async {
    try {
      switch (song.platform) {
        case 'netease':
          return await _neteaseUrl.getUrl(song, quality: quality);
        case 'kuwo':
          return await _kuwoUrl.getUrl(song, quality: quality);
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }
}

final musicManagerProvider = Provider<MusicManager>((ref) => MusicManager());
