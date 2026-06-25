import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/song.dart';
import 'providers/qijieya_provider.dart';
import 'providers/bingdou_provider.dart';
import 'providers/90svip_provider.dart';
import 'providers/ausearcher_provider.dart';
import 'providers/iqwq_provider.dart';
import 'providers/provider_config_service.dart';

class MusicManager {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  NeteaseQijieyaProvider? _netease;
  BingdouProvider? _bingdou;
  Netease90SvipProvider? _net90svip;
  AusearcherProvider? _ausearcher;
  IqwqProvider? _iqwq;

  NeteaseQijieyaProvider get _neteaseGetter {
    _netease ??= NeteaseQijieyaProvider(_dio,
        baseUrl: ProviderConfigService.baseUrlFor('qijieya') ?? '');
    return _netease!;
  }

  BingdouProvider get _bingdouGetter {
    _bingdou ??= BingdouProvider(_dio,
        baseUrl: ProviderConfigService.baseUrlFor('bingdou') ?? '');
    return _bingdou!;
  }

  Netease90SvipProvider get _net90svipGetter {
    _net90svip ??= Netease90SvipProvider(_dio,
        baseUrl: ProviderConfigService.baseUrlFor('net90svip') ?? '');
    return _net90svip!;
  }

  AusearcherProvider get _ausearcherGetter {
    _ausearcher ??= AusearcherProvider(_dio,
        baseUrl: ProviderConfigService.baseUrlFor('ausearcher') ?? '');
    return _ausearcher!;
  }

  IqwqProvider get _iqwqGetter {
    _iqwq ??= IqwqProvider(_dio,
        baseUrl: ProviderConfigService.baseUrlFor('iqwq') ?? '');
    return _iqwq!;
  }

  Future<List<Song>> search(String source, String musicType, String keyword, {int num = 20}) async {
    switch (source) {
      case 'netease':
        return await _neteaseGetter.search(keyword, musicType: musicType, limit: num);
      case 'bingdou':
        return await _bingdouGetter.search(keyword, musicType: musicType);
      case 'net90svip':
        return await _net90svipGetter.search(keyword, musicType: musicType);
      case 'ausearcher':
        return await _ausearcherGetter.search(keyword, musicType: musicType);
      case 'iqwq':
        return await _iqwqGetter.search(keyword, musicType: musicType);
      default:
        return [];
    }
  }

  Future<SongUrl?> getUrl(Song song, {String quality = 'sq'}) async {
    switch (song.source) {
      case 'bingdou':
        return await _bingdouGetter.getUrl(song);
      case 'net90svip':
        return await _net90svipGetter.getUrl(song);
      case 'ausearcher':
        return await _ausearcherGetter.getUrl(song);
      case 'iqwq':
        return await _iqwqGetter.getUrl(song);
      default:
        final server = song.extra?['server']?.toString() ?? 'netease';
        return await _neteaseGetter.getUrl(song.id, server: server);
    }
  }
}

final musicManagerProvider = Provider<MusicManager>((ref) => MusicManager());
