import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song.dart';
import '../../../data/datasources/remote/api_client.dart';

class SongListNotifier extends StateNotifier<AsyncValue<List<Song>>> {
  final ApiClient _api;

  SongListNotifier(this._api) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final jsonList = await _api.getSongList();
      return jsonList.map((j) => Song.fromJson(j)).toList();
    });
  }
}

final songListProvider =
    StateNotifierProvider<SongListNotifier, AsyncValue<List<Song>>>((ref) {
  final api = ref.read(apiClientProvider);
  return SongListNotifier(api);
});
