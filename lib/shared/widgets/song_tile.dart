import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/song.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/network/itunes_cover_service.dart';

class SongTile extends ConsumerStatefulWidget {
  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SongTile({super.key, required this.song, this.onTap, this.onLongPress});

  @override
  ConsumerState<SongTile> createState() => _SongTileState();
}

class _SongTileState extends ConsumerState<SongTile> {
  Uint8List? _cover;

  @override
  void initState() {
    super.initState();
    _fetchCover();
  }

  @override
  void didUpdateWidget(covariant SongTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      _cover = null;
      _fetchCover();
    }
  }

  Future<void> _fetchCover() async {
    final bytes = await const ITunesCoverService().fetch(widget.song.title, widget.song.artist);
    if (mounted) setState(() => _cover = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildCover(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.song.artist} · ${widget.song.durationFormatted}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!widget.song.hasLyric)
                    Icon(Icons.lyrics_outlined, size: 16, color: AppColors.muted.withOpacity(0.5)),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (_cover != null) {
      return Image.memory(_cover!, width: 46, height: 46, fit: BoxFit.cover);
    }
    return Container(
      width: 46, height: 46,
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.music_note_rounded, color: AppColors.accent, size: 22),
    );
  }
}
