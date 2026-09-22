import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'notification_service.dart';
import 'package:music_app/core/i18n/app_strings.dart';

/// 通话模式事件最终要转给谁 —— 即当前真正在用的 handler。
MusicAudioHandler? _audioModeTarget;
bool _audioModeListening = false;

/// 只注册一次 MethodChannel 回调，再把事件转给当前生效的 handler。
///
/// 不能省掉这层转发：见 [MusicAudioHandler.markAsActiveHandler] 的说明。
void _ensureAudioModeDispatch() {
  if (_audioModeListening) return;
  _audioModeListening = true;
  NotificationService.listenAudioMode((mode) {
    _audioModeTarget?._onAudioModeChanged(mode);
  });
}

class MusicAudioHandler extends BaseAudioHandler with SeekHandler {
  /// 中断（来电、抢焦点、耳机拔出）全部由本类自己处理，所以关掉 just_audio
  /// 内建的那套：它收到 duck 型中断时只在 `usage == game` 下把音量减半，
  /// 我们用的是 media，等于什么都不做 —— 这正是「来了电话音乐还在放」的
  /// 直接原因。焦点独占的语义要的是任何中断都让路。激活音频会话（申请焦点）
  /// 仍由 just_audio 负责，与这个开关无关。
  final AudioPlayer _player = AudioPlayer(handleInterruptions: false);
  final StreamController<Duration> _positionController = StreamController<Duration>.broadcast();

  bool _isPlaying = false;

  /// 中断发生前是否在播 —— 中断结束后据此决定要不要自动续播。
  bool _wasPlayingBeforeInterruption = false;

  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;

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

    _initInterruptionHandling();
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

  // ===================== 中断处理（焦点独占） =====================
  //
  // 「独占」在 Android 上不是能锁住 DAC，而是把焦点协商的结果改成
  // 「要么我在放，要么大家都别放」：任何中断（别人抢焦点、导航播报、
  // 提示音、来电、耳机拔出）一律暂停，结束后按中断前的意图自动续播。

  /// AudioManager 的模式值，与 MainActivity 保持一致。
  static const _modeInCall = 2; // MODE_IN_CALL
  static const _modeInCommunication = 3; // MODE_IN_COMMUNICATION

  /// 订阅音频焦点中断与「耳机拔出」。
  void _initInterruptionHandling() {
    AudioSession.instance.then((session) {
      _becomingNoisySub = session.becomingNoisyEventStream.listen((_) {
        debugPrint('[AudioHandler] becoming noisy -> pause');
        pause();
      });
      _interruptionSub = session.interruptionEventStream.listen((event) {
        debugPrint(
            '[AudioHandler] interruption: begin=${event.begin} type=${event.type}');
        if (event.begin) {
          _onInterruptionBegin();
        } else {
          _resumeAfterInterruption();
        }
      });
    });
  }

  /// 通话检测：等不到焦点回调时的兜底。
  ///
  /// 正常的焦点协商是系统主动给 app 发回调（AUDIOFOCUS_LOSS_TRANSIENT），但
  /// 部分厂商 ROM 进入通话时根本不给第三方 app 发，Dart 侧收不到任何通知，
  /// 音乐就继续播。既然等不到回调，就只能自己看 AudioManager.mode。
  /// 详见 MainActivity.startAudioModeWatch()。
  void _onAudioModeChanged(int mode) {
    final inCall = mode == _modeInCall || mode == _modeInCommunication;
    debugPrint('[AudioHandler] audio mode -> $mode (inCall=$inCall)');
    if (inCall) {
      _onInterruptionBegin();
    } else {
      _resumeAfterInterruption();
    }
  }

  /// 把自己登记为通话事件的接收方。
  ///
  /// 由 PlayerController.setHandler 调用（audio_service 初始化成功后），
  /// 别在构造函数里登记：MusicAudioHandler 不是唯一实例 —— audioHandlerProvider
  /// 先建一个，AudioService.init 成功后 audio_service 再建一个并通过
  /// setHandler 换掉它。而 Dart 侧一个 MethodChannel 只能挂一个 method call
  /// handler，后注册的会覆盖先注册的，各自在构造函数里登记就可能把事件发给那个
  /// 已被换掉、播放器里根本没歌的实例。
  void markAsActiveHandler() {
    _audioModeTarget = this;
    _ensureAudioModeDispatch();
  }

  /// 中断开始：暂停并记住「本来在播」。
  void _onInterruptionBegin() {
    // 焦点丢失和 AudioManager 模式变化是两路独立信号，会先后到达且顺序不定。
    // 只在第一路记录意图：第二路看到的 playing 已经被第一路置成 false 了，
    // 再记一次会把「中断后要续播」这件事抹掉。
    if (!_wasPlayingBeforeInterruption) {
      _wasPlayingBeforeInterruption = _player.playing;
    }
    if (_wasPlayingBeforeInterruption && _player.playing) pause();
  }

  /// 中断结束：恢复中断前的播放。用户自己按的暂停不会被这里恢复。
  Future<void> _resumeAfterInterruption() async {
    if (!_wasPlayingBeforeInterruption) return;
    _wasPlayingBeforeInterruption = false;
    // 焦点归还和 AudioManager 模式归位谁先到不确定，早的那次申请到的焦点
    // 可能还握着在通话那边，会被系统拒绝，所以要等一下并重试。
    await Future<void>.delayed(const Duration(milliseconds: 400));
    for (var attempt = 0; attempt < 3; attempt++) {
      if (_player.playing) return;
      // 不 await：焦点被拒时 just_audio 的 play() 会因为内部分支不再返回，
      // await 会把这次续播永久挂住。
      unawaited(play());
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (_player.playing) return;
    }
    debugPrint('[AudioHandler] resume after interruption failed');
  }

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
    _interruptionSub?.cancel();
    _becomingNoisySub?.cancel();
    await _positionController.close();
    await _player.dispose();
  }
}

/// 显式配置音频会话（焦点申请方式）。
///
/// 不配就会走 audio_session 的兜底配置 `AudioSessionConfiguration.music()`，
/// 它的 `androidWillPauseWhenDucked` 是 null（等于 false）：别人想压低我们
/// 音量时，系统送来的是 AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK，而 just_audio
/// 只在 usage=game 时才理会 duck（我们用的是 media），结果什么都不做 ——
/// 导航播报、提示音、来电铃声会和音乐同时出声。
///
/// 置 true 之后，系统在有人请求「压低」时直接给我们 LOSS_TRANSIENT，
/// 也就是把 duck 升级成暂停，由 [MusicAudioHandler] 统一处理成「中断」。
Future<void> configureAudioSession() async {
  try {
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration.music()
          .copyWith(androidWillPauseWhenDucked: true),
    );
    debugPrint('[AudioSession] configured: willPauseWhenDucked=true');
  } catch (e) {
    debugPrint('[AudioSession] configure failed: $e');
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

  // 必须在首次播放之前配好：焦点申请方式在 play() 激活音频会话时才生效。
  await configureAudioSession();
  debugPrint('[AudioService] current audio mode: ${await NotificationService.getAudioMode()}');

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
  //
  // 但通话兜底要补登记：成功路径是靠 setHandler 换 handler 时登记的，这里没
  // 成功、也就没换 handler —— 播放用的还是 controller 里原本那个。
  controller.state.markAsActiveHandler();
  debugPrint('[AudioService] init failed after 3 attempts; notification unavailable');
}
