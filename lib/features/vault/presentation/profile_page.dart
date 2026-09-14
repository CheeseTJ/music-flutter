import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/theme/pearl_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/app_update_service.dart';
import '../../../core/network/platform_cover_service.dart';
import '../../../core/utils/settings.dart';
import '../../collection/providers/song_list_provider.dart';
import '../../player/providers/player_provider.dart';

class VaultPage extends ConsumerStatefulWidget {
  const VaultPage({super.key});

  @override
  ConsumerState<VaultPage> createState() => _VaultPageState();
}

class _VaultPageState extends ConsumerState<VaultPage> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 必须 watch  playerProvider 本身以订阅播放状态变化，否则歌曲切换时
    // hasSong / miniPlayerHeight 不会更新，底部 padding 始终不包含迷你播放器
    ref.watch(playerProvider);
    final hasSong = ref.watch(playerProvider.notifier).currentSong != null;
    final showMiniPlayer = ref.watch(showMiniPlayerProvider);
    // viewPadding 不受 SafeArea(bottom:false) 影响，拿到真实设备底部高度
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final miniPlayerHeight = (hasSong && showMiniPlayer) ? 68.0 + 8.0 : 0.0;
    final bottomPadding = 64.0 + 16.0 + bottomInset + miniPlayerHeight + 16.0;
    final songsAsync = ref.watch(songListProvider);
    final showUploadButton = ref.watch(showUploadButtonProvider);

    final songs = songsAsync.valueOrNull ?? const [];
    final totalSongs = songs.length;
    final totalLyrics = songs.where((s) => s.hasLyric).length;
    final audioSize = songs.fold<int>(0, (sum, s) => sum + s.size);
    // Rough estimate of LRC memory:
    //   ~3 KB per minute of song (a typical LRC line is 60-120 bytes
    //   and there are ~15-20 lines per minute). Used only for the
    //   headline storage number, so the user understands the "real"
    //   on-device footprint includes the lyric cache.
    final lyricBytes = songs.where((s) => s.hasLyric).fold<int>(
          0,
          (sum, s) => sum + (s.duration ~/ 60) * 3072,
        );
    final totalStorage = audioSize + lyricBytes;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await ref.read(songListProvider.notifier).load();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding),
              children: [
                _StorageHero(
                  totalStorage: totalStorage,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                _StatsCard(
                  totalSongs: totalSongs,
                  totalLyrics: totalLyrics,
                  isDark: isDark,
                ),
                const SizedBox(height: 28),

                _HistoryEntry(
                  isDark: isDark,
                  onTap: () => context.push('/history'),
                ),
                const SizedBox(height: 28),

                _SettingsSection(
                  isDark: isDark,
                  showUploadButton: showUploadButton,
                  showMiniPlayer: showMiniPlayer,
                  onUploadButtonChanged: (v) async {
                    await Settings.setShowUploadButton(v);
                    ref.read(showUploadButtonProvider.notifier).state = v;
                  },
                  onMiniPlayerChanged: (v) async {
                    await Settings.setShowMiniPlayer(v);
                    ref.read(showMiniPlayerProvider.notifier).state = v;
                  },
                ),
                const SizedBox(height: 32),

                _AboutSection(isDark: isDark),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
//  Storage hero: huge headline number with gradient + subtitle
// ============================================================
class _StorageHero extends StatelessWidget {
  final int totalStorage;
  final bool isDark;

  const _StorageHero({required this.totalStorage, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = PearlColors.accent(isDark);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.18),
            accent.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
        border: Border.all(
          color: accent.withValues(alpha: 0.18),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Library',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: accent,
              )),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatSize(totalStorage),
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: PearlColors.textPrimary(isDark),
                    letterSpacing: -2,
                    height: 1,
                  )),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_unitFor(totalStorage),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PearlColors.textSecondary(isDark),
                    )),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Audio + lyric cache on this device',
              style: TextStyle(
                fontSize: 13,
                color: PearlColors.textSecondary(isDark),
              )),
        ],
      ),
    );
  }

  String _unitFor(int bytes) {
    if (bytes < 1024 * 1024) return 'KB';
    if (bytes < 1024 * 1024 * 1024) return 'MB';
    return 'GB';
  }
}

// ============================================================
//  Stats card: Songs / Lyrics / Duration
// ============================================================
class _StatsCard extends StatelessWidget {
  final int totalSongs;
  final int totalLyrics;
  final bool isDark;

