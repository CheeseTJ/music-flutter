import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class KrcDecoder {
  static const _key = <int>[
    0x40, 0x47, 0x61, 0x77, 0x5e, 0x32, 0x74, 0x47,
    0x51, 0x36, 0x31, 0x2d, 0xce, 0xd2, 0x6e, 0x69,
  ];

  static bool isKrcFile(String filePath) {
    final lower = filePath.toLowerCase();
    return lower.endsWith('.krc') || lower.contains('.krc.');
  }

  static String stripKrcExtension(String fileName) {
    final lower = fileName.toLowerCase();
    final krcIndex = lower.indexOf('.krc');
    if (krcIndex == -1) return fileName;
    final before = fileName.substring(0, krcIndex);
    final after = fileName.substring(krcIndex + 4);
    if (after.isEmpty) return '$before.lrc';
    return '$before$after';
  }

  static Future<String> decode(String inputPath, {String? outputPath}) async {
    final lrcContent = await decodeToString(inputPath);
    final outPath = outputPath ??
        '${Directory.systemTemp.path}/krc_decoded_${DateTime.now().millisecondsSinceEpoch}.lrc';
    final outFile = File(outPath);
    await outFile.writeAsString(lrcContent);
    return outPath;
  }

  static Future<String> decodeToString(String inputPath) async {
    final inputFile = File(inputPath);
    final raw = await inputFile.readAsBytes();
    if (raw.isEmpty) throw Exception('Empty KRC file');
    if (raw.length < 4) throw Exception('KRC file too short');

    if (raw[0] != 0x6B || raw[1] != 0x72 || raw[2] != 0x63) {
      throw Exception('不是有效的 KRC 文件（magic header 不匹配）');
    }

    final body = raw.sublist(4);

    final decrypted = Uint8List(body.length);
    for (var i = 0; i < body.length; i++) {
      decrypted[i] = body[i] ^ _key[i % 16];
    }

    final decompressed = zlib.decode(decrypted);
    var text = _bytesToString(decompressed);

    if (text.isEmpty) {
      throw Exception('解码后内容为空');
    }

    text = _stripBom(text);
    text = _convertKrcToLrc(text);

    if (text.isEmpty) {
      throw Exception('解码后内容为空');
    }

    return text;
  }

  static String _bytesToString(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  static String _stripBom(String text) {
    if (text.isEmpty) return text;
    if (text.codeUnitAt(0) == 0xFEFF) {
      return text.substring(1);
    }
    return text;
  }

  static String _convertKrcToLrc(String krcText) {
    var lines = krcText.split('\n');
    final result = <String>[];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('[kana:') || trimmed.startsWith('[Kana:') ||
          trimmed.startsWith('[language:') || trimmed.startsWith('[Language:')) {
        continue;
      }

      line = line.replaceAll(RegExp(r'<[^>]*>'), '');

      line = line.replaceAllMapped(RegExp(r'\[(\d+),(\d+)\]'), (m) {
        final ms = int.tryParse(m.group(1)!) ?? 0;
        final totalSec = ms ~/ 1000;
        final min = totalSec ~/ 60;
        final sec = totalSec % 60;
        final msPart = ms % 1000 ~/ 10;
        return '[${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}.${msPart.toString().padLeft(2, '0')}]';
      });

      result.add(line);
    }

    return result.join('\n');
  }
}
