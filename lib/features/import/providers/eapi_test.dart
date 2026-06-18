// Quick EAPI test - run with: dart run lib/features/import/providers/eapi_test.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

void main() {
  const urlPath = '/api/song/enhance/player/url';
  const body = '{"ids":[5257138],"br":320000}';

  // Step 1: digest
  final message = 'nobody$urlPath${'use'}$body${'md5forencrypt'}';
  final digest = md5.convert(utf8.encode(message)).toString();
  print('Digest: $digest');

  // Step 2: data
  final data = '$urlPath-36cd479b6b5-$body-36cd479b6b5-$digest';
  print('Data length: ${data.length}');

  // Step 3: AES-128-ECB
  final key = encrypt.Key.fromUtf8('e82ckenh8dichen8');
  final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.ecb));
  final encrypted = encrypter.encrypt(data);
  final hex = encrypted.base16.toUpperCase();
  print('Hex length: ${hex.length}');
  print('Hex: $hex');

  // Expected from Node.js:
  const expected = 'FA90B329E9614F79E79598F37DC2EDB430F8378D2A2796338F0BFDEAEF824A22975CDA9D96D79E6DC4A59218CDB8199F2145F55FEED8129B21509C21E4F4431B8D532D31B2338802ADDEFFC5550DEE9943813F207A4A237CDD449FB7D7F27305B2AEEEEF635BDF6514AF3C6E1CF622A8CC357B9DF056B9E67D3BA2BA36A15BCD';
  print('Match: ${hex == expected}');
}
