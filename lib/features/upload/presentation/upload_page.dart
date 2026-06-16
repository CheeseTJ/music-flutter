import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/crypto/kgm_decoder.dart';
import '../../../data/datasources/remote/api_client.dart';
import '../../home/providers/song_list_provider.dart';

enum _UploadItemStatus { pending, decrypting, uploading, success, failed }

class _UploadQueueItem {
  final String fileName;
  final String filePath;
  final bool isKgm;
  _UploadItemStatus status;
  String? error;
  double progress;

  _UploadQueueItem({
    required this.fileName,
    required this.filePath,
    this.isKgm = false,
    this.status = _UploadItemStatus.pending,
    this.error,
    this.progress = 0,
  });
}

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends ConsumerState<UploadPage> {
  final List<_UploadQueueItem> _queue = [];
  bool _uploading = false;

  Future<void> _pickSongs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      if (file.path == null) continue;
      _queue.add(_UploadQueueItem(
        fileName: file.name,
        filePath: file.path!,
        isKgm: KgmDecoder.isKgmFile(file.name),
      ));
    }
    setState(() {});
  }

  Future<void> _startUpload() async {
    if (_uploading) return;
    setState(() => _uploading = true);

    final api = ref.read(apiClientProvider);
    final pending = _queue.where((i) => i.status == _UploadItemStatus.pending).toList();

    for (final item in pending) {
      try {
        String uploadPath = item.filePath;
        String uploadName = item.fileName;

        if (item.isKgm) {
          item.status = _UploadItemStatus.decrypting;
          setState(() {});
          final outName = KgmDecoder.stripKgmExtension(item.fileName);
          final outDir = '${Directory.systemTemp.path}/kgm_decoded';
          await Directory(outDir).create(recursive: true);
          final outPath = '$outDir/$outName';
          uploadPath = await KgmDecoder.decode(item.filePath, outputPath: outPath);
          uploadName = outName;
        }

        item.status = _UploadItemStatus.uploading;
        item.progress = 0.3;
        setState(() {});

        await api.uploadSong(uploadPath, uploadName);
        item.status = _UploadItemStatus.success;
        item.progress = 1.0;
        setState(() {});
      } catch (e) {
        item.status = _UploadItemStatus.failed;
        item.error = e.toString();
        setState(() {});
      }
    }

    await ref.read(songListProvider.notifier).load();
    setState(() => _uploading = false);
  }

  void _removeItem(int index) {
    setState(() => _queue.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;

    final hasPending = _queue.any((i) => i.status == _UploadItemStatus.pending);
    final hasItems = _queue.isNotEmpty;

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Upload',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary,
                )),
            const SizedBox(height: 20),

            // Online Import Card
            _ImportCard(
              icon: Icons.language_rounded,
              title: 'Online Import',
              subtitle: 'Search Online Music',
              gradientColors: isDark
                  ? const [AuroraColors.gradientStart, AuroraColors.gradientEnd]
                  : const [HarmoniqColors.blue, HarmoniqColors.emphasize],
              onTap: () {
                if (mounted) context.push('/search');
              },
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Local Import Card
            _ImportCard(
              icon: Icons.cloud_upload_outlined,
              title: 'Local Import',
              subtitle: 'Upload Local Music',
              gradientColors: isDark
                  ? const [AuroraColors.gradientMid, AuroraColors.gradientEnd]
                  : const [HarmoniqColors.mint, HarmoniqColors.blue],
              onTap: _pickSongs,
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            // Supported formats
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8, bottom: 16),
              child: Wrap(
                spacing: 8,
                children: ['mp3', 'wav', 'flac', 'aac', 'm4a'].map((fmt) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? AuroraColors.bgSecondary : HarmoniqColors.aux,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(fmt.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary,
                        )),
                  );
                }).toList(),
              ),
            ),

            if (hasItems) ...[
              // Queue Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Queue',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary,
                      )),
                  if (hasPending && !_uploading)
                    GestureDetector(
                      onTap: _startUpload,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: isDark
                              ? const LinearGradient(colors: AuroraColors.gradient)
                              : const LinearGradient(colors: [HarmoniqColors.blue, HarmoniqColors.emphasize]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Upload All',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Queue Items
              ..._queue.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return _QueueItemTile(
                  item: item,
                  isDark: isDark,
                  onRemove: () => _removeItem(i),
                );
              }),
            ],

            if (!hasItems) ...[
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload_outlined, size: 64,
                        color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
                    const SizedBox(height: 16),
                    Text('Select music files to upload',
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary,
                        )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;
  final bool isDark;

  const _ImportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark
              ? [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 10))]
              : [
                  BoxShadow(color: const Color(0x14283246), blurRadius: 30, offset: const Offset(0, 10)),
                  BoxShadow(color: const Color(0x0C283246), blurRadius: 12, offset: const Offset(0, 4)),
                ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                )),
          ],
        ),
      ),
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  final _UploadQueueItem item;
  final bool isDark;
  final VoidCallback onRemove;

  const _QueueItemTile({
    required this.item,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final progressColor = isDark ? AuroraColors.gradientStart : HarmoniqColors.blue;
    final textColor = isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary;
    final subColor = isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AuroraColors.bgSecondary : HarmoniqColors.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(color: const Color(0x0C283246), blurRadius: 12, offset: const Offset(0, 4)),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.audiotrack_rounded, size: 18, color: subColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
                ),
                if (item.status == _UploadItemStatus.pending)
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: subColor),
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: item.progress > 0 ? item.progress : null,
                minHeight: 4,
                backgroundColor: isDark ? AuroraColors.surface : HarmoniqColors.aux,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_statusText, style: TextStyle(color: _statusColor, fontSize: 12)),
                if (item.status == _UploadItemStatus.uploading)
                  GestureDetector(
                    onTap: onRemove,
                    child: Text('Pause',
                        style: TextStyle(color: subColor, fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _statusText {
    switch (item.status) {
      case _UploadItemStatus.pending:
        return 'Pending';
      case _UploadItemStatus.decrypting:
        return 'Decrypting...';
      case _UploadItemStatus.uploading:
        return 'Uploading...';
      case _UploadItemStatus.success:
        return 'Completed';
      case _UploadItemStatus.failed:
        return 'Failed: ${item.error ?? "Unknown error"}';
    }
  }

  Color get _statusColor {
    switch (item.status) {
      case _UploadItemStatus.success:
        return const Color(0xFF44D3FF);
      case _UploadItemStatus.failed:
        return const Color(0xFFFF7A9E);
      case _UploadItemStatus.decrypting:
      case _UploadItemStatus.uploading:
        return const Color(0xFF3399FF);
      case _UploadItemStatus.pending:
        return AuroraColors.textDisabled;
    }
  }
}
