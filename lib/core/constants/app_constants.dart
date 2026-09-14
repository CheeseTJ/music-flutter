class AppConstants {
  /// music-api：搜索 / 取链 / 歌词（聚合接口）
  static const String baseUrl = 'https://music.june-t.top';

  /// music-worker（Cloudflare）：个人曲库（上传 / 列表 / 播放 / 删除）
  static const String vaultBaseUrl = 'https://valut.june-t.top';

  static const String appKey = 'junet';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ---------------------------------------------------------------
  //  应用更新（蒲公英开放 API）
  //
  //  走蒲公英而不是 GitHub Release：蒲公英在国内是直连、下载走国内 CDN，
  //  而 GitHub Release 在国内拉取和下载都不稳定。
  //
  //  API Key 不写死在这里，构建时通过
  //    --dart-define=PGYER_API_KEY=xxx
  //  注入（CI 从 GitHub Secrets 取）。未注入时更新检查会明确提示未配置，
  //  不会静默失败。
  // ---------------------------------------------------------------
  static const String pgyerApiBase = 'https://www.pgyer.com/apiv2';

  /// 蒲公英后台「API 信息」页获取，对应本 App 在蒲公英上的 _api_key
  static const String pgyerApiKey = String.fromEnvironment('PGYER_API_KEY');

  /// 蒲公英上的 App Key（同一 App 各版本相同）
  static const String pgyerAppKey = '472c49ece21c1674ff8269659d121fc5';

  static bool get hasPgyerKey => pgyerApiKey.isNotEmpty;
}
