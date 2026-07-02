import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../data/models/song.dart';
import '../../../core/audio/audio_player_handler.dart';
import '../../../core/audio/custom_notification_service.dart';
import '../../../core/utils/playback_history.dart';
import '../../../core/utils/settings.dart';
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
  bool _isSkipping = false;
  final _random = Random();

  static String get _lyricCacheDir => '${Directory.systemTemp.path}/lyric_cache';

  Uri? _fallbackArtUri;
  Future<Uri> _getFallbackArtUri() async {
    if (_fallbackArtUri != null) return _fallbackArtUri!;
    try {
      final data = await rootBundle.load('assets/icons/logo.png');
      final file = File('${Directory.systemTemp.path}/cover_fallback.png');
      await file.writeAsBytes(data.buffer.asUint8List());
      _fallbackArtUri = Uri.file(file.path);
    } catch (_) {
      _fallbackArtUri = Uri.parse('https://via.placeholder.com/300');
    }
    return _fallbackArtUri!;
  }

  PlayerController(this._apiClient, this._handler) : super(PlayerState.idle()) {
    _wireHandlerCallbacks();
    _wireCustomNotificationActions();
    _restorePlayMode();
  }

  void _restorePlayMode() {
    Settings.getPlayMode().then((mode) {
      state = state.copyWith(playMode: mode);
    });
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

  StreamSubscription<String>? _customNotifSub;
  void _wireCustomNotificationActions() {
    if (!CustomNotificationService.isEnabled) return;
    _customNotifSub = CustomNotificationService.onAction.listen((action) {
      switch (action) {
        case 'play':
          _handler.play();
          state = state.copyWith(phase: PlayerPhase.playing);
          CustomNotificationService.updatePlayState(true);
          break;
        case 'pause':
          _handler.pause();
          state = state.copyWith(phase: PlayerPhase.paused);
          CustomNotificationService.updatePlayState(false);
          break;
        case 'skipNext':
          if (_playlist.isNotEmpty) next();
          break;
        case 'skipPrev':
          if (_playlist.isNotEmpty) previous();
          break;
      }
    });
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

  Future<void> load(Song song) async {
    try {
      await _loadSongInternal(song);
      state = state.copyWith(phase: PlayerPhase.paused);
      _wirePlayerStreams();
      _fetchLyric(song.id);
    } catch (e) {
      state = state.copyWith(phase: PlayerPhase.error);
    }
  }

  Future<void> play(Song song) async {
    try {
      await _loadSongInternal(song);
      await _handler.play();
      state = state.copyWith(phase: PlayerPhase.playing);
      _syncCustomNotification(_lastCoverUrl ?? _fallbackArtUri?.toString());
      _wirePlayerStreams();
      _fetchLyric(song.id);
    } catch (e) {
      state = state.copyWith(phase: PlayerPhase.error);
    }
  }

  String? _lastCoverUrl;

  Future<void> _loadSongInternal(Song song) async {
    final index = _playlist.indexWhere((s) => s.id == song.id);
    if (index >= 0) _currentIndex = index;

    _currentSong = song;
    _lyric = null;
    _currentLyricIndex = -1;
    _playingUrlId = null;
    state = state.copyWith(phase: PlayerPhase.loading);

    final data = await _apiClient.getPlayUrl(song.id);
    final url = data['url'] as String;

    _lastCoverUrl = await const PlatformCoverService().fetchUrl(song.type, song.title, song.artist);
    final cover = _lastCoverUrl;
    final artUri = cover != null ? Uri.parse(cover) : await _getFallbackArtUri();

    await _handler.loadSong(
      url: url,
      id: song.id.toString(),
      title: song.title,
      artist: song.artist,
      album: song.album,
      artUri: artUri,
    );

    PlaybackHistory().record(song.id, song.title, song.artist, song.format, song.duration, 0, song.size);
  }

  void _wirePlayerStreams() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _playingSub?.cancel();
    _positionSub = _handler.player.positionStream.listen(_onPositionChanged);
    _durationSub = _handler.player.durationStream.listen((_) {});
    _playingSub = _handler.player.playingStream.listen((playing) {
      if (!playing && state.isPlaying) {
        state = state.copyWith(phase: PlayerPhase.paused);
      }
    });
    _completeSub = _handler.player.playerStateStream.listen((ps) {
      if (ps.processingState == ProcessingState.completed) {
        onSongEnd();
      }
    });
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

    await _ensureLyricCacheDir();
    final cached = await _readLyricCache(songId);
    if (cached != null) {
      _lyric = LrcParser.parse(cached);
      state = state.copyWith(lyricLoading: false);
      return;
    }

    try {
      final lrcText = await _apiClient.getLyric(songId);
      if (lrcText.isNotEmpty) {
        _lyric = LrcParser.parse(lrcText);
        await _writeLyricCache(songId, lrcText);
        state = state.copyWith(lyricLoading: false);
      } else {
        state = state.copyWith(lyricLoading: false, lyricFailed: true);
      }
    } catch (_) {
      _lyric = null;
      state = state.copyWith(lyricLoading: false, lyricFailed: true);
    }
  }

  bool _cacheDirReady = false;
  Future<void> _ensureLyricCacheDir() async {
    if (_cacheDirReady) return;
    await Directory(_lyricCacheDir).create(recursive: true);
    _cacheDirReady = true;
  }

  Future<String?> _readLyricCache(int songId) async {
    try {
      final file = File('$_lyricCacheDir/$songId.lrc');
      if (await file.exists()) return await file.readAsString();
    } catch (_) {}
    return null;
  }

  Future<void> _writeLyricCache(int songId, String text) async {
    try {
      await File('$_lyricCacheDir/$songId.lrc').writeAsString(text);
    } catch (_) {}
  }

  void onSongEnd() {
    debugPrint('[onSongEnd] playMode=${state.playMode} playlist=${_playlist.length} idx=$_currentIndex isSkipping=$_isSkipping');
    if (state.playMode == 1) {
      _handler.seek(Duration.zero);
      _handler.play();
      state = state.copyWith(phase: PlayerPhase.playing);
    } else {
      state = state.copyWith(phase: PlayerPhase.paused);
      next();
    }
  }

  int _randomIndex() {
    if (_playlist.length == 1) return 0;
    var idx = _currentIndex;
    while (idx == _currentIndex) {
      idx = _random.nextInt(_playlist.length);
    }
    return idx;
  }

  Future<void> next() async {
    if (_playlist.isEmpty || _isSkipping) return;
    _isSkipping = true;
    try {
      await _handler.stop();
      state = state.copyWith(phase: PlayerPhase.paused);
      if (state.playMode == 2) {
        if (_playlist.length == 1) {
          await play(_playlist[0]);
          return;
        }
        _currentIndex = _randomIndex();
        await play(_playlist[_currentIndex]);
        return;
      }
      if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
        debugPrint('[next] -> idx=$_currentIndex');
        await play(_playlist[_currentIndex]);
      } else if (state.playMode == 0) {
        _currentIndex = 0;
        debugPrint('[next] loop -> idx=$_currentIndex');
        await play(_playlist[_currentIndex]);
      } else {
        debugPrint('[next] end, no loop');
      }
    } finally {
      _isSkipping = false;
    }
  }

  Future<void> previous() async {
    if (_playlist.isEmpty || _isSkipping) return;
    _isSkipping = true;
    try {
      await _handler.stop();
      state = state.copyWith(phase: PlayerPhase.paused);
      if (state.playMode == 2) {
        _currentIndex = _randomIndex();
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
    } finally {
      _isSkipping = false;
    }
  }

  Future<void> playUrl(String url, String title, String artist, {String? platform, String? id, String? lyric}) async {
    try {
      state = state.copyWith(phase: PlayerPhase.loading);
      final songId = int.tryParse(id ?? '') ?? 0;
      _currentSong = Song(id: songId, title: title, artist: artist, album: '', format: '', duration: 0, size: 0, createdAt: 0);
      _lyric = (lyric != null && lyric.isNotEmpty) ? LrcParser.parse(lyric) : null;
      _currentLyricIndex = -1;
      _playingUrlId = (platform != null && id != null) ? '$platform|$id' : null;
      // 维护单曲 playlist，使 next/previous 可用
      _playlist = [_currentSong!];
      _currentIndex = 0;

      await _handler.loadSong(
        url: url,
        id: '',
        title: title,
        artist: artist,
        artUri: await _getFallbackArtUri(),
      );
      await _handler.play();
      state = state.copyWith(phase: PlayerPhase.playing);
      _syncCustomNotification(null);
      // 在线播放也写入历史，保证最新一条可被冷启动恢复
      if (songId != 0) {
        await PlaybackHistory().record(songId, title, artist, '', 0, 0, 0);
      }
      _wirePlayerStreams();
    } catch (e) {
      state = state.copyWith(phase: PlayerPhase.error);
    }
  }

  void togglePlayPause() {
    if (_handler.playing) {
      _handler.pause();
      state = state.copyWith(phase: PlayerPhase.paused);
      CustomNotificationService.updatePlayState(false);
    } else {
      _handler.play();
      state = state.copyWith(phase: PlayerPhase.playing);
      CustomNotificationService.updatePlayState(true);
    }
  }

  void seekTo(Duration position) {
    _handler.seek(position);
  }

  void _syncCustomNotification(String? coverUrl) {
    if (!CustomNotificationService.isEnabled) return;
    final song = _currentSong;
    if (song == null) {
      debugPrint('[CustomNotif] _syncCustomNotification skipped: no current song');
      return;
    }
    debugPrint('[CustomNotif] _syncCustomNotification: ${song.title} - ${song.artist}, coverUrl=$coverUrl');
    CustomNotificationService.show(
      title: song.title,
      artist: song.artist,
      album: song.album,
      coverUrl: coverUrl,
      playing: true,
    );
  }

  void togglePlayMode() {
    final newMode = (state.playMode + 1) % 3;
    state = state.copyWith(playMode: newMode);
    Settings.setPlayMode(newMode);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _playingSub?.cancel();
    _customNotifSub?.cancel();
    CustomNotificationService.hide();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerController, PlayerState>((ref) {
  final api = ref.read(apiClientProvider);
  // 用 read 而非 watch：避免 audioHandlerProvider 变化时重建整个 controller
  // （否则 initAudioService 完成后会丢弃已恢复的 _currentSong）
  final handler = ref.read(audioHandlerProvider);
  final controller = PlayerController(api, handler);

  ref.listen(audioHandlerProvider, (_, next) {
    controller.setHandler(next);
  });

  return controller;
});
