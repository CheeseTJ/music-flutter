import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/pearl_colors.dart';
import '../../../core/theme/pearl_theme.dart';
import '../../../core/crypto/kgm_decoder.dart';
import '../../../data/datasources/remote/api_client.dart';
import '../../collection/providers/song_list_provider.dart';
import '../../player/providers/player_provider.dart';

enum _ImportItemStatus { pending, decrypting, uploading, success, failed }

class _ImportQueueItem {
  final String fileName;
  final String filePath;
  final bool isKgm;
  _ImportItemStatus status = _ImportItemStatus.pending;
  String? error;
  double progress = 0;

  _ImportQueueItem({
    required this.fileName,
    required this.filePath,
    this.isKgm = false,
  });
}

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  final List<_ImportQueueItem> _queue = [];
  bool _importing = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      if (file.path == null) continue;
      _queue.add(_ImportQueueItem(
        fileName: file.name,
        filePath: file.path!,
        isKgm: KgmDecoder.isKgmFile(file.name),
      ));
    }
    setState(() {});
  }

  Future<void> _startImport() async {
    if (_importing) return;
    setState(() => _importing = true);

    final api = ref.read(apiClientProvider);
    final pending = _queue.where((i) => i.status == _ImportItemStatus.pending).toList();

    for (final item in pending) {
      try {
        String uploadPath = item.filePath;
        String uploadName = item.fileName;

        if (item.isKgm) {
          item.status = _ImportItemStatus.decrypting;
          setState(() {});
          final outName = KgmDecoder.stripKgmExtension(item.fileName);
          final outDir = '${Directory.systemTemp.path}/kgm_decoded';
          await Directory(outDir).create(recursive: true);
          final outPath = '$outDir/$outName';
          uploadPath = await KgmDecoder.decode(item.filePath, outputPath: outPath);
          uploadName = uploadPath.split(Platform.pathSeparator).last;
        }

        item.status = _ImportItemStatus.uploading;
        item.progress = 0.3;
        setState(() {});

        await api.uploadSong(uploadPath, uploadName);
        item.status = _ImportItemStatus.success;
        item.progress = 1.0;
        setState(() {});
      } catch (e) {
        item.status = _ImportItemStatus.failed;
        item.error = e.toString();
        setState(() {});
      }
    }

    await ref.read(songListProvider.notifier).load();
    setState(() => _importing = false);
  }

  void _removeItem(int index) {
    setState(() => _queue.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSong = ref.watch(playerProvider.notifier).currentSong != null;
    final bottomPadding = 72.0 + 20.0 + MediaQuery.of(context).padding.bottom + (hasSong ? 68.0 + 8.0 : 0) + 24;

    final hasPending = _queue.any((i) => i.status == _ImportItemStatus.pending);
    final hasItems = _queue.isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPadding),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: PearlColors.textPrimary(isDark),
                )),
            const SizedBox(height: 20),

            // Import from Web Card
            _ImportCard(
              icon: Icons.language_rounded,
              title: 'Import from Web',
              subtitle: 'Search Online Music',
              isDark: isDark,
              onTap: () {
                if (mounted) context.push('/import/search');
              },
            ),
            const SizedBox(height: 16),

            // Import Files Card
            _ImportCard(
              icon: Icons.cloud_upload_outlined,
              title: 'Import Files',
              subtitle: 'Upload Local Music',
              isDark: isDark,
              onTap: _pickFiles,
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
                      color: PearlColors.glassBg(isDark),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(fmt.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: PearlColors.textSecondary(isDark),
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
                        color: PearlColors.textPrimary(isDark),
                      )),
                  if (hasPending && !_importing)
                    GestureDetector(
                      onTap: _startImport,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7D8CFF), Color(0xFF9B8BFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Import All',
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
                        color: PearlColors.textDisabled(isDark)),
                    const SizedBox(height: 16),
                    Text('Select music files to import',
                        style: TextStyle(
                          fontSize: 15,
                          color: PearlColors.textSecondary(isDark),
                        )),
                  ],
                ),
              ),
            ],
            ],
          ),
    );
  }
}

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback onTap;

  const _ImportCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: PearlColors.glassBg(isDark),
          borderRadius: BorderRadius.circular(PearlTheme.radiusXl),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PearlColors.accent(isDark).withValues(alpha: 0.08),
                      PearlColors.accent(isDark).withValues(alpha: 0.02),
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
                  Icon(icon, color: PearlColors.accent(isDark), size: 36),
                  const SizedBox(height: 14),
                  Text(title,
                      style: TextStyle(
                        color: PearlColors.textPrimary(isDark),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
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
    );
  }
}

class _QueueItemTile extends StatelessWidget {
  final _ImportQueueItem item;
  final bool isDark;
  final VoidCallback onRemove;

  const _QueueItemTile({
    required this.item,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = PearlColors.textPrimary(isDark);
    final subColor = PearlColors.textSecondary(isDark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PearlColors.glassBg(isDark),
          borderRadius: BorderRadius.circular(PearlTheme.radiusMd),
        ),
        child: Row(
          children: [
            _StatusIcon(status: item.status, isDark: isDark),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(_statusText, style: TextStyle(color: _statusColor, fontSize: 11)),
                ],
              ),
            ),
            if (item.status == _ImportItemStatus.pending)
              IconButton(
                icon: Icon(Icons.close_rounded, size: 18, color: subColor),
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
          ],
        ),
      ),
    );
  }

  String get _statusText {
    switch (item.status) {
      case _ImportItemStatus.pending:
        return '待上传';
      case _ImportItemStatus.decrypting:
        return '解密中...';
      case _ImportItemStatus.uploading:
        return '上传中...';
      case _ImportItemStatus.success:
        return '已完成';
      case _ImportItemStatus.failed:
        return item.error ?? '上传失败';
    }
  }

  Color get _statusColor {
    switch (item.status) {
      case _ImportItemStatus.success:
        return const Color(0xFF44D3FF);
      case _ImportItemStatus.failed:
        return const Color(0xFFFF7A9E);
      case _ImportItemStatus.decrypting:
      case _ImportItemStatus.uploading:
        return PearlColors.accent(isDark);
      case _ImportItemStatus.pending:
        return PearlColors.textDisabled(isDark);
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final _ImportItemStatus status;
  final bool isDark;

  const _StatusIcon({required this.status, required this.isDark});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case _ImportItemStatus.pending:
        icon = Icons.hourglass_empty_rounded;
        color = PearlColors.textDisabled(isDark);
        break;
      case _ImportItemStatus.decrypting:
        icon = Icons.lock_open_rounded;
        color = PearlColors.accent(isDark);
        break;
      case _ImportItemStatus.uploading:
        icon = Icons.cloud_upload_outlined;
        color = PearlColors.accent(isDark);
        break;
      case _ImportItemStatus.success:
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF44D3FF);
        break;
      case _ImportItemStatus.failed:
        icon = Icons.error_outline_rounded;
        color = const Color(0xFFFF7A9E);
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
