import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../home/providers/song_list_provider.dart';

class MePage extends ConsumerWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider).isDark;
    final songsAsync = ref.watch(songListProvider);
    final totalSongs = songsAsync is AsyncData ? (songsAsync.value?.length ?? 0) : 0;
    final totalLyrics = songsAsync is AsyncData
        ? (songsAsync.value?.where((s) => s.hasLyric).length ?? 0)
        : 0;
    final totalStorage = songsAsync is AsyncData
        ? (songsAsync.value?.fold<int>(0, (sum, s) => sum + s.size) ?? 0)
        : 0;

    final text = isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary;
    final sub = isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary;
    final bg = isDark ? AuroraColors.bgSecondary : HarmoniqColors.card;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cloud Library',
                style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.w700,
                  letterSpacing: -0.5, color: text,
                )),
            const SizedBox(height: 28),

            _SectionTitle(title: 'Local Storage', isDark: isDark),
            const SizedBox(height: 14),

            // Main stat card with gradient icon circle + big number
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: isDark
                    ? null
                    : [BoxShadow(color: const Color(0x0C283246), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Column(
                children: [
                  // Icon circle
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(colors: AuroraColors.gradient)
                          : const LinearGradient(colors: [HarmoniqColors.blue, HarmoniqColors.emphasize]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.headphones_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text('$totalSongs',
                      style: TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w800,
                        color: text, letterSpacing: -1, height: 1,
                      )),
                  const SizedBox(height: 4),
                  Text('Songs',
                      style: TextStyle(fontSize: 15, color: sub, letterSpacing: 0.5)),

                  const SizedBox(height: 24),
                  // Divider
                  Container(height: 1, color: isDark ? AuroraColors.surface : HarmoniqColors.aux),
                  const SizedBox(height: 20),

                  // Two-row sub stats with icons
                  Row(
                    children: [
                      Expanded(
                        child: _SubStat(
                          icon: Icons.lyrics_outlined,
                          label: 'Lyrics',
                          value: '$totalLyrics',
                          isDark: isDark,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: isDark ? AuroraColors.surface : HarmoniqColors.aux,
                      ),
                      Expanded(
                        child: _SubStat(
                          icon: Icons.folder_outlined,
                          label: 'Cache',
                          value: _formatSize(totalStorage),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _SectionTitle(title: 'Settings', isDark: isDark),
            const SizedBox(height: 12),
            _SettingsTile(
              icon: Icons.palette_outlined,
              title: 'Theme',
              subtitle: isDark ? 'Aurora (Dark)' : 'Harmoniq (Light)',
              onTap: () => ref.read(themeProvider).toggle(),
              isDark: isDark,
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'Version',
              subtitle: '1.0.0',
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _SubStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;
  const _SubStat({required this.icon, required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final text = isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary;
    final sub = isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary;
    return Column(
      children: [
        Icon(icon, size: 20, color: sub),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700,
              color: text, height: 1,
            )),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: sub)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final bool isDark;
  const _SectionTitle({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final text = isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary;
    return Text(title,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: text));
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDark;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final text = isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary;
    final sub = isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary;
    final bg = isDark ? AuroraColors.bgSecondary : HarmoniqColors.card;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, size: 22,
                    color: isDark ? AuroraColors.gradientStart : HarmoniqColors.blue),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: text)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(fontSize: 13, color: sub)),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded, size: 20,
                      color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
