import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/provider_config.dart';

class ProviderConfigService {
  static const _baseUrl = 'https://music.june-t.top';
  static List<ProviderConfig>? _cached;

  static List<ProviderConfig>? get cached => _cached;

  static Future<void> preload() async {
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
      final resp = await dio.get('$_baseUrl/providers');
      final list = resp.data['providers'] as List;
      _cached = list.map((j) => ProviderConfig.fromJson(j as Map<String, dynamic>)).toList();
      debugPrint('[ProviderConfig] loaded ${_cached!.length} providers from remote');
    } catch (e) {
      debugPrint('[ProviderConfig] fetch failed: $e');
    }
  }

  static String? baseUrlFor(String source) {
    final configs = _cached;
    if (configs == null) return null;
    for (final c in configs) {
      if (c.source == source) return c.baseUrl;
    }
    return null;
  }
}
