import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/song.dart';
import 'providers/qijieya_provider.dart';
import 'providers/bingdou_provider.dart';
import 'providers/90svip_provider.dart';
import 'providers/ausearcher_provider.dart';
import 'providers/iqwq_provider.dart';

class MusicManager {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  late final NeteaseQijieyaProvider _netease;
  late final BingdouProvider _bingdou;
  late final Netease90SvipProvider _net90svip;
  late final AusearcherProvider _ausearcher;
  late final IqwqProvider _iqwq;

  MusicManager() {
    _netease = NeteaseQijieyaProvider(_dio);
    _bingdou = BingdouProvider(_dio);
    _net90svip = Netease90SvipProvider(_dio);
    _ausearcher = AusearcherProvider(_dio);
    _iqwq = IqwqProvider(_dio);
  }

  /// 搜索
  /// [source] API 线路: qijieya / bingdou / net90svip / ausearcher / iqwq
  /// [musicType] 音乐平台: netease / qq / kugou / kuwo
  Future<List<Song>> search(String source, String musicType, String keyword, {int num = 20}) async {
    switch (source) {
      case 'netease':
        return await _netease.search(keyword, musicType: musicType, limit: num);
      case 'bingdou':
        return await _bingdou.search(keyword, musicType: musicType);
      case 'net90svip':
        return await _net90svip.search(keyword, musicType: musicType);
      case 'ausearcher':
        return await _ausearcher.search(keyword, musicType: musicType);
      case 'iqwq':
        return await _iqwq.search(keyword, musicType: musicType);
      default:
        return [];
    }
  }

  /// 播放链接
  Future<SongUrl?> getUrl(Song song, {String quality = 'sq'}) async {
    switch (song.source) {
      case 'bingdou':
        return await _bingdou.getUrl(song);
      case 'net90svip':
        return await _net90svip.getUrl(song);
      case 'ausearcher':
        return await _ausearcher.getUrl(song);
      case 'iqwq':
        return await _iqwq.getUrl(song);
      default:
        final server = song.extra?['server']?.toString() ?? 'netease';
        return await _netease.getUrl(song.id, server: server);
    }
  }
}

final musicManagerProvider = Provider<MusicManager>((ref) => MusicManager());