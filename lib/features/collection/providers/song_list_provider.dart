import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song.dart';
import '../../../data/datasources/remote/api_client.dart';

class SongListNotifier extends StateNotifier<AsyncValue<List<LocalSong>>> {
  final ApiClient _api;

  String get _cachePath =>
      '${Directory.systemTemp.path}/music_song_cache.json';

  SongListNotifier(this._api) : super(const AsyncData([])) {
    _loadCache();  // 同步加载缓存，立即显示
    load();         // API 并行加载，不等缓存
  }

  void _loadCache() {
    try {
      final file = File(_cachePath);
      if (!file.existsSync()) return;
      final json = file.readAsStringSync();
      final list = _parseSongList(json);
      if (list.isNotEmpty) state = AsyncData(list);
    } catch (_) {}
  }

  static List<LocalSong> _parseSongList(String json) {
    return (jsonDecode(json) as List)
        .map((j) => LocalSong.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveCache(List<LocalSong> songs) async {
    try {
      final json = jsonEncode(songs.map((s) => s.toJson()).toList());
      await File(_cachePath).writeAsString(json);
    } catch (_) {}
  }

  Future<void> load() async {
    final hasData = state.valueOrNull?.isNotEmpty == true;
    if (!hasData) state = const AsyncLoading();

    try {
      final jsonList = await _api.getSongList();
      final songs = jsonList.map((j) => LocalSong.fromJson(j)).toList();
      _saveCache(songs);
      state = AsyncData(songs);
    } catch (e, st) {
      if (!hasData) state = AsyncError(e, st);
    }
  }

  Future<void> removeSong(int id) async {
    await _api.deleteSong(id);
    state.whenData((songs) {
      final updated = songs.where((s) => s.id != id).toList();
      _saveCache(updated);
      state = AsyncData(updated);
    });
  }
}

final songListProvider =
    StateNotifierProvider<SongListNotifier, AsyncValue<List<LocalSong>>>((ref) {
  final api = ref.read(apiClientProvider);
  return SongListNotifier(api);
});
