import 'dart:convert';
import 'dart:io';
import 'cache_dir.dart';

class PlayRecord {
  final int songId;
  final int playedAt;

  const PlayRecord({required this.songId, required this.playedAt});

  Map<String, dynamic> toJson() => {
        'songId': songId,
        'playedAt': playedAt,
      };

  factory PlayRecord.fromJson(Map<String, dynamic> j) => PlayRecord(
        songId: j['songId'] as int,
        playedAt: j['playedAt'] as int,
      );
}

class PlaybackHistory {
  static final PlaybackHistory _instance = PlaybackHistory._();
  factory PlaybackHistory() => _instance;
  PlaybackHistory._();

  List<PlayRecord> _records = [];
  bool _loaded = false;

  String? _cacheDir;
  String get _path => '$_cacheDir/playback_history.json';

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _cacheDir = await getCacheDir();
    try {
      final file = File(_path);
      if (await file.exists()) {
        final list = (jsonDecode(await file.readAsString()) as List)
            .map((e) => PlayRecord.fromJson(e as Map<String, dynamic>))
            .toList();
        _records = list;
      }
    } catch (_) {
      _records = [];
    }
    _loaded = true;
  }

  Future<void> _save() async {
    if (_cacheDir == null) return;
    try {
      final json = jsonEncode(_records.map((r) => r.toJson()).toList());
      await File(_path).writeAsString(json);
    } catch (_) {}
  }

  Future<void> record(int songId) async {
    await _ensureLoaded();
    _records.removeWhere((r) => r.songId == songId);
    _records.insert(
        0, PlayRecord(songId: songId, playedAt: DateTime.now().millisecondsSinceEpoch));
    if (_records.length > 50) _records = _records.sublist(0, 50);
    await _save();
  }

  Future<List<PlayRecord>> get all async {
    await _ensureLoaded();
    return List.unmodifiable(_records);
  }

  Future<void> clear() async {
    _records = [];
    await _save();
  }
}
