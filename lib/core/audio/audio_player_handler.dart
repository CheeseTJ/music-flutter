import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'notification_service.dart';
import 'custom_notification_service.dart';

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
  void Function()? onStop;

  MusicAudioHandler() {
    debugPrint('[AudioHandler] Created');
    _player.playbackEventStream.listen(_broadcastState);

    _positionSub = _player.positionStream.listen((pos) {
      _positionController.add(pos);
      _broadcastPosition(pos);
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

  Timer? _positionTimer;
  // 周期更新 PlaybackState 的 position，让锁屏/通知进度条实时移动
  void _broadcastPosition(Duration pos) {
    if (_positionTimer?.isActive ?? false) return;
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isPlaying) {
        _positionTimer?.cancel();
        _positionTimer = null;
        return;
      }
      playbackState.add(playbackState.value.copyWith(
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
      ));
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
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.skipToPrevious,
        MediaAction.playPause,
        MediaAction.skipToNext,
        MediaAction.seek,
        MediaAction.stop,
      },
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

  /// 媒体按键（耳机线控/蓝牙按键）由 Android MediaButtonReceiver 自动转成
  /// MediaSession transport controls 调用，最终走到 play()/pause()/
  /// skipToNext()/skipToPrevious()。无需在 Dart 端手动处理 KeyEvent。

  Future<void> loadSong({
    required String url,
    required String id,
    required String title,
    required String artist,
    String? album,
    Uri? artUri,
  }) async {
    _currentUrl = url;
    debugPrint('[AudioHandler] loadSong: $title - $artist, artUri=$artUri');
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
    debugPrint('[AudioHandler] play');
    _player.play();
    _isPlaying = true;
  }

  @override
  Future<void> pause() async {
    debugPrint('[AudioHandler] pause');
    _player.pause();
    _isPlaying = false;
  }

  @override
  Future<void> stop() async {
    debugPrint('[AudioHandler] stop');
    _positionTimer?.cancel();
    _positionTimer = null;
    await _player.stop();
    _isPlaying = false;
    // 通知 PlayerController 清空 currentSong，让 mini player 消失
    onStop?.call();
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
    _positionTimer?.cancel();
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
  debugPrint('[AudioService] init start');
  final info = await NotificationService.debugInfo();
  debugPrint('[AudioService] device info:\n$info');

  // 重试 3 次，确保 audio_service 始终可用（避免 fallback 到自定义通知导致蓝牙按键失效）
  for (var attempt = 1; attempt <= 3; attempt++) {
    try {
      final handler = await AudioService.init(
        builder: () => MusicAudioHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.example.music_app.channel.audio',
          androidNotificationChannelName: '\u97f3\u4e50\u64ad\u653e',
          androidNotificationIcon: 'drawable/ic_stat_music_note',
          androidNotificationClickStartsActivity: true,
          androidStopForegroundOnPause: false,
        ),
      ).timeout(const Duration(seconds: 15));
      controller.state = handler;
      debugPrint('[AudioService] init success (attempt $attempt)');
      return;
    } catch (e, stack) {
      debugPrint('[AudioService] init attempt $attempt FAILED: $e');
      debugPrint('[AudioService] stack: $stack');
      if (attempt < 3) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }
  debugPrint('[AudioService] init failed after 3 attempts, falling back to custom notification');
  CustomNotificationService.enable();
}
