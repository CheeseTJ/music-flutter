import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import 'package:music_app/core/i18n/app_strings.dart';

/// 线上版本信息（来自蒲公英）
class AppUpdateInfo {
  final bool hasUpdate;
  final bool forceUpdate;
  final String currentVersion;
  final String latestVersion;
  final String latestVersionNo;
  final String downloadUrl;
  final String releasePageUrl;
  final String updateDescription;
  final int fileSize;

  const AppUpdateInfo({
    required this.hasUpdate,
    required this.forceUpdate,
    required this.currentVersion,
    required this.latestVersion,
    required this.latestVersionNo,
    required this.downloadUrl,
    required this.releasePageUrl,
    required this.updateDescription,
    required this.fileSize,
  });

  String get fileSizeText {
    if (fileSize <= 0) return '';
    final mb = fileSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class AppUpdateException implements Exception {
  final String message;
  const AppUpdateException(this.message);
  @override
  String toString() => message;
}

/// 通过蒲公英开放 API 检查更新、下载安装包。
class AppUpdateService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: AppConstants.connectTimeout,
    receiveTimeout: AppConstants.receiveTimeout,
  ));

  /// 用「当前安装版本」去问蒲公英有没有更新的版本。
  /// 蒲公英会自己比对，直接给 [AppUpdateInfo.hasUpdate]，无需本地比版本号。
  Future<AppUpdateInfo> check(String currentVersion) async {
    if (!AppConstants.hasPgyerKey) {
        throw AppUpdateException(L.s.noApiKey);
      }

    final Response<dynamic> resp;
    try {
      resp = await _dio.post(
        '${AppConstants.pgyerApiBase}/app/check',
        data: {
          '_api_key': AppConstants.pgyerApiKey,
          'appKey': AppConstants.pgyerAppKey,
          'buildVersion': currentVersion,
        },
        // 蒲公英只解析 form-urlencoded。dio 传 Map 时默认按 JSON 发出，
        // 服务端读不到字段会直接报 code=1001「_api_key could not be empty」。
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (e) {
      throw AppUpdateException(L.s.checkFailed(e.message ?? e.type.name));
    }

    final body = resp.data;
    if (body is! Map) {
      throw AppUpdateException(L.s.checkBadFormat);
    }
    final code = body['code'];
    if (code != 0) {
      throw AppUpdateException(
        L.s.pgyerError('$code', '${body['message'] ?? ''}').trim(),
      );
    }

    final data = (body['data'] as Map?) ?? const {};
    return AppUpdateInfo(
      hasUpdate: data['buildHaveNewVersion'] == true,
      forceUpdate: data['needForceUpdate'] == true,
      currentVersion: currentVersion,
      latestVersion: '${data['buildVersion'] ?? ''}',
      latestVersionNo: '${data['buildVersionNo'] ?? ''}',
      downloadUrl: '${data['downloadURL'] ?? ''}',
      releasePageUrl: '${data['buildShortcutUrl'] ?? ''}',
      updateDescription: '${data['buildUpdateDescription'] ?? ''}',
      fileSize: int.tryParse('${data['buildFileSize'] ?? 0}') ?? 0,
    );
  }

  /// 下载 APK 到应用缓存目录，返回本地路径。
  /// 缓存目录在 open_filex 的 FileProvider 白名单内，可直接交给安装器。
  Future<String> download(
    String url, {
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getTemporaryDirectory();
    final savePath = '${dir.path}/music-app-update.apk';

    // 上一次下载的残留先删掉，避免把旧包当成新包装上
    final old = File(savePath);
    if (await old.exists()) {
      await old.delete();
    }

    try {
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 10),
        ),
      );
    } on DioException catch (e) {
      throw AppUpdateException(L.s.downloadFailed(e.message ?? e.type.name));
    }
    return savePath;
  }
}
