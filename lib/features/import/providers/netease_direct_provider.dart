import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

import '../models/song.dart';
import 'music_provider.dart';

/// 网易云直连 URL Provider — EAPI 加密在 Dart 端完成
/// 绕过 Cloudflare Worker 的 AES-ECB 兼容问题
class NeteaseDirectProvider implements MusicProvider {
  final Dio _dio;

  static const _eapiKey = 'e82ckenh8dichen8';
  static const _baseUrl = 'http://music.163.com';

  NeteaseDirectProvider(this._dio);

  @override
  String get platform => 'netease_direct';

  @override
  Future<List<Song>> search(String keyword, {int page = 1, int num = 20}) async {
    return [];
  }

  @override
  Future<SongUrl?> getUrl(Song song, {String quality = ''}) async {
    try {
      final body = jsonEncode({'ids': [int.tryParse(song.id) ?? 0], 'br': 320000});
      final urlPath = '/api/song/enhance/player/url';

      final params = _eapiEncrypt(urlPath, body);

      final resp = await _dio.post(
        '$_baseUrl/eapi$urlPath',
        data: 'params=${Uri.encodeComponent(params)}',
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Referer': 'https://music.163.com/',
            'User-Agent': 'Mozilla/5.0 (Linux; Android 11; wv) AppleWebKit/537.36 (KHTML, like Gecko) '
                'Version/4.0 Chrome/77.0.3865.120 MQQBrowser/6.2 TBS/045714 '
                'Mobile Safari/537.36 NeteaseMusic/8.7.01',
            'Cookie': 'osver=android; appver=8.7.01; os=android; channel=netease;',
          },
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = resp.data;
      if (data is Map) {
        final u = data['data']?[0];
        if (u != null && u['url'] != null) {
          final url = u['url'].toString();
          if (url.isNotEmpty) {
            final ext = url.contains('.flac') ? 'flac' : (url.contains('.m4a') ? 'm4a' : 'mp3');
            return SongUrl(url: url, source: 'netease_direct', ext: ext);
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// EAPI 加密
  /// data = "{urlPath}-36cd479b6b5-{body}-36cd479b6b5-{digest}"
  /// 再用 AES-128-ECB 加密，输出大写 hex
  String _eapiEncrypt(String urlPath, String body) {
    // 1. message = "nobody{url}use{body}md5forencrypt"
    final message = 'nobody$urlPath${'use'}$body${'md5forencrypt'}';
    final digest = md5.convert(utf8.encode(message)).toString();

    // 2. data = "{url}-36cd479b6b5-{body}-36cd479b6b5-{digest}"
    final data = '$urlPath-36cd479b6b5-$body-36cd479b6b5-$digest';

    // 3. AES-128-ECB encrypt
    final key = encrypt.Key.fromUtf8(_eapiKey);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ecb));
    final encrypted = encrypter.encrypt(data);

    // 4. 输出大写 hex
    return encrypted.base16.toUpperCase();
  }
}
