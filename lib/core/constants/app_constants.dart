class AppConstants {
  /// music-api：搜索 / 取链 / 歌词（聚合接口）
  static const String baseUrl = 'https://music.june-t.top';

  /// music-worker（Cloudflare）：个人曲库（上传 / 列表 / 播放 / 删除）
  static const String vaultBaseUrl = 'https://music-worker.2697065512-1b5.workers.dev';

  static const String appKey = 'junet';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
