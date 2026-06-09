import 'dart:convert';
import 'package:crypto/crypto.dart';

class Signer {
  final String secret;
  const Signer(this.secret);

  Map<String, String> generateSignature(String method, String path) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final timestampStr = timestamp.toString();
    final data = '$timestampStr$method$path';
    final hmac = Hmac(sha256, utf8.encode(secret));
    final digest = hmac.convert(utf8.encode(data));
    final signature = digest.toString();

    return {
      'x-timestamp': timestampStr,
      'x-signature': signature,
    };
  }
}
