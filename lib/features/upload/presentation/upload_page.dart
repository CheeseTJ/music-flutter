import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/crypto/kgm_decoder.dart';
import '../../../core/crypto/krc_decoder.dart';
import '../../../data/datasources/remote/api_client.dart';
import '../../../data/models/song.dart';
import '../../home/providers/song_list_provider.dart';

class UploadPage extends ConsumerStatefulWidget {
  const UploadPage({super.key});

  @override
  ConsumerState<UploadPage> createState() => _UploadPageState();
}

enum UploadMode { song, lyric, cover }
enum ItemStatus { pending, decrypting, uploading, success, failed, skipped, noMatch, needDecision, hasLyric }

class _UploadItem {
  final String fileName;
  final String filePath;
  final bool isKgm;
  final bool isKrc;
  ItemStatus status;
  String? error;
  String? lrcText;
  Song? matchedSong;
  List<Song>? candidates;
  bool userApproved;

  _UploadItem({
    required this.fileName,
    required this.filePath,
    this.isKgm = false,
    this.isKrc = false,
    this.status = ItemStatus.pending,
    this.error,
    this.lrcText,
    this.matchedSong,
    this.candidates,
    this.userApproved = false,
  });

  String get displayName => fileName;

  IconData get statusIcon {
    switch (status) {
      case ItemStatus.pending:
        return Icons.hourglass_empty_rounded;
      case ItemStatus.decrypting:
        return Icons.lock_open_rounded;
      case ItemStatus.uploading:
        return Icons.cloud_upload_rounded;
      case ItemStatus.success:
        return Icons.check_circle_rounded;
      case ItemStatus.failed:
        return Icons.error_rounded;
      case ItemStatus.skipped:
        return Icons.skip_next_rounded;
      case ItemStatus.noMatch:
        return Icons.link_off_rounded;
      case ItemStatus.needDecision:
        return Icons.quiz_rounded;
      case ItemStatus.hasLyric:
        return Icons.check_rounded;
    }
  }

  Color get statusColor {
    switch (status) {
      case ItemStatus.success:
        return AppColors.accent;
      case ItemStatus.failed:
      case ItemStatus.noMatch:
        return AppColors.error;
      case ItemStatus.skipped:
        return AppColors.muted;
      case ItemStatus.needDecision:
      case ItemStatus.hasLyric:
        return const Color(0xFFF0A050);
      case ItemStatus.decrypting:
      case ItemStatus.uploading:
        return const Color(0xFF3399FF);
      case ItemStatus.pending:
        return AppColors.subtle;
    }
  }

  String get statusText {
    switch (status) {
      case ItemStatus.pending:
        return '等待中';
      case ItemStatus.decrypting:
        return '解密中';
      case ItemStatus.uploading:
        return '上传中';
      case ItemStatus.success:
        return '成功';
      case ItemStatus.failed:
        return '失败';
      case ItemStatus.skipped:
        return '跳过';
      case ItemStatus.noMatch:
        return '未匹配到歌曲';
      case ItemStatus.needDecision:
        return '待确认';
      case ItemStatus.hasLyric:
        return '已有歌词';
    }
  }
}

class _UploadPageState extends ConsumerState<UploadPage> {
  UploadMode _mode = UploadMode.song;
  final List<_UploadItem> _items = [];
  bool _processing = false;
  bool _allDone = false;
  bool _hideHasLyric = true;
  bool _hideNoMatch = true;
  String _matchDirectionLabel = '歌词 → 歌曲';
  List<Song> _existingSongs = [];

  void _loadExistingSongs() {
    final songsState = ref.read(songListProvider);
    if (songsState is AsyncData) {
      _existingSongs = List<Song>.from(songsState.value ?? []);
    }
  }

