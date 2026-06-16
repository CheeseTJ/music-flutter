import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';

Future<int> parseDuration(Uint8List bytes, {String ext = 'mp3'}) async {
  final dir = Directory.systemTemp;
  final file = File('${dir.path}/music_import_tmp.$ext');
  try {
    await file.writeAsBytes(bytes);
    final player = AudioPlayer();
    await player.setFilePath(file.path);
    final dur = player.duration;
    await player.dispose();
    return dur?.inSeconds ?? 0;
  } catch (_) {
    return 0;
  } finally {
    try { await file.delete(); } catch (_) {}
  }
}
