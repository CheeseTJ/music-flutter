class Song {
  final String platform; // qq / netease / kuwo / kugou / migu
  final String source;   // dedicated / meting
  final String id;
  final String name;
  final String singer;
  final String? album;
  final String? cover;
  final String? quality;

  Song({
    required this.platform,
    this.source = 'dedicated',
    required this.id,
    required this.name,
    required this.singer,
    this.album,
    this.cover,
    this.quality,
  });

  Song copyWith({String? source}) => Song(
    platform: platform,
    source: source ?? this.source,
    id: id,
    name: name,
    singer: singer,
    album: album,
    cover: cover,
    quality: quality,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && platform == other.platform && id == other.id;

  @override
  int get hashCode => platform.hashCode ^ id.hashCode;
}

class SongUrl {
  final String url;
  final String? lrc;
  final String? ext;
  final String source; // 最终由哪条线路提供

  SongUrl({required this.url, this.lrc, this.ext, this.source = 'dedicated'});
}