  Future<void> _pickAndUploadSongs() async {
    setState(() {
      _processing = true;
      _allDone = false;
      _matchDirectionLabel = '歌曲 → 歌词';
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) { _reset(); return; }

    _items.clear();
    for (final file in result.files) {
      if (file.path == null) continue;
      _items.add(_UploadItem(
        fileName: file.name,
        filePath: file.path!,
        isKgm: KgmDecoder.isKgmFile(file.name),
      ));
    }

    if (mounted) setState(() {});

    await _processSongItems();
    if (mounted) setState(() {});
    await ref.read(songListProvider.notifier).load();
    if (!mounted) return;
    setState(() => _allDone = true);
    _loadExistingSongs();
  }

  Future<void> _pickAndUploadCovers() async {
    _loadExistingSongs();

    setState(() {
      _processing = true;
      _allDone = false;
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) { _reset(); return; }

    _items.clear();
    for (final file in result.files) {
      if (file.path == null) continue;
      final item = _UploadItem(fileName: file.name, filePath: file.path!);
      final songId = _matchSongByFileName(file.name);
      if (songId != null) {
        item.matchedSong = _existingSongs.firstWhere((s) => s.id == songId);
      }
      _items.add(item);
    }

    if (mounted) setState(() {});

    await _processCoverItems();
    if (mounted) setState(() {});
    await ref.read(songListProvider.notifier).load();
    if (!mounted) return;
    setState(() => _allDone = true);
    _loadExistingSongs();
  }

  void _findLyricConflicts() {
    final seenSongIds = <int>{};
    for (final item in _items) {
      if (item.status != ItemStatus.pending && item.status != ItemStatus.needDecision) continue;

      if (item.status == ItemStatus.needDecision && item.candidates != null) {
        item.userApproved = false;
        continue;
      }

      final parsed = _parseKrcFileName(item.fileName);
      final isExact = parsed != null;
      final krcArtist = parsed?.artist.toLowerCase() ?? '';
      final krcTitle = parsed?.title.toLowerCase() ?? '';

      if (!isExact) {
        item.status = ItemStatus.noMatch;
        item.userApproved = false;
        continue;
      }

      Song? exactSong;
      for (final song in _existingSongs) {
        if (song.hasLyric) continue;
        if (song.title.toLowerCase() == krcTitle &&
            song.artist.toLowerCase() == krcArtist) {
          exactSong = song;
          break;
        }
      }

      if (exactSong != null) {
        if (seenSongIds.contains(exactSong.id)) {
          item.status = ItemStatus.noMatch;
          item.userApproved = false;
          continue;
        }
        item.matchedSong = exactSong;
        item.status = ItemStatus.pending;
        item.userApproved = true;
        seenSongIds.add(exactSong.id);
        continue;
      }

      final matches = _findMatchingSongs(item.fileName);
      if (matches.isEmpty) {
        item.status = ItemStatus.noMatch;
        item.userApproved = false;
      } else if (matches.length == 1) {
        final song = matches.first;
        if (seenSongIds.contains(song.id)) {
          item.status = ItemStatus.noMatch;
          item.userApproved = false;
          continue;
        }
        item.matchedSong = song;
        item.candidates = matches;
        item.status = ItemStatus.pending;
        item.userApproved = false;
        seenSongIds.add(song.id);
      } else {
        if (matches.any((s) => seenSongIds.contains(s.id))) {
          item.status = ItemStatus.noMatch;
          item.userApproved = false;
          continue;
        }
        item.candidates = matches;
        item.status = ItemStatus.needDecision;
        item.userApproved = false;
      }
    }
  }

  ({String artist, String title})? _parseKrcFileName(String fileName) {
    var name = fileName;
    final extIdx = name.toLowerCase().lastIndexOf('.krc');
    if (extIdx >= 0) name = name.substring(0, extIdx);

    if (name.toLowerCase().startsWith('lyrics')) {
      name = name.substring(6);
    }

    final lastDash = name.lastIndexOf('-');
    if (lastDash < 1) return null;
    final hashPart = name.substring(lastDash + 1).trim();
    if (hashPart.length == 32 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(hashPart)) {
      name = name.substring(0, lastDash).trim();
    }

    final sepIdx = name.indexOf(' - ');
    if (sepIdx < 1) return null;
    final artist = name.substring(0, sepIdx).trim();
    final title = name.substring(sepIdx + 3).trim();
    if (artist.isEmpty || title.isEmpty) return null;
    return (artist: artist, title: title);
  }

  List<Song> _findMatchingSongs(String krcFileName, {int maxResults = 8}) {
    final parsed = _parseKrcFileName(krcFileName);
    if (parsed == null) return [];
    final krcArtist = parsed.artist.toLowerCase();
    final krcTitle = parsed.title.toLowerCase();

    final scored = <({Song song, double score})>[];
    for (final song in _existingSongs) {
      if (song.hasLyric) continue;
      final sa = song.artist.toLowerCase();
      final st = song.title.toLowerCase();
      if (st == krcTitle && sa == krcArtist) {
        scored.add((song: song, score: 1.0));
      } else {
        final score = _songSimilarity(krcArtist, krcTitle, sa, st);
        if (score >= 0.25) scored.add((song: song, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(maxResults).map((s) => s.song).toList();
  }

  double _songSimilarity(String krcArtist, String krcTitle, String sa, String st) {
    double artistScore = 0;
    if (sa == krcArtist) {
      artistScore = 1.0;
    } else if (sa.contains(krcArtist) || krcArtist.contains(sa)) {
      artistScore = 0.6;
    } else {
      artistScore = _tokenOverlap(krcArtist, sa);
    }

    double titleScore = 0;
    if (st == krcTitle) {
      titleScore = 1.0;
    } else if (st.contains(krcTitle) || krcTitle.contains(st)) {
      titleScore = 0.6;
    } else {
      titleScore = _tokenOverlap(krcTitle, st);
    }

    return artistScore * 0.3 + titleScore * 0.7;
  }

  double _tokenOverlap(String a, String b) {
    final tokensA = <String>{};
    final tokensB = <String>{};
    for (final c in a.runes) {
      final ch = String.fromCharCode(c);
      if (ch.trim().isNotEmpty) tokensA.add(ch);
    }
    for (final c in b.runes) {
      final ch = String.fromCharCode(c);
      if (ch.trim().isNotEmpty) tokensB.add(ch);
    }
    if (tokensA.isEmpty || tokensB.isEmpty) return 0;
    final common = tokensA.intersection(tokensB).length;
    final shorter = tokensA.length < tokensB.length ? tokensA.length : tokensB.length;
    return common / shorter;
  }

  int? _matchSongByFileName(String fileName) {
    final parsed = _parseKrcFileName(fileName);
    if (parsed == null) return null;
    final krcTitle = parsed.title.toLowerCase();

    for (final song in _existingSongs) {
      if (song.title.toLowerCase() == krcTitle) return song.id;
    }
    return null;
  }

  Future<void> _showLyricConflictDrawer() async {
    final reviewItems = _items.where((i) =>
        i.userApproved != true &&
        (i.status == ItemStatus.pending ||
         i.status == ItemStatus.needDecision)).toList();
    if (reviewItems.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final initSize = ((reviewItems.length.clamp(1, 8) * 0.06) + 0.3).clamp(0.0, 0.85);
          return DraggableScrollableSheet(
            initialChildSize: initSize,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            expand: false,
            builder: (ctx, scrollCtrl) => Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: AppColors.subtle, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 16),
                  const Text('确认歌词匹配',
                      style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('勾选后将上传，未勾选的将跳过：',
                      style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      children: reviewItems.map((item) {
                        final matchName = item.matchedSong != null
                            ? '${item.matchedSong!.title} - ${item.matchedSong!.artist}'
                            : null;
                        String reason;
                        if (item.status == ItemStatus.needDecision) {
                          reason = '匹配到 ${item.candidates?.length ?? 0} 首候选歌曲';
                        } else {
                          reason = matchName != null ? '匹配到: $matchName' : '待确认';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: AppColors.elevated,
                            borderRadius: BorderRadius.circular(10),
                            child: Column(
                            children: [
                              CheckboxListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                title: Text(item.fileName,
                                    style: const TextStyle(color: AppColors.text, fontSize: 13)),
                                subtitle: Text(reason,
                                    style: TextStyle(color: item.statusColor, fontSize: 11)),
                                value: item.userApproved,
                                activeColor: AppColors.accent,
                                onChanged: (v) {
                                  setSheetState(() => item.userApproved = v ?? false);
                                },
                              ),
                              if (item.status == ItemStatus.needDecision && item.userApproved && item.candidates != null)
                                Padding(
                                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    children: item.candidates!.map((song) => ChoiceChip(
                                      label: Text('${song.title} - ${song.artist}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: item.matchedSong?.id == song.id
                                                ? AppColors.deep
                                                : AppColors.text,
                                          )),
                                      selected: item.matchedSong?.id == song.id,
                                      selectedColor: AppColors.accent,
                                      backgroundColor: AppColors.elevated,
                                      onSelected: (sel) {
                                        setSheetState(() => item.matchedSong = song);
                                      },
                                    )).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.deep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('确认并上传', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    for (final item in reviewItems) {
      if (!item.userApproved) {
        item.status = ItemStatus.skipped;
      } else if (item.status == ItemStatus.needDecision) {
        item.status = ItemStatus.pending;
      }
    }

    final hasApproved = _items.any((i) => i.status == ItemStatus.pending);
    if (!hasApproved) {
      _reset();
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _pickAndUploadLyrics() async {
    _loadExistingSongs();

    if (_existingSongs.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先上传歌曲，再上传歌词')),
      );
      return;
    }

    setState(() {
      _processing = true;
      _allDone = false;
      _matchDirectionLabel = '歌词 → 歌曲';
    });
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) { _reset(); return; }

    final krcFiles = result.files.where((f) =>
        f.path != null && f.name.toLowerCase().endsWith('.krc')).toList();
    if (krcFiles.isEmpty) {
      if (!mounted) { _reset(); return; }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未选择 KRC 格式的歌词文件')),
      );
      return;
    }

    _items.clear();
    for (final file in krcFiles) {
      _items.add(_UploadItem(
        fileName: file.name,
        filePath: file.path!,
        isKrc: true,
      ));
    }

    if (mounted) setState(() {});

    await _decryptAllLyrics();
    _findLyricConflicts();
    if (mounted) setState(() {});

    if (_items.any((i) =>
        i.status == ItemStatus.pending ||
        i.status == ItemStatus.needDecision)) {
      await _showLyricConflictDrawer();
    }

    final approved = _items.where((i) => i.status == ItemStatus.pending && i.isKrc).toList();
    for (final item in approved) {
      if (item.matchedSong == null) {
        item.status = ItemStatus.skipped;
        continue;
      }
      item.status = ItemStatus.uploading;
      if (mounted) setState(() {});
      try {
        final api = ref.read(apiClientProvider);
        await _uploadWithRetry(() => api.uploadLyric(item.matchedSong!.id, item.lrcText!));
        item.status = ItemStatus.success;
      } catch (e) {
        item.status = ItemStatus.failed;
        item.error = e.toString();
      }
      if (mounted) setState(() {});
    }

    await ref.read(songListProvider.notifier).load();
    if (!mounted) return;
    setState(() => _allDone = true);
    _loadExistingSongs();
  }

  Future<void> _decryptAllLyrics() async {
    for (final item in _items) {
      item.status = ItemStatus.decrypting;
      if (mounted) setState(() {});
      try {
        item.lrcText = await KrcDecoder.decodeToString(item.filePath);
        item.status = ItemStatus.pending;
      } catch (e) {
        item.status = ItemStatus.failed;
        item.error = e.toString();
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _processSongItems() async {
    final api = ref.read(apiClientProvider);
    final pending = _items.where((i) => i.status == ItemStatus.pending).toList();

    for (var idx = 0; idx < pending.length; idx++) {
      final item = pending[idx];

      if (idx > 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      try {
        String uploadPath = item.filePath;
        String uploadName = item.fileName;

        if (item.isKgm) {
          item.status = ItemStatus.decrypting;
          if (mounted) setState(() {});
          final outName = KgmDecoder.stripKgmExtension(item.fileName);
          final outDir = '${Directory.systemTemp.path}/kgm_decoded';
          await Directory(outDir).create(recursive: true);
          final outPath = '$outDir/$outName';
          uploadPath = await KgmDecoder.decode(item.filePath, outputPath: outPath);
          uploadName = uploadPath.split('/').last.split('\\').last;
        }

        item.status = ItemStatus.uploading;
        if (mounted) setState(() {});
        await _uploadWithRetry(() => api.uploadSong(uploadPath, uploadName));
        item.status = ItemStatus.success;
      } catch (e) {
        item.status = ItemStatus.failed;
        item.error = e.toString();
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _processCoverItems() async {
    final api = ref.read(apiClientProvider);
    final pending = _items.toList();

    for (var idx = 0; idx < pending.length; idx++) {
      final item = pending[idx];

      if (idx > 0) {
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (item.matchedSong == null) {
        item.status = ItemStatus.noMatch;
        if (mounted) setState(() {});
        continue;
      }

      try {
        item.status = ItemStatus.uploading;
        if (mounted) setState(() {});
        await _uploadWithRetry(() => api.uploadCover(item.matchedSong!.id, item.filePath));
        item.status = ItemStatus.success;
      } catch (e) {
        item.status = ItemStatus.failed;
        item.error = e.toString();
      }
      if (mounted) setState(() {});
    }
  }

  Future<T> _uploadWithRetry<T>(Future<T> Function() fn) async {
    Exception? lastError;
    var serverError = false;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await fn();
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        final errStr = e.toString();
        final is5xx = errStr.contains('Status: 5') || errStr.contains('Status: 500') || errStr.contains('Status: 502') || errStr.contains('Status: 503');
        if (is5xx) {
          serverError = true;
          break;
        }
        if (attempt < 2) {
          await Future.delayed(Duration(milliseconds: (attempt + 1) * 500));
        }
      }
    }
    if (serverError) {
      await Future.delayed(const Duration(seconds: 3));
    }
    throw lastError!;
  }

  Future<void> _retryAllFailed() async {
    final failedItems = _items.where((i) => i.status == ItemStatus.failed).toList();
    for (final item in failedItems) {
      await _retryItem(item);
    }
  }

  Future<void> _retryItem(_UploadItem item) async {
    item.status = ItemStatus.pending;
    item.error = null;
    if (mounted) setState(() {});

    if (_mode == UploadMode.song) {
      final api = ref.read(apiClientProvider);
      try {
        String uploadPath = item.filePath;
        String uploadName = item.fileName;

        if (item.isKgm) {
          item.status = ItemStatus.decrypting;
          if (mounted) setState(() {});
          final outName = KgmDecoder.stripKgmExtension(item.fileName);
          final outDir = '${Directory.systemTemp.path}/kgm_decoded';
          await Directory(outDir).create(recursive: true);
          final outPath = '$outDir/$outName';
          uploadPath = await KgmDecoder.decode(item.filePath, outputPath: outPath);
          uploadName = uploadPath.split('/').last.split('\\').last;
        }

        item.status = ItemStatus.uploading;
        if (mounted) setState(() {});
        await api.uploadSong(uploadPath, uploadName);
        item.status = ItemStatus.success;
      } catch (e) {
        item.status = ItemStatus.failed;
        item.error = e.toString();
      }
    } else if (_mode == UploadMode.lyric) {
      final api = ref.read(apiClientProvider);

      if (item.lrcText == null) {
        try {
          item.lrcText ??= await KrcDecoder.decodeToString(item.filePath);
        } catch (e) {
          item.status = ItemStatus.failed;
          item.error = e.toString();
          if (mounted) setState(() {});
          return;
        }
      }

      if (item.matchedSong == null) {
        final matches = _findMatchingSongs(item.fileName);
        if (matches.isEmpty) {
          item.status = ItemStatus.noMatch;
          return;
        } else if (matches.length == 1) {
          item.matchedSong = matches.first;
        } else {
          item.candidates = matches;
          item.status = ItemStatus.needDecision;
          if (mounted) setState(() {});
          await _showLyricConflictDrawer();
          if (item.status != ItemStatus.pending || item.matchedSong == null) return;
        }
      }

      try {
        item.status = ItemStatus.uploading;
        if (mounted) setState(() {});
        await api.uploadLyric(item.matchedSong!.id, item.lrcText!);
        item.status = ItemStatus.success;
      } catch (e) {
        item.status = ItemStatus.failed;
        item.error = e.toString();
      }
    } else {
      final api = ref.read(apiClientProvider);
      if (item.matchedSong == null) {
        item.status = ItemStatus.noMatch;
      } else {
        try {
          item.status = ItemStatus.uploading;
          if (mounted) setState(() {});
          await api.uploadCover(item.matchedSong!.id, item.filePath);
          item.status = ItemStatus.success;
        } catch (e) {
          item.status = ItemStatus.failed;
          item.error = e.toString();
        }
      }
    }

    await ref.read(songListProvider.notifier).load();
    _loadExistingSongs();
    if (mounted) setState(() {});
  }

  void _reset() {
    _items.clear();
    _processing = false;
    _allDone = false;
    _hideHasLyric = true;
    _hideNoMatch = true;
    if (mounted) setState(() {});
  }

  String get _titleText {
    switch (_mode) {
      case UploadMode.song:
        return '上传歌曲';
      case UploadMode.lyric:
        return '上传歌词';
      case UploadMode.cover:
        return '上传封图';
    }
  }

  Widget _filterChip(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: value ? AppColors.accent.withOpacity(0.15) : AppColors.elevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? AppColors.accent : AppColors.subtle,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 14,
              color: value ? AppColors.accent : AppColors.muted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: value ? AppColors.accent : AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_processing) {
      return Scaffold(
        appBar: AppBar(title: const Text('上传')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _IdleView(
              mode: _mode,
              onSongPick: _pickAndUploadSongs,
              onLyricPick: _pickAndUploadLyrics,
              onCoverPick: _pickAndUploadCovers,
              onModeChanged: (m) => setState(() => _mode = m),
            ),
          ),
        ),
      );
    }

    final displayItems = _items.where((i) {
      if (i.status == ItemStatus.skipped) return false;
      if (_hideNoMatch && i.status == ItemStatus.noMatch) return false;
      if (_hideHasLyric && i.status == ItemStatus.hasLyric) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titleText),
        leading: _allDone
            ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: _reset)
            : null,
      ),
      body: Column(
        children: [
          if (displayItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text(_matchDirectionLabel, style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(
                    '${displayItems.where((i) => i.status == ItemStatus.success).length}/${displayItems.where((i) => i.status != ItemStatus.noMatch && i.status != ItemStatus.hasLyric).length}',
                    style: TextStyle(color: _allDone ? AppColors.accent : AppColors.muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          if (displayItems.isNotEmpty && !_allDone)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Row(
                children: [
                  _filterChip('已有歌词', _hideHasLyric, (v) => setState(() => _hideHasLyric = v)),
                  const SizedBox(width: 8),
                  _filterChip('未匹配', _hideNoMatch, (v) => setState(() => _hideNoMatch = v)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: displayItems.length,
              itemBuilder: (_, i) => _buildItemRow(displayItems[i]),
            ),
          ),
          if (_allDone)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_items.any((i) => i.status == ItemStatus.failed)) ...[
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _retryAllFailed,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('重试失败项'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error.withOpacity(0.15),
                          foregroundColor: AppColors.error,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  SizedBox(
                    width: 160,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: _reset,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('继续上传'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: AppColors.deep,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _isRetryable(_UploadItem item) {
    if (_mode == UploadMode.song) return item.status == ItemStatus.failed;
    if (_mode == UploadMode.cover) return item.status == ItemStatus.failed;
    if (_mode == UploadMode.lyric) {
      return item.status == ItemStatus.failed ||
          item.status == ItemStatus.skipped ||
          item.status == ItemStatus.noMatch ||
          item.status == ItemStatus.needDecision;
    }
    return false;
  }

  Widget _buildItemRow(_UploadItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _isRetryable(item) ? () => _retryItem(item) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(item.statusIcon, size: 20, color: item.statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.text, fontSize: 13)),
                      if (_mode == UploadMode.lyric && item.matchedSong != null && item.status != ItemStatus.failed)
                        Text('→ ${item.matchedSong!.title} - ${item.matchedSong!.artist}',
                            style: const TextStyle(color: AppColors.accent, fontSize: 11)),
                      if (item.error != null && item.status == ItemStatus.failed)
                        Text(item.error!, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.error, fontSize: 10)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(item.userApproved && item.status == ItemStatus.pending ? '自动匹配' : item.statusText,
                        style: TextStyle(color: item.statusColor, fontSize: 12)),
                    if (_mode == UploadMode.lyric && (item.status == ItemStatus.failed || item.status == ItemStatus.skipped || item.status == ItemStatus.noMatch)) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.refresh_rounded, size: 18, color: AppColors.accent),
                    ],
                    if ((_mode == UploadMode.song || _mode == UploadMode.cover) && item.status == ItemStatus.failed) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.refresh_rounded, size: 18, color: AppColors.accent),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdleView extends StatelessWidget {
  final UploadMode mode;
  final VoidCallback onSongPick;
  final VoidCallback onLyricPick;
  final VoidCallback onCoverPick;
  final ValueChanged<UploadMode> onModeChanged;
  const _IdleView({
    required this.mode,
    required this.onSongPick,
    required this.onLyricPick,
    required this.onCoverPick,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final VoidCallback onPick;
    final String labelText;
    final String hintText;
    final IconData icon;

    switch (mode) {
      case UploadMode.song:
        onPick = onSongPick;
        labelText = '添加你的音乐';
        hintText = '支持 MP3 / FLAC / KGM 格式';
        icon = Icons.music_note_rounded;
        break;
      case UploadMode.lyric:
        onPick = onLyricPick;
        labelText = '添加歌词';
        hintText = '支持 KRC 歌词格式';
        icon = Icons.lyrics_rounded;
        break;
      case UploadMode.cover:
        onPick = onCoverPick;
        labelText = '添加封图';
        hintText = '支持 PNG / JPG 格式';
        icon = Icons.image_rounded;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 120, height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.subtle, width: 1.5),
          ),
          child: Icon(icon, size: 44, color: AppColors.muted),
        ),
        const SizedBox(height: 28),
        Text(labelText,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 8),
        Text(hintText, style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        const SizedBox(height: 24),
        _ModeToggle(mode: mode, onChanged: onModeChanged),
        const SizedBox(height: 32),
        SizedBox(
          width: 200, height: 48,
          child: ElevatedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.add_rounded),
            label: const Text('选择文件'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.deep,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final UploadMode mode;
  final ValueChanged<UploadMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: AppColors.elevated, borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeTab(label: '歌曲', active: mode == UploadMode.song, onTap: () => onChanged(UploadMode.song)),
          _ModeTab(label: '歌词', active: mode == UploadMode.lyric, onTap: () => onChanged(UploadMode.lyric)),
          _ModeTab(label: '封图', active: mode == UploadMode.cover, onTap: () => onChanged(UploadMode.cover)),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ModeTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w500,
          color: active ? AppColors.deep : AppColors.muted,
        )),
      ),
    );
  }
}
