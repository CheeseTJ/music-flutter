import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../data/models/song.dart';
import '../../../core/audio/audio_player_handler.dart';
import '../../../data/models/lrc_parser.dart';
import '../../../data/datasources/remote/api_client.dart';
import '../../../core/network/platform_cover_service.dart';

enum PlayerPhase { idle, loading, playing, paused, error }

class PlayerState {
  final PlayerPhase phase;
  final int playMode;
  final bool lyricLoading;
  final bool lyricFailed;
  const PlayerState(this.phase, {this.playMode = 0, this.lyricLoading = false, this.lyricFailed = false});
  PlayerState copyWith({PlayerPhase? phase, int? playMode, bool? lyricLoading, bool? lyricFailed}) =>
      PlayerState(
        phase ?? this.phase,
        playMode: playMode ?? this.playMode,
        lyricLoading: lyricLoading ?? this.lyricLoading,
        lyricFailed: lyricFailed ?? this.lyricFailed,
      );
  factory PlayerState.idle() => const PlayerState(PlayerPhase.idle);
  factory PlayerState.loading() => const PlayerState(PlayerPhase.loading);
  factory PlayerState.playing() => const PlayerState(PlayerPhase.playing);
  factory PlayerState.paused() => const PlayerState(PlayerPhase.paused);
  factory PlayerState.error() => const PlayerState(PlayerPhase.error);
  bool get isPlaying => phase == PlayerPhase.playing;
}

class PlayerController extends StateNotifier<PlayerState> {
  MusicAudioHandler _handler;
  final ApiClient _apiClient;
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;

  String? _playingUrlId;
  String? get playingUrlId => _playingUrlId;

  LrcParser? _lyric;
  int _currentLyricIndex = -1;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<dynamic>? _completeSub;
  StreamSubscription<bool>? _playingSub;

  static String get _lyricCacheDir => '${Directory.systemTemp.path}/lyric_cache';

  PlayerController(this._apiClient, this._handler) : super(PlayerState.idle()) {
    Directory(_lyricCacheDir).createSync(recursive: true);
    _wireHandlerCallbacks();
  }

  void setHandler(MusicAudioHandler handler) {
    _handler = handler;
    _wireHandlerCallbacks();
  }

  void _wireHandlerCallbacks() {
    _handler.onSkipToNext = () {
      if (_playlist.isNotEmpty) next();
    };
    _handler.onSkipToPrevious = () {
      if (_playlist.isNotEmpty) previous();
    };
  }

  MusicAudioHandler get handler => _handler;
  AudioPlayer get player => _handler.player;
  Song? get currentSong => _currentSong;
  Duration get position => _handler.position;
  Duration? get duration => _handler.duration;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  int get playMode => state.playMode;
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
    _playingUrlId = null;
    state = PlayerState.loading();

    try {
      final data = await _apiClient.getPlayUrl(song.id);
      final url = data['url'] as String;

      final coverUrl = await const PlatformCoverService().fetchUrl(song.type, song.title, song.artist);

      await _handler.loadSong(
        url: url,
        id: song.id.toString(),
        title: song.title,
        artist: song.artist,
        album: song.album,
        artUri: coverUrl != null ? Uri.parse(coverUrl) : null,
      );
      await _handler.play();
      state = PlayerState.playing();

      _positionSub?.cancel();
      _durationSub?.cancel();
      _completeSub?.cancel();
      _playingSub?.cancel();
      _positionSub = _handler.player.positionStream.listen(_onPositionChanged);
      _durationSub = _handler.player.durationStream.listen((_) {});
      _playingSub = _handler.player.playingStream.listen((playing) {
        if (!playing && state.isPlaying) {
          state = PlayerState.paused();
        }
      });
      _completeSub = _handler.player.playerStateStream.listen((ps) {
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
    state = state.copyWith(lyricLoading: true, lyricFailed: false);

    final cached = _readLyricCache(songId);
    if (cached != null) {
      _lyric = LrcParser.parse(cached);
      state = state.copyWith(lyricLoading: false);
      return;
    }

    try {
      final lrcText = await _apiClient.getLyric(songId);
      if (lrcText.isNotEmpty) {
        _lyric = LrcParser.parse(lrcText);
        _writeLyricCache(songId, lrcText);
        state = state.copyWith(lyricLoading: false);
      } else {
        state = state.copyWith(lyricLoading: false, lyricFailed: true);
      }
    } catch (_) {
      _lyric = null;
      state = state.copyWith(lyricLoading: false, lyricFailed: true);
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
    if (state.playMode == 1) {
      _handler.seek(Duration.zero);
      _handler.play();
      state = PlayerState.playing();
    } else {
      state = PlayerState.paused();
      next();
    }
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
    if (state.playMode == 2) {
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
    } else if (state.playMode == 0) {
      _currentIndex = 0;
      await play(_playlist[_currentIndex]);
    }
  }

  Future<void> previous() async {
    if (_playlist.isEmpty) return;
    if (state.playMode == 2) {
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
    } else if (state.playMode == 0) {
      _currentIndex = _playlist.length - 1;
      await play(_playlist[_currentIndex]);
    }
  }

  Future<void> playUrl(String url, String title, String artist, {String? platform, String? id, String? lyric}) async {
    try {
      state = PlayerState.loading();
      _currentSong = Song(id: 0, title: title, artist: artist, album: '', format: '', duration: 0, size: 0, createdAt: 0);
      _lyric = (lyric != null && lyric.isNotEmpty) ? LrcParser.parse(lyric) : null;
      _currentLyricIndex = -1;
      _playingUrlId = (platform != null && id != null) ? '$platform|$id' : null;

      await _handler.loadSong(
        url: url,
        id: '',
        title: title,
        artist: artist,
      );
      await _handler.play();
      state = PlayerState.playing();

      _positionSub?.cancel();
      _durationSub?.cancel();
      _completeSub?.cancel();
      _playingSub?.cancel();
      _positionSub = _handler.player.positionStream.listen(_onPositionChanged);
      _durationSub = _handler.player.durationStream.listen((_) {});
      _playingSub = _handler.player.playingStream.listen((playing) {
        if (!playing && state.isPlaying) {
          state = PlayerState.paused();
        }
      });
      _completeSub = _handler.player.playerStateStream.listen((ps) {
        if (ps.processingState == ProcessingState.completed) {
          onSongEnd();
        }
      });
    } catch (e) {
      state = PlayerState.error();
    }
  }

  void togglePlayPause() {
    if (_handler.playing) {
      _handler.pause();
      state = PlayerState.paused();
    } else {
      _handler.play();
      state = PlayerState.playing();
    }
  }

  void seekTo(Duration position) {
    _handler.seek(position);
  }

  void togglePlayMode() {
    final newMode = (state.playMode + 1) % 3;
    state = state.copyWith(playMode: newMode);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _playingSub?.cancel();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerController, PlayerState>((ref) {
  final api = ref.read(apiClientProvider);
  final handler = ref.watch(audioHandlerProvider);
  final controller = PlayerController(api, handler);

  ref.listen(audioHandlerProvider, (_, next) {
    controller.setHandler(next);
  });

  return controller;
});
