import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/song.dart';
import 'providers/netease_qijieya_provider.dart';

class MusicManager {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  late final NeteaseQijieyaProvider _netease;

  MusicManager() {
    _netease = NeteaseQijieyaProvider(_dio);
  }

  /// 搜索
  Future<List<Song>> search(String platform, String keyword, {int num = 20}) async {
    if (platform != 'netease') return [];
    final results = await _netease.search(keyword, limit: num);
    return results;
  }

  /// 播放链接
  Future<SongUrl?> getUrl(Song song, {String quality = 'sq'}) async {
    return await _netease.getUrl(song.id);
  }
}

final musicManagerProvider = Provider<MusicManager>((ref) => MusicManager());
