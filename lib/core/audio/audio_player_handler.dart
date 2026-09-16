import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'notification_service.dart';
import 'package:music_app/core/i18n/app_strings.dart';

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();

  bool _isPlaying = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<bool>? _playingSub;

  void Function()? onSkipToNext;
  void Function()? onSkipToPrevious;

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

  /// 通知栏 / 锁屏上的操作按钮。
  ///
  /// 不用 [MediaControl] 的预设常量（skipToPrevious 等）：那些预设指向插件
  /// 自带的图标（audio_service_skip_next 之类），造型老旧，label 也固定为
  /// 英文。这里换成自绘的白色矢量图标，label 跟随界面语言。
  ///
  /// 刻意不含停止按钮：停止会清空当前曲目（迷你播放器一起消失），语义上
  /// 跟暂停重复但后果更重，放通知栏容易被误触。
  List<MediaControl> _buildControls({required bool playing}) => [
        MediaControl(
          androidIcon: 'drawable/ic_notif_prev',
          label: L.s.previousSong,
          action: MediaAction.skipToPrevious,
        ),
        if (playing)
          MediaControl(
            androidIcon: 'drawable/ic_notif_pause',
            label: L.s.pause,
            action: MediaAction.pause,
          )
        else
          MediaControl(
            androidIcon: 'drawable/ic_notif_play',
            label: L.s.play,
            action: MediaAction.play,
          ),
        MediaControl(
          androidIcon: 'drawable/ic_notif_next',
          label: L.s.nextSong,
          action: MediaAction.skipToNext,
        ),
      ];

  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: _buildControls(playing: playing),
      systemActions: const {
        MediaAction.skipToPrevious,
        MediaAction.playPause,
        MediaAction.skipToNext,
        MediaAction.seek,
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
    // 必须 await：_player.play() 内部可能因音频会话激活失败而静默回退
    // （把 playing 置回 false），不 await 的话调用方会误以为已经开播，
    // 自动切歌场景就表现为「播完没下一首」。
    await _player.play();
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

/// 初始化 audio_service：后台播放 + 通知栏播控。
///
/// 别把「通知栏播控」和「锁屏播控卡片 / 控制中心媒体卡片」混为一谈。前者是
/// Android 标准能力，我们已完整适配（会话 active、flags 含 TRANSPORT_CONTROLS、
/// PlaybackState 有 actions、通知 category=transport）。后者在华为 / vivo / OPPO
/// 上是厂商白名单机制，非白名单应用拿不到，**改代码无解** —— 别为此 fork
/// audio_service 去补 setCategory / setFlags，那些字段本来就是对的。
/// 详见 README「锁屏 / 控制中心的媒体播控：厂商白名单问题」。
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
          androidNotificationChannelName: L.s.musicPlayback,
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
  // 不再退回到「自研通知」那条路径。它的 MediaSession 既没有回调也没有
  // MediaMetadata，华为等厂商的系统不会把它渲染成锁屏播控卡片；按钮还得
  // 再维护一套。现在只留 audio_service 这一条，初始化失败就只是没通知，
  // 播放本身不受影响。
  debugPrint('[AudioService] init failed after 3 attempts; notification unavailable');
}
