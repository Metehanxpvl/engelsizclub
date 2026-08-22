import 'dart:convert';

import 'package:flutter/services.dart';

import 'cvi_discovery_models.dart';

abstract final class CviDiscoveryConfigLoader {
  static const _assetPath = 'assets/cvi/discovery/discovery_config.json';

  static Future<CviDiscoveryConfig> load() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('Geçersiz keşif yapılandırması');
    }
    return CviDiscoveryConfig.fromJson(Map<String, dynamic>.from(decoded));
  }
}
