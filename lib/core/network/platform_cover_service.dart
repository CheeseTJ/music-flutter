import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'itunes_cover_service.dart';

class PlatformCoverService {
  static final Map<String, String?> _cache = {};
  static final Map<String, Future<String?>> _inFlight = {};
  static bool _persistLoaded = false;

  static String get _cacheFilePath =>
      '${Directory.systemTemp.path}/cover_url_cache.json';

  const PlatformCoverService();

  static Future<void> _ensurePersistLoaded() async {
    if (_persistLoaded) return;
    _persistLoaded = true;
    try {
      final file = File(_cacheFilePath);
      if (await file.exists()) {
        final json = await file.readAsString();
        final map = await compute(_decodeCache, json);
        _cache.addAll(map);
      }
    } catch (_) {}
  }

  static Map<String, String?> _decodeCache(String json) {
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String?));
  }

  static Future<void> _persistCache() async {
    try {
      final file = File(_cacheFilePath);
      final json = jsonEncode(_cache);
      await file.writeAsString(json);
    } catch (_) {}
  }

  static String? getCachedUrl(String type, String title, String artist) {
    final server = _serverFor(type);
    final key = '${server}_${title}_$artist';
    return _cache[key];
  }

  static Future<void> preloadCache() => _ensurePersistLoaded();

  Future<String?> fetchUrl(String type, String title, String artist) async {
    await _ensurePersistLoaded();

    final server = _serverFor(type);
    final key = '${server}_${title}_$artist';

    final cached = _cache[key];
    if (cached != null) return cached;
    if (_cache.containsKey(key) && _cache[key] == null) return null;

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    final future = _fetchAndCache(server, key, title, artist);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<String?> _fetchAndCache(
    String server,
    String key,
    String title,
    String artist,
  ) async {
    String? picUrl;
    try {
      picUrl = await _searchMeting(server, title, artist);
    } catch (_) {}

    if (picUrl == null || picUrl.isEmpty) {
      try {
        picUrl = await const ITunesCoverService().fetchUrl(title, artist);
      } catch (_) {}
    }

    _cache[key] = picUrl;
    _persistCache();
    return picUrl;
  }

  static String _serverFor(String type) {
    switch (type) {
      case 'netease':
        return 'netease';
      case 'qq':
        return 'tencent';
      default:
        return 'netease';
    }
  }

  Future<String?> _searchMeting(String server, String title, String artist) async {
    final query = Uri.encodeComponent('$title $artist');
    final url =
        'https://api.qijieya.cn/meting/?server=$server&type=search&id=$query&limit=1';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'MusicApp/1.0');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      final list = jsonDecode(body) as List?;
      if (list == null || list.isEmpty) return null;

      final pic = (list.first as Map<String, dynamic>)['pic']?.toString();
      return (pic != null && pic.isNotEmpty) ? pic : null;
    } finally {
      client.close();
    }
  }
}
