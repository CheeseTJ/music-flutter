class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String format;
  final int duration;
  final int size;
  final String? lyricPath;
  final int createdAt;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.format,
    required this.duration,
    required this.size,
    this.lyricPath,
    required this.createdAt,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as int,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      format: json['format'] as String,
      duration: json['duration'] as int,
      size: json['size'] as int,
      lyricPath: json['lyric_path'] as String?,
      createdAt: json['created_at'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'format': format,
      'duration': duration,
      'size': size,
      'lyric_path': lyricPath,
      'created_at': createdAt,
    };
  }

  String get durationFormatted {
    final m = duration ~/ 60;
    final s = (duration % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get formatLabel => format.toUpperCase();

  bool get hasLyric => lyricPath != null && lyricPath!.isNotEmpty; // lyric_path is set to 'db' when lyric text stored in DB

  String get sizeFormatted {
    if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    }
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
