import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();

  String? _currentUrl;
  bool _isPlaying = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;

  MusicAudioHandler() {
    _player.playbackEventStream.listen(_broadcastState);

    _positionSub = _player.positionStream.listen((pos) {
      _positionController.add(pos);
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null && mediaItem.value != null) {
        final item = mediaItem.value!;
        if (item.duration != dur) {
          mediaItem.add(item.copyWith(duration: dur));
        }
      }
    });

    _playingSub = _player.playingStream.listen((playing) {
      _isPlaying = playing;
    });
  }

  AudioPlayer get player => _player;
  Stream<Duration> get positionStream => _positionController.stream;
  Duration get position => _player.position;
  Duration? get duration => _player.duration;
  bool get playing => _isPlaying;
  String? get currentUrl => _currentUrl;

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  Future<void> loadSong({
    required String url,
    required String id,
    required String title,
    required String artist,
    String? album,
    Uri? artUri,
  }) async {
    _currentUrl = url;
    mediaItem.add(MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artUri: artUri,
    ));
    await _player.setUrl(url);
  }

  @override
  Future<void> play() async {
    _player.play();
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    _player.pause();
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _isPlaying = false;
    return super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() {
    onSkipToNext?.call();
    return super.skipToNext();
  }

  @override
  Future<void> skipToPrevious() {
    onSkipToPrevious?.call();
    return super.skipToPrevious();
  }

  Future<void> close() async {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _playingSub?.cancel();
    await _positionController.close();
    await _player.dispose();
  }
}

final audioHandlerProvider = StateProvider<MusicAudioHandler>((ref) {
  final handler = MusicAudioHandler();
  return handler;
});

Future<void> initAudioService(StateController<MusicAudioHandler> controller) async {
  await Future.delayed(const Duration(milliseconds: 800));
  try {
    final handler = await AudioService.init(
      builder: () => MusicAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.example.music_app.channel.audio',
        androidNotificationChannelName: '\u97f3\u4e50\u64ad\u653e',
        // Status bar / lock-screen small icon. Must be a flat white
        // silhouette on a transparent background — Android tints it
        // automatically to match the system theme. Without this the
        // default launcher icon gets used, which looks like a blob.
        androidNotificationIcon: 'ic_stat_music_note',
        // Accent color used for the small icon tint and the
        // notification's expand-button ring on Android 5–12. Matches
        // the Pearl accent (cyan-blue) so the media chip feels part
        // of the app's brand.
        androidNotificationColor: const Color(0xFF44D3FF),
        // Click the body of the notification (not the controls) →
        // open the app to the player page.
        androidNotificationClickStartsActivity: true,
        // Foreground service stays running while playing; drop the
        // foreground notification on pause so the status bar quiets
        // down when nothing is playing.
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    ).timeout(const Duration(seconds: 10));
    controller.state = handler;
  } catch (_) {}
}