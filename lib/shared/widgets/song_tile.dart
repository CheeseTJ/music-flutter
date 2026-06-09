import 'package:flutter/material.dart';
import '../../data/models/song.dart';

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback? onTap;

  const SongTile({super.key, required this.song, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.primaryContainer,
        child: Icon(Icons.music_note, color: theme.colorScheme.onPrimaryContainer),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${song.artist} · ${song.durationFormatted}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: song.format == 'flac'
              ? Colors.orange.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          song.formatLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: song.format == 'flac' ? Colors.orange : Colors.blue,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
