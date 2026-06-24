import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class KgmDecoder {
  static const _headerLen = 1024;
  static const _ownKeyLen = 17;
  static const _pubKeyMagnification = 16;
  static const _magicHeader = <int>[
    0x7c, 0xd5, 0x32, 0xeb, 0x86, 0x02, 0x7f, 0x4b, 0xa8, 0xaf,
    0xa6, 0x8e, 0x0f, 0xff, 0x99, 0x14, 0x00, 0x04, 0x00, 0x00,
    0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
  ];

  static const _pubKeyMend = <int>[
    0xB8, 0xD5, 0x3D, 0xB2, 0xE9, 0xAF, 0x78, 0x8C, 0x83, 0x33,
    0x71, 0x51, 0x76, 0xA0, 0xCD, 0x37, 0x2F, 0x3E, 0x35, 0x8D,
    0xA9, 0xBE, 0x98, 0xB7, 0xE7, 0x8C, 0x22, 0xCE, 0x5A, 0x61,
    0xDF, 0x68, 0x69, 0x89, 0xFE, 0xA5, 0xB6, 0xDE, 0xA9, 0x77,
    0xFC, 0xC8, 0xBD, 0xBD, 0xE5, 0x6D, 0x3E, 0x5A, 0x36, 0xEF,
    0x69, 0x4E, 0xBE, 0xE1, 0xE9, 0x66, 0x1C, 0xF3, 0xD9, 0x02,
    0xB6, 0xF2, 0x12, 0x9B, 0x44, 0xD0, 0x6F, 0xB9, 0x35, 0x89,
    0xB6, 0x46, 0x6D, 0x73, 0x82, 0x06, 0x69, 0xC1, 0xED, 0xD7,
    0x85, 0xC2, 0x30, 0xDF, 0xA2, 0x62, 0xBE, 0x79, 0x2D, 0x62,
    0x62, 0x3D, 0x0D, 0x7E, 0xBE, 0x48, 0x89, 0x23, 0x02, 0xA0,
    0xE4, 0xD5, 0x75, 0x51, 0x32, 0x02, 0x53, 0xFD, 0x16, 0x3A,
    0x21, 0x3B, 0x16, 0x0F, 0xC3, 0xB2, 0xBB, 0xB3, 0xE2, 0xBA,
    0x3A, 0x3D, 0x13, 0xEC, 0xF6, 0x01, 0x45, 0x84, 0xA5, 0x70,
    0x0F, 0x93, 0x49, 0x0C, 0x64, 0xCD, 0x31, 0xD5, 0xCC, 0x4C,
    0x07, 0x01, 0x9E, 0x00, 0x1A, 0x23, 0x90, 0xBF, 0x88, 0x1E,
    0x3B, 0xAB, 0xA6, 0x3E, 0xC4, 0x73, 0x47, 0x10, 0x7E, 0x3B,
    0x5E, 0xBC, 0xE3, 0x00, 0x84, 0xFF, 0x09, 0xD4, 0xE0, 0x89,
    0x0F, 0x5B, 0x58, 0x70, 0x4F, 0xFB, 0x65, 0xD8, 0x5C, 0x53,
    0x1B, 0xD3, 0xC8, 0xC6, 0xBF, 0xEF, 0x98, 0xB0, 0x50, 0x4F,
    0x0F, 0xEA, 0xE5, 0x83, 0x58, 0x8C, 0x28, 0x2C, 0x84, 0x67,
    0xCD, 0xD0, 0x9E, 0x47, 0xDB, 0x27, 0x50, 0xCA, 0xF4, 0x63,
    0x63, 0xE8, 0x97, 0x7F, 0x1B, 0x4B, 0x0C, 0xC2, 0xC1, 0x21,
    0x4C, 0xCC, 0x58, 0xF5, 0x94, 0x52, 0xA3, 0xF3, 0xD3, 0xE0,
    0x68, 0xF4, 0x00, 0x23, 0xF3, 0x5E, 0x0A, 0x7B, 0x93, 0xDD,
    0xAB, 0x12, 0xB2, 0x13, 0xE8, 0x84, 0xD7, 0xA7, 0x9F, 0x0F,
    0x32, 0x4C, 0x55, 0x1D, 0x04, 0x36, 0x52, 0xDC, 0x03, 0xF3,
    0xF9, 0x4E, 0x42, 0xE9, 0x3D, 0x61, 0xEF, 0x7C, 0xB6, 0xB3,
    0x93, 0x50,
  ];

  static Uint8List? _pubKeyLarge;
  static bool _keyLoading = false;
  static final List<void Function()> _keyLoadCallbacks = [];

  static Future<void> _ensureKeyLoaded() async {
    if (_pubKeyLarge != null) return;
    if (_keyLoading) {
      final completer = Completer<void>();
      _keyLoadCallbacks.add(() => completer.complete());
      return completer.future;
    }
    _keyLoading = true;
    try {
      final gzData = await rootBundle.load('assets/kugou_key.gz');
      final decoded = await compute(_decodeGzip, gzData.buffer.asUint8List());
      _pubKeyLarge = decoded;
    } finally {
      _keyLoading = false;
      for (final callback in _keyLoadCallbacks) {
        callback();
      }
      _keyLoadCallbacks.clear();
    }
  }

  static Uint8List _decodeGzip(Uint8List data) {
    return Uint8List.fromList(gzip.decode(data));
  }

  static bool isKgmFile(String filePath) {
    final lower = filePath.toLowerCase();
    return lower.endsWith('.kgm') || lower.contains('.kgm.');
  }

  static String stripKgmExtension(String fileName) {
    final lower = fileName.toLowerCase();
    final kgmIndex = lower.indexOf('.kgm');
    if (kgmIndex == -1) return fileName;

    final before = fileName.substring(0, kgmIndex);
    final after = fileName.substring(kgmIndex + 4);

    if (after.isEmpty) return '$before.mp3';
    return '$before$after';
  }

  static Future<String> decode(String inputPath, {String? outputPath}) async {
    await _ensureKeyLoaded();

    final inputFile = File(inputPath);
    final raf = await inputFile.open(mode: FileMode.read);
    try {
      final header = await raf.read(_headerLen);
      if (header.length < _headerLen) {
        throw Exception('File too small to be a valid KGM file');
      }

      if (!_checkMagicHeader(header)) {
        throw Exception('Invalid KGM file: magic header mismatch');
      }

      final ownKey = Uint8List(_ownKeyLen);
      for (var i = 0; i < 16; i++) {
        ownKey[i] = header[0x1c + i];
      }
      ownKey[16] = 0;

      final detectedExtension = await _detectDecimalExtension(raf, ownKey);
      final extension = detectedExtension;

      final outPath = outputPath != null
          ? outputPath.replaceAll(RegExp(r'\.[^.]+$'), '.$extension')
          : '${Directory.systemTemp.path}/kgm_decoded_${DateTime.now().millisecondsSinceEpoch}.$extension';

      final outFile = File(outPath);
      final outRaf = await outFile.open(mode: FileMode.write);

      try {
        await _decodeAudioData(raf, outRaf, ownKey);
      } finally {
        await outRaf.close();
      }

      return outPath;
    } finally {
      await raf.close();
    }
  }

  static bool _checkMagicHeader(Uint8List header) {
    if (header.length < _magicHeader.length) return false;
    for (var i = 0; i < _magicHeader.length; i++) {
      if (header[i] != _magicHeader[i]) return false;
    }
    return true;
  }

  static Future<String> _detectDecimalExtension(RandomAccessFile input, Uint8List ownKey) async {
    const sampleSize = 8192;
    final encrypted = Uint8List(sampleSize);
    final bytesRead = await input.readInto(encrypted, 0, sampleSize);

    await input.setPosition(_headerLen);

    final decoded = _decodeBytes(encrypted, ownKey, 0, bytesRead);

    if (decoded.length >= 4) {
      if (decoded[0] == 0x66 && decoded[1] == 0x4C && decoded[2] == 0x61 && decoded[3] == 0x43) return 'flac';
      if (decoded[0] == 0x4F && decoded[1] == 0x67 && decoded[2] == 0x67 && decoded[3] == 0x53) return 'ogg';
      if (decoded[0] == 0x52 && decoded[1] == 0x49 && decoded[2] == 0x46 && decoded[3] == 0x46) return 'wav';
    }
    if (decoded.length >= 3) {
      if (decoded[0] == 0xFF && (decoded[1] & 0xE0) == 0xE0) return 'mp3';
      if (decoded[0] == 0x49 && decoded[1] == 0x44 && decoded[2] == 0x33) return 'mp3';
    }
    return 'mp3';
  }

  static Uint8List _decodeBytes(Uint8List input, Uint8List ownKey, int startPos, int len) {
    final pubKeyLarge = _pubKeyLarge!;
    final result = Uint8List(len);

    for (var i = 0; i < len; i++) {
      final globalPos = startPos + i;

      var b = ownKey[globalPos % _ownKeyLen] ^ input[i];
      b ^= (b & 0x0f) << 4;

      final pubKeyIdx = globalPos ~/ _pubKeyMagnification;
      var m = _pubKeyMend[globalPos % _pubKeyMend.length] ^ pubKeyLarge[pubKeyIdx];
      m ^= (m & 0x0f) << 4;

      result[i] = b ^ m;
    }

    return result;
  }

  static Future<void> _decodeAudioData(
    RandomAccessFile input,
    RandomAccessFile output,
    Uint8List ownKey,
  ) async {
    final pubKeyLarge = _pubKeyLarge!;
    const bufferSize = 65536;
    final buffer = Uint8List(bufferSize);
    var pos = 0;

    while (true) {
      final bytesRead = await input.readInto(buffer, 0, bufferSize);
      if (bytesRead == 0) break;

      for (var i = 0; i < bytesRead; i++) {
        final globalPos = pos + i;

        var b = ownKey[globalPos % _ownKeyLen] ^ buffer[i];
        b ^= (b & 0x0f) << 4;

        final pubKeyIdx = globalPos ~/ _pubKeyMagnification;
        var m = _pubKeyMend[globalPos % _pubKeyMend.length] ^ pubKeyLarge[pubKeyIdx];
        m ^= (m & 0x0f) << 4;

        buffer[i] = b ^ m;
      }

      await output.writeFrom(buffer, 0, bytesRead);
      pos += bytesRead;
    }
  }
}
