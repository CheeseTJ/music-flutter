class LyricLine {
  final Duration time;
  final String text;

  const LyricLine({required this.time, required this.text});
}

class LrcParser {
  final List<LyricLine> lines;
  final List<String> metadata;

  const LrcParser._({required this.lines, required this.metadata});

  static LrcParser parse(String lrcText) {
    final lines = <LyricLine>[];
    final metadata = <String>[];
    final timeRegExp = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
    final metaRegExp = RegExp(r'\[(\w+):(.*)\]');

    for (final rawLine in lrcText.split('\n')) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      if (RegExp(r'^\[\d{2}:\d{2}\.').hasMatch(trimmed)) {
        final matches = timeRegExp.allMatches(trimmed);
        if (matches.isEmpty) continue;

        final text = trimmed.substring(trimmed.lastIndexOf(']') + 1).trim();
        if (text.isEmpty) continue;

        for (final match in matches) {
          final min = int.parse(match.group(1)!);
          final sec = int.parse(match.group(2)!);
          final msStr = match.group(3)!;
          final ms = msStr.length == 3
              ? int.parse(msStr)
              : int.parse(msStr) * 10;

          final time = Duration(minutes: min, seconds: sec, milliseconds: ms);
          lines.add(LyricLine(time: time, text: text));
        }
        continue;
      }

      final metaMatch = metaRegExp.firstMatch(trimmed);
      if (metaMatch != null) {
        metadata.add(trimmed);
        continue;
      }
    }

    lines.sort((a, b) => a.time.compareTo(b.time));

    return LrcParser._(lines: lines, metadata: metadata);
  }

  int findIndex(Duration position) {
    if (lines.isEmpty) return -1;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (position >= lines[i].time) return i;
    }
    return -1;
  }
}
