import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/remote/api_client.dart';

/// 曲库在 R2 上的真实占用。
///
/// 数字来自 Cloudflare 官方的 bucket usage 接口（App 这边走 music-worker 的
/// /storage 转发），也就是 dashboard「指标」页那个数 —— 不是前端按歌曲
/// `size` 字段自己加出来的估算值。
class RemoteStorage {
  /// 对象本体 + 元数据，与计费口径一致
  final int usedBytes;

  /// 免费额度
  final int quotaBytes;
  final int objectCount;

  /// 官方数据的采样时间
  final DateTime? measuredAt;

  const RemoteStorage({
    required this.usedBytes,
    required this.quotaBytes,
    required this.objectCount,
    this.measuredAt,
  });

  /// 已用比例，0~1
  double get usedRatio =>
      quotaBytes <= 0 ? 0 : (usedBytes / quotaBytes).clamp(0.0, 1.0);

  factory RemoteStorage.fromJson(Map<String, dynamic> json) {
    final measured = json['measuredAt'] as String?;
    return RemoteStorage(
      usedBytes: (json['usedBytes'] as num?)?.toInt() ?? 0,
      quotaBytes: (json['quotaBytes'] as num?)?.toInt() ?? 0,
      objectCount: (json['objectCount'] as num?)?.toInt() ?? 0,
      measuredAt: measured == null ? null : DateTime.tryParse(measured),
    );
  }
}

final storageProvider = FutureProvider<RemoteStorage>((ref) async {
  final json = await ref.read(apiClientProvider).getStorage();
  return RemoteStorage.fromJson(json);
});
