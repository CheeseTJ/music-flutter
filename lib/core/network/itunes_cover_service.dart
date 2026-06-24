import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class ITunesCoverService {
  static final Map<int, Uint8List> _memory = {};
  static final Map<int, String> _urlCache = {};

  const ITunesCoverService();

  Future<String?> fetchUrl(String title, String artist) async {
    final key = '${title}_$artist'.hashCode;
    final cached = _urlCache[key];
    if (cached != null) return cached;

    try {
      final artworkUrl = await _searchArtwork(title, artist);
      if (artworkUrl != null) _urlCache[key] = artworkUrl;
      return artworkUrl;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> fetch(String title, String artist) async {
    final key = '${title}_$artist'.hashCode;
    final cached = _memory[key];
    if (cached != null) return cached;

    final cacheFile = File('${Directory.systemTemp.path}/itunes_cover_$key.jpg');
    if (await cacheFile.exists()) {
      final bytes = await cacheFile.readAsBytes();
      _memory[key] = bytes;
      return bytes;
    }

    try {
      final artworkUrl = await _searchArtwork(title, artist);
      if (artworkUrl == null) return null;

      final bytes = await _download(artworkUrl);
      if (bytes != null) {
        _memory[key] = bytes;
        await cacheFile.writeAsBytes(bytes);
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _searchArtwork(String title, String artist) async {
    final term = Uri.encodeComponent(artist.isNotEmpty ? '$title $artist' : title);
    final url = 'https://itunes.apple.com/search?term=$term&limit=1&country=cn&media=music';

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent', 'MusicApp/1.0');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      if (resp.statusCode != 200) return null;

      final body = await resp.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final results = data['results'] as List? ?? [];
      if (results.isEmpty) return null;

      final artwork = (results.first as Map<String, dynamic>)['artworkUrl100'] as String?;
      return artwork?.replaceAll('100x100bb', '600x600bb');
    } finally {
      client.close();
    }
  }

  Future<Uint8List?> _download(String url) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.getUrl(Uri.parse(url));
      final resp = await req.close().timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;

      final sink = BytesBuilder(copy: false);
      await for (final chunk in resp) {
        sink.add(chunk);
        if (sink.length > 524288) break;
      }
      return sink.takeBytes();
    } finally {
      client.close();
    }
  }
}
