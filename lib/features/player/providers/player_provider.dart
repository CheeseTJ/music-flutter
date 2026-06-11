import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../data/models/song.dart';
import '../../../data/models/lrc_parser.dart';
import '../../../data/datasources/remote/api_client.dart';

enum PlayerPhase { idle, loading, playing, paused, error }

class PlayerState {
  final PlayerPhase phase;
  final int tick;
  final bool lyricLoading;
  final bool lyricFailed;
  const PlayerState(this.phase, {this.tick = 0, this.lyricLoading = false, this.lyricFailed = false});
  PlayerState withTick(int t) => PlayerState(phase, tick: t, lyricLoading: lyricLoading, lyricFailed: lyricFailed);
  PlayerState withLyricLoading(bool v) => PlayerState(phase, tick: tick, lyricLoading: v, lyricFailed: lyricFailed);
  PlayerState withLyricFailed(bool v) => PlayerState(phase, tick: tick, lyricLoading: lyricLoading, lyricFailed: v);
  factory PlayerState.idle() => const PlayerState(PlayerPhase.idle);
  factory PlayerState.loading() => const PlayerState(PlayerPhase.loading);
  factory PlayerState.playing() => const PlayerState(PlayerPhase.playing);
  factory PlayerState.paused() => const PlayerState(PlayerPhase.paused);
  factory PlayerState.error() => const PlayerState(PlayerPhase.error);
  bool get isPlaying => phase == PlayerPhase.playing;
  bool get isPaused => phase == PlayerPhase.paused;
  bool get hasError => phase == PlayerPhase.error;
  bool get isLoading => phase == PlayerPhase.loading;
}

class PlayerController extends StateNotifier<PlayerState> {
  final AudioPlayer _player = AudioPlayer();
  final ApiClient _apiClient;
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  int _playMode = 0;

  LrcParser? _lyric;
  int _currentLyricIndex = -1;
  int _lyricVersion = 0;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<dynamic>? _completeSub;

  static String get _lyricCacheDir => '${Directory.systemTemp.path}/lyric_cache';

  PlayerController(this._apiClient) : super(PlayerState.idle()) {
    Directory(_lyricCacheDir).createSync(recursive: true);
  }

  AudioPlayer get player => _player;
  Song? get currentSong => _currentSong;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  int get playMode => _playMode;
  LrcParser? get lyric => _lyric;
  int get currentLyricIndex => _currentLyricIndex;
  bool get lyricLoading => state.lyricLoading;
  bool get lyricFailed => state.lyricFailed;

  void setPlaylist(List<Song> songs) {
    _playlist = songs;
  }

  Future<void> play(Song song) async {
    final index = _playlist.indexWhere((s) => s.id == song.id);
    if (index >= 0) _currentIndex = index;

    _currentSong = song;
    _lyric = null;
    _currentLyricIndex = -1;
    state = PlayerState.loading();

    try {
      final data = await _apiClient.getPlayUrl(song.id);
      final url = data['url'] as String;

      await _player.setUrl(url);
      _player.play();
      state = PlayerState.playing();

      _positionSub?.cancel();
      _durationSub?.cancel();
      _completeSub?.cancel();
      _positionSub = _player.positionStream.listen(_onPositionChanged);
      _durationSub = _player.durationStream.listen((_) {});
      _completeSub = _player.playerStateStream.listen((ps) {
        if (ps.processingState == ProcessingState.completed) {
          onSongEnd();
        }
      });

      _fetchLyric(song.id);
    } catch (e) {
      state = PlayerState.error();
    }
  }

  void _onPositionChanged(Duration position) {
    if (_lyric != null) {
      final idx = _lyric!.findIndex(position);
      if (idx != _currentLyricIndex) {
        _currentLyricIndex = idx;
      }
    }
  }

  Future<void> _fetchLyric(int songId) async {
    state = state.withLyricLoading(true).withLyricFailed(false);

    final cached = _readLyricCache(songId);
    if (cached != null) {
      _lyric = LrcParser.parse(cached);
      _lyricVersion++;
      state = state.withTick(_lyricVersion).withLyricLoading(false);
      return;
    }

    try {
      final lrcText = await _apiClient.getLyric(songId);
      if (lrcText.isNotEmpty) {
        _lyric = LrcParser.parse(lrcText);
        _writeLyricCache(songId, lrcText);
        _lyricVersion++;
        state = state.withTick(_lyricVersion).withLyricLoading(false);
      } else {
        state = state.withLyricLoading(false).withLyricFailed(true);
      }
    } catch (_) {
      _lyric = null;
      state = state.withLyricLoading(false).withLyricFailed(true);
    }
  }

  String? _readLyricCache(int songId) {
    try {
      final file = File('$_lyricCacheDir/$songId.lrc');
      if (file.existsSync()) return file.readAsStringSync();
    } catch (_) {}
    return null;
  }

  void _writeLyricCache(int songId, String text) {
    try {
      File('$_lyricCacheDir/$songId.lrc').writeAsStringSync(text);
    } catch (_) {}
  }

  void onSongEnd() {
    if (_playMode == 1) {
      _player.seek(Duration.zero);
      _player.play();
      state = PlayerState.playing();
    } else {
      next();
    }
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    if (_playMode == 2) {
      if (_playlist.length == 1) {
        await play(_playlist[0]);
        return;
      }
      final rng = Random();
      var nextIdx = _currentIndex;
      while (nextIdx == _currentIndex) {
        nextIdx = rng.nextInt(_playlist.length);
      }
      _currentIndex = nextIdx;
      await play(_playlist[_currentIndex]);
      return;
    }
    if (_currentIndex < _playlist.length - 1) {
      _currentIndex++;
      await play(_playlist[_currentIndex]);
    } else if (_playMode == 0) {
      _currentIndex = 0;
      await play(_playlist[_currentIndex]);
    }
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    if (_playMode == 2) {
      final rng = Random();
      var prevIdx = _currentIndex;
      while (prevIdx == _currentIndex) {
        prevIdx = rng.nextInt(_playlist.length);
      }
      _currentIndex = prevIdx;
      await play(_playlist[_currentIndex]);
      return;
    }
    if (_currentIndex > 0) {
      _currentIndex--;
      await play(_playlist[_currentIndex]);
    } else if (_playMode == 0) {
      _currentIndex = _playlist.length - 1;
      await play(_playlist[_currentIndex]);
    }
  }

  void togglePlayPause() {
    if (_player.playing) {
      _player.pause();
      state = PlayerState.paused();
    } else {
      _player.play();
      state = PlayerState.playing();
    }
  }

  void seekTo(Duration position) {
    _player.seek(position);
  }

  void togglePlayMode() {
    _playMode = (_playMode + 1) % 3;
    state = state.withTick(state.tick + 1);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerController, PlayerState>((ref) {
  final api = ref.read(apiClientProvider);
  return PlayerController(api);
});
