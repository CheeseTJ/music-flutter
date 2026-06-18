import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/song.dart';
import 'providers/netease_90svip_provider.dart';

class MusicManager {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  late final Netease90svipProvider _netease;

  MusicManager() {
    _netease = Netease90svipProvider(_dio);
  }

  /// 搜索（走 90svip API）
  Future<List<Song>> search(String platform, String keyword, {int num = 20}) async {
    if (platform != 'netease') return [];
    return await _netease.search(keyword);
  }

  /// 获取播放链接（走 90svip 302 重定向）
  Future<SongUrl?> getUrl(Song song, {String quality = 'sq'}) async {
    return await _netease.getUrl(song);
  }
}

final musicManagerProvider = Provider<MusicManager>((ref) => MusicManager());
