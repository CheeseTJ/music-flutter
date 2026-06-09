import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/song.dart';

class CacheDataSource {
  static const String _songsBox = 'songs';
  static const String _metaBox = 'cache_meta';
  static const String _lastFetchKey = 'last_fetch';

  late Box _songsBoxInstance;
  late Box _metaBoxInstance;

  Future<void> init() async {
    _songsBoxInstance = await Hive.openBox(_songsBox);
    _metaBoxInstance = await Hive.openBox(_metaBox);
  }

  List<Song> getCachedSongs() {
    final raw = _songsBoxInstance.get('list');
    if (raw == null) return [];
    final list = jsonDecode(raw as String) as List;
    return list.map((e) => Song.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> cacheSongs(List<Song> songs) async {
    final json = jsonEncode(songs.map((s) => s.toJson()).toList());
    await _songsBoxInstance.put('list', json);
    await _metaBoxInstance.put(
      _lastFetchKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  bool get isCacheExpired {
    final lastFetch = _metaBoxInstance.get(_lastFetchKey);
    if (lastFetch == null) return true;
    final lastFetchMs = lastFetch as int;
    final elapsed = DateTime.now().millisecondsSinceEpoch - lastFetchMs;
    return elapsed > const Duration(minutes: 30).inMilliseconds;
  }

  bool get hasCachedData {
    return _songsBoxInstance.containsKey('list');
  }

  Future<void> clear() async {
    await _songsBoxInstance.clear();
    await _metaBoxInstance.clear();
  }
}
