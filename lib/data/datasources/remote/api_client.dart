import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/signer.dart';

class ApiClient {
  late final Dio _dio;
  final Signer _signer = const Signer(AppConstants.appKey);

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: AppConstants.connectTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
    ));
  }

  Future<List<Map<String, dynamic>>> getSongList() async {
    final response = await _dio.get('/list');
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['songs'] ?? []);
  }

  Future<Map<String, dynamic>> getPlayUrl(int id) async {
    final headers = _signer.generateSignature('GET', '/play');
    final response = await _dio.get(
      '/play',
      queryParameters: {'id': id},
      options: Options(headers: headers),
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadSong(String filePath, String fileName, {String type = ''}) async {
    final headers = _signer.generateSignature('POST', '/upload');
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'type': type,
    });
    try {
      final response = await _dio.post(
        '/upload',
        data: formData,
        options: Options(headers: headers),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      String detail = e.message ?? '';
      if (e.response != null) {
        detail += ' | Status: ${e.response!.statusCode}';
        detail += ' | Body: ${e.response!.data}';
      }
      throw Exception('上传失败: $detail');
    }
  }

  Future<Map<String, dynamic>> uploadLyric(int songId, String lrcText) async {
    final headers = _signer.generateSignature('POST', '/lyric/upload');
    try {
      final response = await _dio.post(
        '/lyric/upload',
        data: {'song_id': songId, 'lyric': lrcText},
        options: Options(headers: headers),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      String detail = e.message ?? '';
      if (e.response != null) {
        detail += ' | Status: ${e.response!.statusCode}';
        detail += ' | Body: ${e.response!.data}';
      }
      throw Exception('歌词上传失败: $detail');
    }
  }

  Future<String> getLyric(int songId) async {
    final headers = _signer.generateSignature('GET', '/lyric');
    final response = await _dio.get(
      '/lyric',
      queryParameters: {'id': songId},
      options: Options(headers: headers),
    );
    final data = response.data as Map<String, dynamic>;
    return data['lyric'] as String? ?? '';
  }

  Future<void> deleteSong(int id) async {
    final headers = _signer.generateSignature('DELETE', '/song');
    try {
      await _dio.delete(
        '/song',
        queryParameters: {'id': id},
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      String detail = e.message ?? '';
      if (e.response != null) {
        detail += ' | Status: ${e.response!.statusCode}';
        detail += ' | Body: ${e.response!.data}';
      }
      throw Exception('删除歌曲失败: $detail');
    }
  }

  Future<void> deleteLyric(int songId) async {
    final headers = _signer.generateSignature('DELETE', '/lyric');
    try {
      await _dio.delete(
        '/lyric',
        queryParameters: {'id': songId},
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      String detail = e.message ?? '';
      if (e.response != null) {
        detail += ' | Status: ${e.response!.statusCode}';
        detail += ' | Body: ${e.response!.data}';
      }
      throw Exception('删除歌词失败: $detail');
    }
  }

  Future<void> deleteCover(int songId) async {
    final headers = _signer.generateSignature('DELETE', '/cover');
    try {
      await _dio.delete(
        '/cover',
        queryParameters: {'id': songId},
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      String detail = e.message ?? '';
      if (e.response != null) {
        detail += ' | Status: ${e.response!.statusCode}';
        detail += ' | Body: ${e.response!.data}';
      }
      throw Exception('\u5220\u9664\u5c01\u56fe\u5931\u8d25: $detail');
    }
  }

  Future<void> downloadFromUrl(String url, String title, String artist, {String? coverUrl}) async {
    final headers = _signer.generateSignature('POST', '/download_url');
    try {
      final response = await _dio.post(
        '/download_url',
        data: {
          'url': url,
          'title': title,
          'artist': artist,
          if (coverUrl != null) 'cover_url': coverUrl,
        },
        options: Options(headers: headers),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] as String? ?? '\u4e0b\u8f7d\u5931\u8d25');
      }
    } on DioException catch (e) {
      String detail = e.message ?? '';
      if (e.response != null) {
        detail += ' | Status: ${e.response!.statusCode}';
        detail += ' | Body: ${e.response!.data}';
      }
      throw Exception('\u4e0b\u8f7d\u5931\u8d25: $detail');
    }
  }

  Future<Map<String, dynamic>> uploadCover(int songId, String filePath) async {
    final headers = _signer.generateSignature('POST', '/cover/upload');
    final formData = FormData.fromMap({
      'song_id': songId,
      'file': await MultipartFile.fromFile(filePath),
    });
    try {
      final response = await _dio.post(
        '/cover/upload',
        data: formData,
        options: Options(headers: headers),
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      String detail = e.message ?? '';
      if (e.response != null) {
        detail += ' | Status: ${e.response!.statusCode}';
        detail += ' | Body: ${e.response!.data}';
      }
      throw Exception('封图上传失败: $detail');
    }
  }

  Future<List<Map<String, dynamic>>> searchSongs(String name, String type) async {
    final response = await _dio.get(
      '/search/$type',
      queryParameters: {'name': name},
    );
    final data = response.data as Map<String, dynamic>;
    return List<Map<String, dynamic>>.from(data['results'] ?? []);
  }

  Future<void> importSong(String id, String source, String name, String artist, {String? url}) async {
    final headers = _signer.generateSignature('POST', '/import');
    try {
      final response = await _dio.post(
        '/import',
        data: {
          'id': id,
          'source': source,
          'name': name,
          'artist': artist,
          if (url != null && url.isNotEmpty) 'url': url,
        },
        options: Options(headers: headers),
      );
      final data = response.data as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] as String? ?? '导入失败');
      }
    } on DioException catch (e) {
      String detail = e.message ?? '';
      if (e.response != null) {
        detail += ' | Status: ${e.response!.statusCode}';
        detail += ' | Body: ${e.response!.data}';
      }
      throw Exception('导入失败: $detail');
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
