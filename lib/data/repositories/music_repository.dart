import '../datasources/remote/api_client.dart';
import '../datasources/local/cache_datasource.dart';
import '../models/song.dart';

class MusicRepository {
  final ApiClient _apiClient;
  final CacheDataSource _cache;

  MusicRepository(this._apiClient, this._cache);

  Future<List<Song>> getSongs({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache.hasCachedData && !_cache.isCacheExpired) {
      return _cache.getCachedSongs();
    }

    final jsonList = await _apiClient.getSongList();
    final songs = jsonList.map((j) => Song.fromJson(j)).toList();
    await _cache.cacheSongs(songs);
    return songs;
  }

  Future<String> getPlayUrl(int id) async {
    final data = await _apiClient.getPlayUrl(id);
    return data['url'] as String;
  }
}