  const _StatsCard({
    required this.totalSongs,
    required this.totalLyrics,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: PearlColors.glassBgStrong(isDark),
        borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
      ),
      child: Row(
        children: [
          Expanded(child: _StatCell(label: 'Songs',     value: '$totalSongs', isDark: isDark)),
          _Divider(isDark: isDark),
          Expanded(child: _StatCell(label: 'Lyrics',    value: '$totalLyrics', isDark: isDark)),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _StatCell({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: PearlColors.textPrimary(isDark),
              letterSpacing: -0.5,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: PearlColors.textSecondary(isDark),
            )),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  final bool isDark;
  const _Divider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1, height: 36,
      color: PearlColors.bgTertiary(isDark),
    );
  }
}

// ============================================================
//  History entry: jump to play history page
// ============================================================
class _HistoryEntry extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  const _HistoryEntry({required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: PearlColors.glassBgStrong(isDark),
          borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
        ),
        child: Row(
          children: [
            Icon(Icons.history, size: 20, color: PearlColors.accent(isDark)),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Play History',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: PearlColors.textPrimary(isDark),
                  )),
            ),
            Icon(Icons.chevron_right,
                size: 20, color: PearlColors.textSecondary(isDark)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  Settings: toggle for the bottom upload button
// ============================================================
class _SettingsSection extends StatelessWidget {
  final bool isDark;
  final bool showUploadButton;
  final bool showMiniPlayer;
  final ValueChanged<bool> onUploadButtonChanged;
  final ValueChanged<bool> onMiniPlayerChanged;
  const _SettingsSection({
    required this.isDark,
    required this.showUploadButton,
    required this.showMiniPlayer,
    required this.onUploadButtonChanged,
    required this.onMiniPlayerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Settings', isDark: isDark),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: PearlColors.glassBgStrong(isDark),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _ToggleRow(
                icon: Icons.cloud_upload_outlined,
                title: 'Show Upload Button',
                subtitle: 'Quick file picker on the bottom bar',
                value: showUploadButton,
                isDark: isDark,
                onChanged: onUploadButtonChanged,
              ),
              _ToggleRow(
                icon: Icons.play_circle_outline,
                title: 'Show Mini Player',
                subtitle: 'Now-playing bar above the tab bar',
                value: showMiniPlayer,
                isDark: isDark,
                onChanged: onMiniPlayerChanged,
              ),
              Divider(height: 1, indent: 16, endIndent: 16, color: PearlColors.bgTertiary(isDark)),
              _ClearCacheRow(isDark: isDark),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClearCacheRow extends StatefulWidget {
  final bool isDark;
  const _ClearCacheRow({required this.isDark});

  @override
  State<_ClearCacheRow> createState() => _ClearCacheRowState();
}

class _ClearCacheRowState extends State<_ClearCacheRow> {
  bool _clearing = false;

  Future<void> _clear() async {
    setState(() => _clearing = true);
    await PlatformCoverService.clearAll();
    if (!mounted) return;
    setState(() => _clearing = false);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('封面缓存已清空'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _clearing ? null : _clear,
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Icon(Icons.delete_sweep_outlined, size: 20,
              color: PearlColors.accent(widget.isDark)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clear Cover Cache',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: PearlColors.textPrimary(widget.isDark),
                    )),
                const SizedBox(height: 2),
                Text('Remove all cached cover images',
                    style: TextStyle(
                      fontSize: 12,
                      color: PearlColors.textSecondary(widget.isDark),
                    )),
              ],
            ),
          ),
          _clearing
              ? SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PearlColors.accent(widget.isDark),
                  ))
              : SizedBox(width: 20),
        ],
      ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool isDark;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: PearlColors.accent(isDark)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: PearlColors.textPrimary(isDark),
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: PearlColors.textSecondary(isDark),
                    )),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: PearlColors.accent(isDark),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ============================================================
//  About — version, copyright, GitHub link
// ============================================================
class _AboutSection extends StatelessWidget {
  final bool isDark;
  const _AboutSection({required this.isDark});

  static const _githubUrl = 'https://github.com/CheeseTJ';

