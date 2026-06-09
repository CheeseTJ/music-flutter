import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../data/models/song.dart';
import '../../../data/datasources/remote/api_client.dart';

enum PlayerState { idle, loading, playing, paused, error }

class PlayerController extends StateNotifier<PlayerState> {
  final AudioPlayer _player = AudioPlayer();
  final ApiClient _apiClient;
  Song? _currentSong;
  List<Song> _playlist = [];
  int _currentIndex = -1;
  int _playMode = 0;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  PlayerController(this._apiClient) : super(PlayerState.idle);

  AudioPlayer get player => _player;
  Song? get currentSong => _currentSong;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get hasNext => _currentIndex < _playlist.length - 1;
  bool get hasPrevious => _currentIndex > 0;
  int get playMode => _playMode;

  void setPlaylist(List<Song> songs) {
    _playlist = songs;
  }

  Future<void> play(Song song) async {
    final index = _playlist.indexWhere((s) => s.id == song.id);
    if (index >= 0) _currentIndex = index;

    _currentSong = song;
    state = PlayerState.loading;

    try {
      final data = await _apiClient.getPlayUrl(song.id);
      final url = data['url'] as String;

      await _player.setUrl(url);
      _player.play();
      state = PlayerState.playing;

      _positionSub?.cancel();
      _durationSub?.cancel();
      _positionSub = _player.positionStream.listen((_) {});
      _durationSub = _player.durationStream.listen((_) {});

      _player.playerStateStream.listen((ps) {
        if (ps.processingState == ProcessingState.completed) {
          onSongEnd();
        }
      });
    } catch (e) {
      state = PlayerState.error;
    }
  }

  void onSongEnd() {
    if (_playMode == 1) {
      _player.seek(Duration.zero);
      _player.play();
    } else {
      next();
    }
  }

  Future<void> next() async {
    if (_playlist.isEmpty) return;
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
    if (_currentIndex > 0) {
      _currentIndex--;
      await play(_playlist[_currentIndex]);
    }
  }

  void togglePlayPause() {
    if (_player.playing) {
      _player.pause();
      state = PlayerState.paused;
    } else {
      _player.play();
      state = PlayerState.playing;
    }
  }

  void seekTo(Duration position) {
    _player.seek(position);
  }

  void togglePlayMode() {
    _playMode = (_playMode + 1) % 3;
  }

  String get playModeLabel {
    switch (_playMode) {
      case 0:
        return '列表循环';
      case 1:
        return '单曲循环';
      case 2:
        return '随机播放';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}

final playerProvider =
    StateNotifierProvider<PlayerController, PlayerState>((ref) {
  final api = ref.read(apiClientProvider);
  return PlayerController(api);
});
