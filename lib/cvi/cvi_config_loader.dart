import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'cvi_models.dart';

/// R2 üzerinden hafif JSON config + yerel offline fallback.
class CviConfigLoader {
  CviConfigLoader._();

  /// Cloudflare R2 public bucket yolu (mevcut engelsizclub bucket).
  static const remoteUrl =
      'https://pub-41d8be38e909416fbb3804b3a3e88569.r2.dev/cvi/cvi_steps.json';

  static const assetPath = 'assets/cvi/cvi_steps.json';

  static Future<CviConfig> load({Duration timeout = const Duration(seconds: 6)}) async {
    try {
      final res = await http.get(Uri.parse(remoteUrl)).timeout(timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final map = jsonDecode(utf8.decode(res.bodyBytes));
        if (map is Map<String, dynamic>) {
          final cfg = CviConfig.fromJson(map);
          if (cfg.steps.isNotEmpty) return cfg;
        } else if (map is Map) {
          final cfg = CviConfig.fromJson(Map<String, dynamic>.from(map));
          if (cfg.steps.isNotEmpty) return cfg;
        }
      }
    } catch (_) {
      // offline / ağ hatası → fallback
    }
    return loadOfflineFallback();
  }

  static Future<CviConfig> loadOfflineFallback() async {
    final raw = await rootBundle.loadString(assetPath);
    final map = jsonDecode(raw);
    if (map is Map<String, dynamic>) {
      return CviConfig.fromJson(map, fromOfflineFallback: true);
    }
    return CviConfig.fromJson(
      Map<String, dynamic>.from(map as Map),
      fromOfflineFallback: true,
    );
  }
}
