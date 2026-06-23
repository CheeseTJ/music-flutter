import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/theme/pearl_theme.dart';
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
    final hasSong = ref.watch(playerProvider.notifier).currentSong != null;
    final bottomPadding = 72.0 + 20.0 + MediaQuery.of(context).padding.bottom + (hasSong ? 68.0 + 8.0 : 0) + 24;
    final songsAsync = ref.watch(songListProvider);
    final showUploadButton = ref.watch(showUploadButtonProvider);

    final songs = songsAsync.valueOrNull ?? const [];
    final totalSongs = songs.length;
    final totalLyrics = songs.where((s) => s.hasLyric).length;
    final totalDuration = songs.fold<int>(0, (sum, s) => sum + s.duration);
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

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(songListProvider.notifier).load();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StorageHero(
              totalStorage: totalStorage,
              isDark: isDark,
            ),
            const SizedBox(height: 20),

            _StatsCard(
              totalSongs: totalSongs,
              totalLyrics: totalLyrics,
              totalDuration: totalDuration,
              isDark: isDark,
            ),
            const SizedBox(height: 28),

            _SettingsSection(
              isDark: isDark,
              showUploadButton: showUploadButton,
              onUploadButtonChanged: (v) async {
                await Settings.setShowUploadButton(v);
                ref.read(showUploadButtonProvider.notifier).state = v;
              },
            ),
            const SizedBox(height: 32),

            _AboutSection(isDark: isDark),
          ],
        ),
      ),
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
  final int totalDuration;
  final bool isDark;

  const _StatsCard({
    required this.totalSongs,
    required this.totalLyrics,
    required this.totalDuration,
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
          _Divider(isDark: isDark),
          Expanded(child: _StatCell(label: 'Duration',  value: _formatDuration(totalDuration), isDark: isDark)),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
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
//  Settings: toggle for the bottom upload button
// ============================================================
class _SettingsSection extends StatelessWidget {
  final bool isDark;
  final bool showUploadButton;
  final ValueChanged<bool> onUploadButtonChanged;
  const _SettingsSection({
    required this.isDark,
    required this.showUploadButton,
    required this.onUploadButtonChanged,
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
            ],
          ),
        ),
      ],
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
//  About (version)
// ============================================================
class _AboutSection extends StatelessWidget {
  final bool isDark;
  const _AboutSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('About', isDark: isDark),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: PearlColors.glassBgStrong(isDark),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20,
                  color: PearlColors.accent(isDark)),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Version',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500,
                      color: PearlColors.textPrimary(isDark),
                    )),
              ),
              Text('1.0.0',
                  style: TextStyle(
                    fontSize: 14,
                    color: PearlColors.textSecondary(isDark),
                  )),
            ],
          ),
        ),
      ],
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
