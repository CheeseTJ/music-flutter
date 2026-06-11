import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _SectionHeader(title: '存储'),
          _Tile(
            icon: Icons.cloud_outlined,
            title: '云端存储',
            subtitle: 'Cloudflare R2',
            trailing: '免费额度',
          ),
          _Tile(
            icon: Icons.storage_outlined,
            title: '本地缓存',
            subtitle: '歌曲列表 · 播放记录',
            trailing: '0 KB',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: '关于'),
          _Tile(
            icon: Icons.info_outline,
            title: '版本',
            subtitle: 'Music App',
            trailing: '1.0.0',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.muted, letterSpacing: 1)),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.accent),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.text)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        trailing: Text(trailing, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
