import 'dart:convert';
import 'dart:io';
import '../../../core/utils/cache_dir.dart';

class PlayRecord {
  final int songId;
  final String title;
  final String artist;
  final String format;
  final int duration;
  final int positionSeconds;
  final int size;
  final int playedAt;

  const PlayRecord({
    required this.songId,
    required this.title,
    required this.artist,
    required this.format,
    required this.duration,
    required this.positionSeconds,
    this.size = 0,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'title': title,
    'artist': artist,
    'format': format,
    'duration': duration,
    'positionSeconds': positionSeconds,
    'size': size,
    'playedAt': playedAt,
  };

  factory PlayRecord.fromJson(Map<String, dynamic> j) => PlayRecord(
    songId: j['songId'] as int,
    title: j['title'] as String,
    artist: j['artist'] as String,
    format: j['format'] as String,
    duration: j['duration'] as int,
    positionSeconds: j['positionSeconds'] as int,
    size: j['size'] as int? ?? 0,
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

  Future<void> record(int songId, String title, String artist, String format, int duration, int positionSeconds, int size) async {
    await _ensureLoaded();
    _records.removeWhere((r) => r.songId == songId);
    _records.insert(0, PlayRecord(
      songId: songId,
      title: title,
      artist: artist,
      format: format,
      duration: duration,
      positionSeconds: positionSeconds,
      size: size,
      playedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    if (_records.length > 50) _records = _records.sublist(0, 50);
    await _save();
  }

  Future<void> updatePosition(int songId, int positionSeconds) async {
    await _ensureLoaded();
    final idx = _records.indexWhere((r) => r.songId == songId);
    if (idx < 0) return;
    _records[idx] = PlayRecord(
      songId: _records[idx].songId,
      title: _records[idx].title,
      artist: _records[idx].artist,
      format: _records[idx].format,
      duration: _records[idx].duration,
      positionSeconds: positionSeconds,
      size: _records[idx].size,
      playedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _save();
  }

  Future<PlayRecord?> get lastPlayed async {
    await _ensureLoaded();
    return _records.isNotEmpty ? _records.first : null;
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
