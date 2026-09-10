// 接口联调验证脚本：模拟 app 端 MusicApi 的解析映射，对真实后端跑通全链路。
// 运行: dart run tool/api_smoke_test.dart
import 'dart:convert';
import 'dart:io';

class Song {
  final String platform, id, name, singer;
  final String? album, cover;
  final Map<String, dynamic>? extra;
  Song({required this.platform, required this.id, required this.name, required this.singer, this.album, this.cover, this.extra});
  String get token => extra?['token'] as String;
}

Future<dynamic> getJson(String path) async {
  final req = await HttpClient().getUrl(Uri.parse('https://music.june-t.top$path'));
  final resp = await req.close();
  final body = await resp.transform(utf8.decoder).join();
  final data = jsonDecode(body) as Map<String, dynamic>;
  if (data['code'] != 0) throw Exception('code=${data['code']} ${data['message']}');
  return data['data'];
}

List<Map<String, dynamic>> asOptions(Map<String, dynamic> extra) =>
    (extra['qualityOptions'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [];

Song toSong(Map<String, dynamic> item) {
  final extra = (item['extra'] as Map<String, dynamic>?) ?? {};
  return Song(
    platform: item['provider'] as String? ?? '',
    id: item['id'] as String? ?? '',
    name: item['title'] as String? ?? '',
    singer: item['artist'] as String? ?? '',
    album: item['album'] as String?,
    cover: item['cover'] as String?,
    extra: {'token': item['token'], 'qualityOptions': asOptions(extra)},
  );
}

Future<void> main() async {
  var failed = 0;
  void check(String name, bool ok, [String detail = '']) {
    stdout.writeln('${ok ? "PASS" : "FAIL"} $name ${ok ? "" : detail}');
    if (!ok) failed++;
  }

  // 1. 聚合搜索
  final data = await getJson('/api/search?q=${Uri.encodeComponent('富士山下 陈奕迅')}&limit=5') as List;
  final items = data.cast<Map<String, dynamic>>();
  check('search 返回结果', items.isNotEmpty, '空');
  final songs = items.map(toSong).toList();
  check('字段映射完整', songs.every((s) => s.platform.isNotEmpty && s.id.isNotEmpty && s.name.isNotEmpty && s.token.isNotEmpty),
      songs.map((s) => '${s.platform}/${s.id}').join(','));
  final withOpts = songs.where((s) => (s.extra?['qualityOptions'] as List?)?.isNotEmpty == true).toList();
  check('qualityOptions 可用', withOpts.isNotEmpty, '所有结果无音质选项');
  stdout.writeln('     providers: ${songs.map((s) => s.platform).toSet().join(", ")}');

  // 2. 播放默认最高音质：并发各档位取链，选 bitrate 最高的实际结果
  final best = withOpts.first;
  final opts = asOptions(best.extra!);
  final urls = await Future.wait(opts.map((o) async {
    try {
      return await getJson('/api/url?token=${Uri.encodeComponent(best.token)}&quality=${o['value']}')
          as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }));
  final okUrls = urls.where((u) => (u['url'] as String?)?.isNotEmpty == true).toList();
  int normBitrate(Map<String, dynamic> u) {
    final v = int.tryParse(u['bitrate']?.toString() ?? '') ?? 0;
    return v <= 0 ? 0 : (v > 100000 ? v ~/ 1000 : v); // 上游单位混乱，统一归一成 kbps
  }
  okUrls.sort((a, b) => normBitrate(b).compareTo(normBitrate(a)));
  final chosen = okUrls.first;
  stdout.writeln('     各档: ${[
    for (var i = 0; i < opts.length; i++)
      '${opts[i]['value']}=${normBitrate(urls[i])}k'
  ].join(' ')}');
  stdout.writeln('     选中: ${chosen['type']} bitrate=${normBitrate(chosen)}k');
  check('选优生效(flac/高码率优先)', normBitrate(chosen) >= 999, '选中仅 ${normBitrate(chosen)}k');

  // 3. 导入指定音质（单次请求明确档位）
  if (opts.length > 1) {
    final midQ = opts[opts.length ~/ 2]['value'] as String;
    final midData = await getJson('/api/url?token=${Uri.encodeComponent(best.token)}&quality=$midQ')
        as Map<String, dynamic>;
    check('导入取链(指定档 $midQ)', (midData['url'] as String?)?.isNotEmpty == true, '');
    stdout.writeln('     type=${midData['type']} bitrate=${midData['bitrate']}');
  }

  // 4. 歌词
  final lyricData = await getJson('/api/lyric?token=${Uri.encodeComponent(best.token)}');
  final lrc = (lyricData['lyric'] ?? lyricData['lrc'] ?? '') as String;
  check('歌词获取', lrc.isNotEmpty, '空');

  // 5. vault 曲库可达性
  final vault = await HttpClient().getUrl(Uri.parse('https://music-worker.2697065512-1b5.workers.dev/list'));
  final vaultResp = await vault.close();
  check('vault 曲库 /list', vaultResp.statusCode == 200, 'status=${vaultResp.statusCode}');

  stdout.writeln(failed == 0 ? '\nALL PASS' : '\n$failed FAILED');
  exit(failed == 0 ? 0 : 1);
}
