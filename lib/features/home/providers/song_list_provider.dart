import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song.dart';
import '../../../data/datasources/remote/api_client.dart';

class SongListNotifier extends StateNotifier<AsyncValue<List<Song>>> {
  final ApiClient _api;
  bool _refreshing = false;

  String get _cachePath =>
      '${Directory.systemTemp.path}/music_song_cache.json';

  SongListNotifier(this._api) : super(const AsyncData([])) {
    _init();
  }

  Future<void> _init() async {
    _loadCacheSync();
    await load();
  }

  void _loadCacheSync() {
    try {
      final file = File(_cachePath);
      if (file.existsSync()) {
        final json = file.readAsStringSync();
        final list = (jsonDecode(json) as List)
            .map((j) => Song.fromJson(j as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) state = AsyncData(list);
      }
    } catch (_) {}
  }

  Future<void> _saveCache(List<Song> songs) async {
    try {
      final json = jsonEncode(songs.map((s) => s.toJson()).toList());
      await File(_cachePath).writeAsString(json);
    } catch (_) {}
  }

  bool get isRefreshing => _refreshing;

  Future<void> load() async {
    final hasData = state.valueOrNull?.isNotEmpty == true;
    if (!hasData) state = const AsyncLoading();
    _refreshing = hasData;

    try {
      final jsonList = await _api.getSongList();
      final songs = jsonList.map((j) => Song.fromJson(j)).toList();
      _saveCache(songs);
      state = AsyncData(songs);
    } catch (e, st) {
      if (!hasData) state = AsyncError(e, st);
    }

    _refreshing = false;
  }

  Future<void> removeSong(int id) async {
    await _api.deleteSong(id);
    state.whenData((songs) {
      final updated = songs.where((s) => s.id != id).toList();
      _saveCache(updated);
      state = AsyncData(updated);
    });
  }

  Future<void> removeLyric(int id) async {
    await _api.deleteLyric(id);
    state.whenData((songs) {
      final updated = songs.map((s) {
        if (s.id == id) {
          return Song(
            id: s.id, title: s.title, artist: s.artist,
            album: s.album, format: s.format,
            duration: s.duration, size: s.size,
            lyricPath: null, createdAt: s.createdAt,
          );
        }
        return s;
      }).toList();
      _saveCache(updated);
      state = AsyncData(updated);
    });
  }
}

final songListProvider =
    StateNotifierProvider<SongListNotifier, AsyncValue<List<Song>>>((ref) {
  final api = ref.read(apiClientProvider);
  return SongListNotifier(api);
});
