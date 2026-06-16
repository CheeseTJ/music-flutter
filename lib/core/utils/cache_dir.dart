import 'dart:io';
import 'package:path_provider/path_provider.dart';

String? _cachedPath;

Future<String> getCacheDir() async {
  if (_cachedPath != null) return _cachedPath!;
  final dir = await getApplicationDocumentsDirectory();
  _cachedPath = '${dir.path}/music_cache';
  await Directory(_cachedPath!).create(recursive: true);
  return _cachedPath!;
}
