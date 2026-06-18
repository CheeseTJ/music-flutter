import '../models/song.dart';

abstract class MusicProvider {
  String get platform;
  Future<List<Song>> search(String keyword, {int page = 1, int num = 20});
  Future<SongUrl?> getUrl(Song song, {String quality});
}
