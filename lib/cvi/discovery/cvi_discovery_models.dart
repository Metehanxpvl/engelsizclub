import 'package:flutter/material.dart';

/// Tek bir keşif görseli. [asset] yerel dosya; [url] isteğe bağlı uzak görsel.
class CviDiscoveryItem {
  const CviDiscoveryItem({
    required this.asset,
    this.url,
    this.label = '',
  });

  final String asset;
  final String? url;
  final String label;

  bool get hasRemote => url != null && url!.trim().isNotEmpty;

  factory CviDiscoveryItem.fromJson(Map<String, dynamic> json) {
    return CviDiscoveryItem(
      asset: json['asset']?.toString() ?? '',
      url: json['url']?.toString(),
      label: json['label']?.toString() ?? '',
    );
  }
}

class CviDiscoveryCategory {
  const CviDiscoveryCategory({
    required this.id,
    required this.label,
    required this.buttonColor,
    required this.textColor,
    required this.sound,
    required this.items,
  });

  final String id;
  final String label;
  final Color buttonColor;
  final Color textColor;
  /// `pop` veya `motor`
  final String sound;
  final List<CviDiscoveryItem> items;

  factory CviDiscoveryCategory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => CviDiscoveryItem.fromJson(Map<String, dynamic>.from(e)))
            .where((i) => i.hasRemote || i.asset.isNotEmpty)
            .toList()
        : <CviDiscoveryItem>[];

    return CviDiscoveryCategory(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      buttonColor: _parseColor(json['buttonColor']?.toString(), const Color(0xFFFFEA00)),
      textColor: _parseColor(json['textColor']?.toString(), Colors.white),
      sound: json['sound']?.toString() ?? 'pop',
      items: items,
    );
  }
}

class CviDiscoveryConfig {
  const CviDiscoveryConfig({
    required this.title,
    required this.categories,
  });

  final String title;
  final List<CviDiscoveryCategory> categories;

  factory CviDiscoveryConfig.fromJson(Map<String, dynamic> json) {
    final raw = json['categories'];
    final categories = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => CviDiscoveryCategory.fromJson(Map<String, dynamic>.from(e)))
            .where((c) => c.id.isNotEmpty && c.items.isNotEmpty)
            .toList()
        : <CviDiscoveryCategory>[];

    return CviDiscoveryConfig(
      title: json['title']?.toString() ?? 'Görsel Keşif',
      categories: categories,
    );
  }
}

Color _parseColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  var s = hex.trim();
  if (s.startsWith('#')) s = s.substring(1);
  if (s.length == 6) s = 'FF$s';
  final v = int.tryParse(s, radix: 16);
  if (v == null) return fallback;
  return Color(v);
}
