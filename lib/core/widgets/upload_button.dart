import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/pearl_colors.dart';
import '../../core/crypto/kgm.dart';
import '../../data/datasources/remote/api_client.dart';
import '../../features/collection/providers/song_list_provider.dart';

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

        if (KgmProcessor.isAcceptedFile(file.name)) {
          final outName = KgmProcessor.stripExtension(file.name);
          final outDir = '${Directory.systemTemp.path}/processed';
          await Directory(outDir).create(recursive: true);
          final outPath = '$outDir/$outName';
          uploadPath = await KgmProcessor.process(file.path!, outputPath: outPath);
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
