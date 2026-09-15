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

  /// 当前在线曲目的标识（`platform|id`；本地曲目为 null）。
  ///
  /// 必须放进 state：界面靠它决定「哪一行高亮」「要不要显示底部小组件」，
  /// 而它变化时 phase 不一定跟着变（连着点两首是 loading → loading）。
  /// 如果只改 controller 的普通字段，不会触发重建，界面就会一直停在上一首
  /// —— 表现为「点了 B，A 还在转圈」。
  final String? playingUrlId;

  const PlayerState(this.phase, {this.playMode = 0, this.lyricLoading = false, this.lyricFailed = false, this.playingUrlId});
  PlayerState copyWith({
    PlayerPhase? phase,
    int? playMode,
    bool? lyricLoading,
    bool? lyricFailed,
    String? playingUrlId,
    bool clearPlayingUrlId = false,
  }) =>
      PlayerState(
        phase ?? this.phase,
        playMode: playMode ?? this.playMode,
        lyricLoading: lyricLoading ?? this.lyricLoading,
        lyricFailed: lyricFailed ?? this.lyricFailed,
        playingUrlId: clearPlayingUrlId ? null : (playingUrlId ?? this.playingUrlId),
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
  LocalSong? _currentSong;
  List<LocalSong> _playlist = [];
  int _currentIndex = -1;

  String? get playingUrlId => state.playingUrlId;

  LrcParser? _lyric;
  int _currentLyricIndex = -1;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<dynamic>? _completeSub;
  StreamSubscription<bool>? _playingSub;
  bool _isSkipping = false;
  final _random = Random();

  /// 播放请求序号：每发起一次「加载一首歌」就自增。
  ///
  /// 取链、取词、下封面都是异步的，这期间用户可能又点了别的歌。只有序号
  /// 最大（最后一次）的那次请求才允许落地，其余全部丢弃 —— 否则慢的那次
  /// 会在快的之后完成，表现就是「先放了第一首，再跳去第二首」。
  int _loadSeq = 0;

  /// 进入在线播放预备态之前的快照，用于取链失败时把界面还原回原来在放的歌。
  /// 写入用 ??=：连点两首时，只有第一次（真正在放的那首）才值得还原。
  _PrePlaySnapshot? _prePlay;

  /// [seq] 是否仍是最新一次播放请求。
  bool isCurrentLoad(int seq) => seq == _loadSeq;

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
  LocalSong? get currentSong => _currentSong;
  Duration get position => _handler.position;
  Duration? get duration => _handler.duration;
  int get playMode => state.playMode;
  LrcParser? get lyric => _lyric;
  bool get lyricLoading => state.lyricLoading;
  bool get lyricFailed => state.lyricFailed;
  void setPlaylist(List<LocalSong> songs) {
    _playlist = songs;
    // 修正 _currentIndex，解决冷启动恢复时 setPlaylist 晚于 load 导致的索引错位
    if (_currentSong != null) {
      final idx = _playlist.indexWhere((s) => s.id == _currentSong!.id);
      if (idx >= 0) _currentIndex = idx;
    }
  }

  Future<void> load(LocalSong song) async {
    final seq = ++_loadSeq;
    _prePlay = null;
    try {
      await _loadSongInternal(song, seq);
      if (!isCurrentLoad(seq)) return;
      // 先挂监听：playingStream 订阅后会立即推送当前值，能把状态拉回真实值
      _wirePlayerStreams();
      // 加载期间用户可能已经点了播放，此时不能再无条件改回暂停
      if (!_handler.playing) {
        state = state.copyWith(phase: PlayerPhase.paused);
      }
      _fetchLyric(song.id);
    } catch (e) {
      if (!isCurrentLoad(seq)) return;
      state = state.copyWith(phase: PlayerPhase.error);
    }
  }

  Future<void> play(LocalSong song) async {
    final seq = ++_loadSeq;
    // 本地播放不需要预备态回滚
    _prePlay = null;
    try {
      await _loadSongInternal(song, seq);
      if (!isCurrentLoad(seq)) return;
      await _handler.play();
      if (!isCurrentLoad(seq)) return;
      state = state.copyWith(phase: PlayerPhase.playing);
      // 原生侧用 URL(...).openConnection() 取图，只认带协议的地址。
      // 而 _lastCoverUrl 是本地文件路径（没有协议），直接传过去会 MalformedURLException，
      // 被 catch 吞掉，表现就是通知栏永远显示兜底 logo、从不显示真实封面。
      // 这里统一转成 file:// URI（java.net.URL 支持 file 协议）。
      _syncCustomNotification(_lastCoverUrl != null
          ? Uri.file(_lastCoverUrl!).toString()
          : _fallbackArtUri?.toString());
      _wirePlayerStreams();
      _fetchLyric(song.id);
    } catch (e) {
      if (!isCurrentLoad(seq)) return;
      state = state.copyWith(phase: PlayerPhase.error);
    }
  }

  String? _lastCoverUrl;

  Future<void> _loadSongInternal(LocalSong song, int seq) async {
    final index = _playlist.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      _currentIndex = index;
    } else if (_playlist.isEmpty) {
      // 冷启动恢复场景：歌单 API 还没返回，至少把当前歌加入播放列表
      _playlist = [song];
      _currentIndex = 0;
    }

    _currentSong = song;
    _lyric = null;
    _currentLyricIndex = -1;
    state = state.copyWith(phase: PlayerPhase.loading, clearPlayingUrlId: true);

    final data = await _apiClient.getPlayUrl(song.id);
    if (!isCurrentLoad(seq)) return;
    final url = data['url'] as String;

    _lastCoverUrl = await const PlatformCoverService().fetch(song.type, song.title, song.artist);
    if (!isCurrentLoad(seq)) return;
    final cover = _lastCoverUrl;
    final artUri = cover != null ? Uri.file(cover) : await _getFallbackArtUri();
    if (!isCurrentLoad(seq)) return;

    await _handler.loadSong(
      url: url,
      id: song.id.toString(),
      title: song.title,
      artist: song.artist,
      album: song.album,
      artUri: artUri,
    );
    if (!isCurrentLoad(seq)) return;

    PlaybackHistory().record(song.id);
  }

  void _wirePlayerStreams() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    _completeSub?.cancel();
    _playingSub?.cancel();
    _positionSub = _handler.player.positionStream.listen(_onPositionChanged);
    _durationSub = _handler.player.durationStream.listen((_) {});
    // 双向同步：图标必须跟随真实播放状态。
    // 只处理「停止」方向的话，phase 一旦被写错就再也纠正不回来。
    _playingSub = _handler.player.playingStream.listen((playing) {
      if (playing) {
        if (state.phase != PlayerPhase.playing) {
          state = state.copyWith(phase: PlayerPhase.playing);
        }
      } else if (state.isPlaying) {
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

  /// 在线播放的预备态：立刻把当前曲目和 loading 状态落地。
  ///
  /// 在线播放要先取链（并发请求所有音质档位）再取词，可能耗时数秒。若等取完
  /// 再改状态，这段时间界面完全没有变化，用户会以为卡住了。所以这里先让底部
  /// 迷你播放器以「这首歌 + 转圈」的形式出现，取链成功后再真正播放。
  ///
  /// 返回请求序号，调用方在每个 await 之后用 [isCurrentLoad] 校验，失败时用
  /// [abortOnlinePlay] 还原界面。
  int beginOnlinePlay(String title, String artist, {String? platform, String? id}) {
    _prePlay ??= _PrePlaySnapshot(
      song: _currentSong,
      playlist: _playlist,
      index: _currentIndex,
      lyric: _lyric,
      lyricIndex: _currentLyricIndex,
      state: state,
    );
    final seq = ++_loadSeq;
    final songId = int.tryParse(id ?? '') ?? 0;
    final urlId = (platform != null && id != null) ? '$platform|$id' : null;
    _currentSong = LocalSong(
        id: songId, title: title, artist: artist, album: '',
        format: '', duration: 0, size: 0, createdAt: 0);
    _lyric = null;
    _currentLyricIndex = -1;
    // 维护单曲 playlist，使 next/previous 可用
    _playlist = [_currentSong!];
    _currentIndex = 0;
    state = state.copyWith(
      phase: PlayerPhase.loading,
      lyricLoading: false,
      lyricFailed: false,
      playingUrlId: urlId,
      clearPlayingUrlId: urlId == null,
    );
    return seq;
  }

  /// 预备态失败：把界面还原到进入预备态之前（原来在放的那首继续在放）。
  /// 过期的序号直接忽略 —— 那时界面已经属于更新的一次点击了。
  void abortOnlinePlay(int seq) {
    if (!isCurrentLoad(seq)) return;
    final snap = _prePlay;
    _prePlay = null;
    if (snap == null) return;
    _currentSong = snap.song;
    _playlist = snap.playlist;
    _currentIndex = snap.index;
    _lyric = snap.lyric;
    _currentLyricIndex = snap.lyricIndex;
    state = snap.state;
  }

  Future<void> playUrl(String url, String title, String artist, {String? platform, String? id, String? lyric}) async {
    final seq = beginOnlinePlay(title, artist, platform: platform, id: id);
    try {
      _lyric = (lyric != null && lyric.isNotEmpty) ? LrcParser.parse(lyric) : null;

      await _handler.loadSong(
        url: url,
        id: '',
        title: title,
        artist: artist,
        artUri: await _getFallbackArtUri(),
      );
      if (!isCurrentLoad(seq)) return;
      await _handler.play();
      if (!isCurrentLoad(seq)) return;
      state = state.copyWith(phase: PlayerPhase.playing);
      // 已经真正开播，预备态不再需要回滚
      _prePlay = null;
      _syncCustomNotification(null);
      // 在线播放也写入历史，保证最新一条可被冷启动恢复
      final songId = _currentSong?.id ?? 0;
      if (songId != 0) {
        await PlaybackHistory().record(songId);
      }
      _wirePlayerStreams();
    } catch (e) {
      if (!isCurrentLoad(seq)) return;
      _prePlay = null;
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

/// 进入在线播放预备态前的播放器快照，用于取链失败时还原界面。
/// playingUrlId 在 state 里，随 [state] 一起还原。
class _PrePlaySnapshot {
  final LocalSong? song;
  final List<LocalSong> playlist;
  final int index;
  final LrcParser? lyric;
  final int lyricIndex;
  final PlayerState state;

  const _PrePlaySnapshot({
    required this.song,
    required this.playlist,
    required this.index,
    required this.lyric,
    required this.lyricIndex,
    required this.state,
  });
}