  Future<void> _openGitHub() async {
    final uri = Uri.parse(_githubUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('About', isDark: isDark),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: PearlColors.glassBgStrong(isDark),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Version + 检查更新
              _UpdateRow(isDark: isDark),
              const SizedBox(height: 10),
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: PearlColors.bgTertiary(isDark),
              ),
              // Copyright + GitHub row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Copyright \u00a9 JuneT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: PearlColors.textDisabled(isDark),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _openGitHub,
                      child: SvgPicture.asset(
                        'assets/icons/Github.svg',
                        width: 20,
                        height: 20,
                        colorFilter: ColorFilter.mode(
                          PearlColors.textSecondary(isDark),
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
//  Version + 检查更新（数据来自蒲公英，下载走国内 CDN）
// ============================================================
class _UpdateRow extends StatefulWidget {
  final bool isDark;
  const _UpdateRow({required this.isDark});

  @override
  State<_UpdateRow> createState() => _UpdateRowState();
}

class _UpdateRowState extends State<_UpdateRow> {
  final AppUpdateService _service = AppUpdateService();

  String _version = '';
  AppUpdateInfo? _info;
  bool _checking = false;
  bool _downloading = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final pkg = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = pkg.version);
    // 进入页面静默检查一次，有新版就直接在行内提示
    await _check(silent: true);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _check({bool silent = false}) async {
    if (_checking || _downloading || _version.isEmpty) return;
    setState(() => _checking = true);
    try {
      final info = await _service.check(_version);
      if (!mounted) return;
      setState(() => _info = info);
      // 静默模式只在确实有新版本时才打扰用户
      if (!silent || info.hasUpdate) {
        await _showDialog(info);
      }
    } catch (e) {
      if (!silent) _toast('$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _showDialog(AppUpdateInfo info) async {
    if (!info.hasUpdate) {
      _toast('已是最新版本 v${info.currentVersion}');
      return;
    }
    final isDark = widget.isDark;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('发现新版本'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'v${info.currentVersion}  →  v${info.latestVersion}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (info.fileSizeText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('安装包 ${info.fileSizeText}',
                  style: TextStyle(
                    fontSize: 13,
                    color: PearlColors.textSecondary(isDark),
                  )),
            ],
            if (info.updateDescription.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(info.updateDescription, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('稍后'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('立即更新'),
          ),
        ],
      ),
    );
    if (go == true) await _downloadAndInstall(info);
  }

  Future<void> _downloadAndInstall(AppUpdateInfo info) async {
    if (info.downloadUrl.isEmpty) {
      _toast('蒲公英没有返回下载地址');
      return;
    }
    setState(() {
      _downloading = true;
      _progress = 0;
    });
    try {
      final path = await _service.download(
        info.downloadUrl,
        onProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = received / total);
        },
      );
      if (!mounted) return;
      setState(() => _downloading = false);

      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        _toast('无法调起安装器：${result.message}\n'
            '若提示签名冲突，请先卸载旧版本再安装');
      }
    } catch (e) {
      if (mounted) setState(() => _downloading = false);
      _toast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final accent = PearlColors.accent(isDark);
    final hasUpdate = _info?.hasUpdate == true;
    final keyMissing = !AppConstants.hasPgyerKey;

    Widget trailing;
    if (_downloading) {
      trailing = SizedBox(
        width: 108,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 3,
              color: accent,
              backgroundColor: PearlColors.bgTertiary(isDark),
            ),
            const SizedBox(height: 4),
            Text('下载中 ${(_progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 11, color: PearlColors.textSecondary(isDark))),
          ],
        ),
      );
    } else if (_checking) {
      trailing = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: accent),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasUpdate)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('可更新 v${_info!.latestVersion}',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: accent)),
            ),
          Text(_version.isEmpty ? '—' : 'v$_version',
              style: TextStyle(
                fontSize: 14,
                color: PearlColors.textSecondary(isDark),
              )),
          const SizedBox(width: 4),
          Icon(Icons.refresh_rounded,
              size: 16, color: PearlColors.textDisabled(isDark)),
        ],
      );
    }

    return InkWell(
      onTap: (_checking || _downloading)
          ? null
          : () {
              if (keyMissing) {
                _toast('未配置蒲公英 API Key，无法检查更新');
                return;
              }
              _check();
            },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(
              hasUpdate ? Icons.system_update_alt_rounded : Icons.info_outline,
              size: 20,
              color: accent,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text('Version',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: PearlColors.textPrimary(isDark),
                  )),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ============================================================
//  Shared bits
// ============================================================
class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionTitle(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: PearlColors.textPrimary(isDark),
          letterSpacing: -0.2,
        ));
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '${bytes}';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}';
}
