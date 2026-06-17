import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/theme/pearl_theme.dart';
import '../../collection/providers/song_list_provider.dart';
import '../../player/providers/player_provider.dart';

class VaultPage extends ConsumerWidget {
  const VaultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSong = ref.watch(playerProvider.notifier).currentSong != null;
    final bottomPadding = 72.0 + 20.0 + MediaQuery.of(context).padding.bottom + (hasSong ? 68.0 + 8.0 : 0) + 24;
    final songsAsync = ref.watch(songListProvider);
    final totalSongs = songsAsync is AsyncData ? (songsAsync.value?.length ?? 0) : 0;
    final totalLyrics = songsAsync is AsyncData
        ? (songsAsync.value?.where((s) => s.hasLyric).length ?? 0)
        : 0;
    final totalStorage = songsAsync is AsyncData
        ? (songsAsync.value?.fold<int>(0, (sum, s) => sum + s.size) ?? 0)
        : 0;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Huge storage number + subtitle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatSize(totalStorage),
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: PearlColors.textPrimary(isDark),
                      letterSpacing: -2,
                      height: 1,
                    )),
                const SizedBox(height: 4),
                Text('Synced · Just Now',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: PearlColors.textSecondary(isDark),
                    )),
              ],
            ),
            const SizedBox(height: 28),

            // Stats card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: PearlColors.glassBgStrong(isDark),
                borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      label: 'Songs',
                      value: '$totalSongs',
                      isDark: isDark,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 48,
                    color: PearlColors.bgTertiary(isDark),
                  ),
                  Expanded(
                    child: _StatItem(
                      label: 'Lyrics',
                      value: '$totalLyrics',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text('About',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: PearlColors.textPrimary(isDark),
                )),
            const SizedBox(height: 12),
            _AboutTile(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle: '1.0.0',
              isDark: isDark,
            ),
          ],
        ),
    );
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _StatItem({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: PearlColors.textPrimary(isDark),
              letterSpacing: -1,
            )),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: PearlColors.textSecondary(isDark),
            )),
      ],
    );
  }
}

class _AboutTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  const _AboutTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: PearlColors.glassBgStrong(isDark),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, size: 22, color: PearlColors.accent(isDark)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: PearlColors.textPrimary(isDark),
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: PearlColors.textSecondary(isDark),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
