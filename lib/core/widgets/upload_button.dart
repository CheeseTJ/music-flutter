import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/pearl_colors.dart';
import '../theme/pearl_theme.dart';
import '../../core/crypto/kgm_decoder.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../features/collection/providers/song_list_provider.dart';

/// 上传按钮：底栏的"快速上传"圆形按钮，点击后直接调起文件选择器，
/// 选完文件立即走和原 Import 页相同的解密+上传流程。
///
/// 是否显示由 [Settings.showUploadButton] 控制；该值变更时，调用方需
/// 自行重建（一般在 ShellPage 用一个 FutureBuilder / ValueNotifier 监听）。
class UploadButton extends ConsumerWidget {
  final bool isDark;
  const UploadButton({super.key, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = PearlColors.accent(isDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handlePick(context, ref, accent),
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent, const Color(0xFF9B8BFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(
            Icons.cloud_upload_rounded,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }

  Future<void> _handlePick(BuildContext context, WidgetRef ref, Color accent) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;
    if (!context.mounted) return;

    final scaffold = ScaffoldMessenger.of(context);
    final api = ref.read(apiClientProvider);
    final songListCtrl = ref.read(songListProvider.notifier);

    var success = 0;
    var failed = 0;

    for (final file in result.files) {
      if (file.path == null) continue;
      try {
        String uploadPath = file.path!;
        String uploadName = file.name;

        if (KgmDecoder.isKgmFile(file.name)) {
          final outName = KgmDecoder.stripKgmExtension(file.name);
          final outDir = '${Directory.systemTemp.path}/kgm_decoded';
          await Directory(outDir).create(recursive: true);
          final outPath = '$outDir/$outName';
          uploadPath = await KgmDecoder.decode(file.path!, outputPath: outPath);
          uploadName = uploadPath.split(Platform.pathSeparator).last;
        }

        await api.uploadSong(uploadPath, uploadName);
        success++;
      } catch (_) {
        failed++;
      }
    }

    await songListCtrl.load();

    if (success > 0) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Imported $success file${success == 1 ? '' : 's'}${failed > 0 ? ' ($failed failed)' : ''}'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } else if (failed > 0) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Import failed for $failed file${failed == 1 ? '' : 's'}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }
}

/// 与原 Import 页同款的卡片样式，留在本文件以备扩展（例如以后想要
/// "上传到云"等高级选项，可以挂在底栏按钮的长按菜单里）。
class ImportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;
  const ImportCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = PearlColors.accent(isDark);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
        child: Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: PearlColors.bgTertiary(isDark),
            borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.08),
                        accent.withValues(alpha: 0.02),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: accent, size: 36),
                    const SizedBox(height: 14),
                    Text(title,
                        style: TextStyle(
                          color: PearlColors.textPrimary(isDark),
                          fontSize: 20, fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        )),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                          color: PearlColors.textSecondary(isDark),
                          fontSize: 14,
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
