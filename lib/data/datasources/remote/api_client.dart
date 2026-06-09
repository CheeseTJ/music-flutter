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

  Future<Map<String, dynamic>> uploadSong(String filePath, String fileName) async {
    final headers = _signer.generateSignature('POST', '/upload');
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _dio.post(
      '/upload',
      data: formData,
      options: Options(headers: headers),
    );
    return response.data as Map<String, dynamic>;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
