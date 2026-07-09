import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/song.dart';

class NeteaseQijieyaProvider {
  final Dio _dio;
  final String _base;

  NeteaseQijieyaProvider(this._dio, {required String baseUrl}) : _base = baseUrl;

  static String _serverFor(String musicType) {
    switch (musicType) {
      case 'netease': return 'netease';
      case 'qq': return 'tencent';
      case 'kugou': return 'kugou';
      case 'kuwo': return 'kuwo';
      default: return 'netease';
    }
  }

  Future<List<Song>> search(String keyword, {String musicType = 'netease', int page = 1, int limit = 30}) async {
    if (_base.isEmpty) {
      throw Exception('meting 线路未配置（Provider 配置未加载）');
    }
    try {
      final server = _serverFor(musicType);
      final resp = await _dio.get(_base, queryParameters: {
        'server': server,
        'type': 'search',
        'id': keyword,
        'limit': limit,
        'page': page,
      });

      dynamic data = resp.data;
      // Dio 在部分 Android 设备上可能不自动解析 JSON，手动兜底
      if (data is String) {
        data = jsonDecode(data);
      }
      if (data is! List) {
        debugPrint('[Meting] 响应格式异常，类型: ${data.runtimeType}, 内容: ${data.toString().substring(0, data.toString().length > 300 ? 300 : data.toString().length)}');
        throw Exception('meting 返回格式异常（期望数组，实际返回 ${data.runtimeType}）');
      }
      final list = data as List;
      return list.map((item) {
        return Song(
          platform: musicType,
          source: 'qijieya',
          id: _extractId(item['url']),
          name: item['name']?.toString() ?? '',
          singer: item['artist']?.toString() ?? '',
          album: '',
          cover: item['pic']?.toString(),
          extra: {
            'server': server,
            if (item['lrc'] != null) 'lrc': item['lrc'].toString(),
          },
        );
      }).toList();
    } catch (e) {
      debugPrint('[Meting] 搜索失败: $e');
      rethrow;
    }
  }

  Future<SongUrl?> getUrl(Song song, {int br = 320}) async {
    if (_base.isEmpty) {
      debugPrint('[Meting] getUrl 失败: baseUrl 为空');
      return null;
    }
    final server = song.extra?['server']?.toString() ?? 'netease';
    final songId = song.id;
    try {
      // 并行获取播放链接和歌词
      final audioFuture = _dio.get(_base, queryParameters: {
        'server': server,
        'type': 'url',
        'id': songId,
        'br': br,
      }, options: Options(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
      ));

      final lrcUrl = song.extra?['lrc']?.toString();
      final lrcFuture = (lrcUrl != null && lrcUrl.isNotEmpty)
          ? _dio.get(lrcUrl, options: Options(
              validateStatus: (status) => status != null && status < 400,
            ))
          : null;

      final results = await Future.wait([audioFuture, if (lrcFuture != null) lrcFuture]);
      final resp = results[0] as Response;
      final lrcResp = results.length > 1 ? results[1] as Response? : null;

      final location = resp.headers.value('location');
      if (location == null || location.isEmpty) return null;

      final ext = location.contains('.flac') ? 'flac'
          : location.contains('.m4a') ? 'm4a'
              : 'mp3';

      String? lrcText;
      if (lrcResp != null) {
        final data = lrcResp.data;
        if (data is String && data.isNotEmpty) {
          lrcText = data;
        } else if (data is List && data.isNotEmpty && data[0] is String) {
          lrcText = data[0] as String;
        }
      }

      return SongUrl(url: location, lrc: lrcText, source: 'qijieya', ext: ext);
    } catch (e) {
      debugPrint('[Meting] getUrl 失败: $e');
      return null;
    }
  }

  String _extractId(dynamic url) {
    final s = url?.toString() ?? '';
    final match = RegExp(r'id=(\d+)').firstMatch(s);
    return match?.group(1) ?? '';
  }
}
