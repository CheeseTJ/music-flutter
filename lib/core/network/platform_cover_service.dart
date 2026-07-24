import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'itunes_cover_service.dart';
import '../../features/import/providers/provider_config_service.dart';

class PlatformCoverService {
  // 内存缓存：key → 本地文件路径（null = 已知不存在）
  static final Map<String, String?> _cache = {};
  static final Map<String, Future<String?>> _inFlight = {};

  static const _maxConcurrent = 4;
  static int _activeFetches = 0;
  static final List<void Function()> _pendingFetches = [];

  static String get _coversDir =>
      '${Directory.systemTemp.path}/music_covers';

  const PlatformCoverService();

  // ── 同步获取已缓存封面的本地路径 ──
  static String? getCachedPath(String type, String title, String artist) {
    final key = _makeKey(type, title, artist);
    if (_cache.containsKey(key)) return _cache[key];
    // 内存未命中，检查磁盘文件
    final filePath = _localPath(key);
    if (File(filePath).existsSync()) {
      _cache[key] = filePath;
      return filePath;
    }
    return null;
  }

  /// 清空所有封面缓存（内存 + 磁盘文件）
  static Future<void> clearAll() async {
    _cache.clear();
    _inFlight.clear();
    _pendingFetches.clear();
    try {
      final dir = Directory(_coversDir);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  // ── 获取封面，返回本地文件路径 ──
  Future<String?> fetch(String type, String title, String artist) async {
    final key = _makeKey(type, title, artist);

    final cached = _cache[key];
    if (cached != null) return cached;
    if (_cache.containsKey(key)) return null; // 已知不存在

    final inFlight = _inFlight[key];
    if (inFlight != null) return inFlight;

    if (_activeFetches >= _maxConcurrent) {
      final completer = Completer<String?>();
      _pendingFetches.add(() async {
        completer.complete(fetch(type, title, artist));
      });
      return completer.future;
    }

    final future = _doFetch(key, title, artist);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<String?> _doFetch(String key, String title, String artist) async {
    _activeFetches++;
    try {
      String? picUrl = await _searchDualPlatform(title, artist);

      if (picUrl == null) {
        picUrl = await const ITunesCoverService().fetchUrl(title, artist);
      }

      if (picUrl == null) {
        picUrl = await _searchTitleOnly(title);
      }

      if (picUrl == null || picUrl.isEmpty) {
        _cache[key] = null;
        return null;
      }

      // 下载图片到本地
      final localPath = await _download(picUrl, key);
      _cache[key] = localPath;
      return localPath;
    } finally {
      _activeFetches--;
      if (_pendingFetches.isNotEmpty) {
        final next = _pendingFetches.removeAt(0);
        next();
      }
    }
  }

  // ── 同时搜索网易云 + QQ ──
  Future<String?> _searchDualPlatform(String title, String artist) async {
    final results = await Future.wait([
      _searchMeting('netease', title, artist),
      _searchMeting('tencent', title, artist),
    ]);
    return results.firstWhere(
      (r) => r != null && r.isNotEmpty,
      orElse: () => null,
    );
  }

  // ── 仅用歌曲名搜索（最后兜底） ──
  Future<String?> _searchTitleOnly(String title) async {
    final results = await Future.wait([
      _searchMeting('netease', title, ''),
      _searchMeting('tencent', title, ''),
    ]);
    return results.firstWhere(
      (r) => r != null && r.isNotEmpty,
      orElse: () => null,
    );
  }

  // ── 下载图片到本地 ──
  Future<String?> _download(String url, String key) async {
    final dir = Directory(_coversDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final ext = _extFromUrl(url);
    final filePath = _localPath(key, ext);

    // 已存在则跳过下载
    if (File(filePath).existsSync()) return filePath;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'MusicApp/1.0');
      final resp = await req.close().timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final file = File(filePath);
      await file.openWrite().addStream(resp);
      return filePath;
    } catch (_) {
      // 清理不完整文件
      try {
        await File(filePath).delete();
      } catch (_) {}
      return null;
    } finally {
      client.close();
    }
  }

  // ── helpers ──
  static String _makeKey(String type, String title, String artist) =>
      '${type}_${title}_$artist';

  static String _localPath(String key, [String ext = 'jpg']) =>
      '$_coversDir/${key.hashCode}.$ext';

  static String _extFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final last = uri.pathSegments.lastOrNull ?? '';
      final dot = last.lastIndexOf('.');
      if (dot > 0) {
        final ext = last.substring(dot + 1).split('?').first;
        if (ext.length <= 4) return ext;
      }
    } catch (_) {}
    return 'jpg';
  }

  Future<String?> _searchMeting(
      String server, String title, String artist) async {
    final query = Uri.encodeComponent('$title $artist');
    final base = ProviderConfigService.baseUrlFor('qijieya');
    if (base == null) return null;
    final url = '$base?server=$server&type=search&id=$query&limit=1';

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
