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
      _throwDioError(e, '上传');
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
      _throwDioError(e, '歌词上传');
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
      _throwDioError(e, '删除歌曲');
    }
  }

  Never _throwDioError(DioException e, String op) {
    String detail = e.message ?? '';
    if (e.response != null) {
      detail += ' | Status: ${e.response?.statusCode}';
      detail += ' | Body: ${e.response?.data}';
    }
    throw Exception('$op失败: $detail');
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
