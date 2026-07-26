import 'package:flutter/material.dart';

import '../data/rights_data.dart';
import '../services/app_catalog_service.dart';

/// Haklar / uzmanlık / merkez kategorilerini remote katalogdan okur;
/// boşsa yerel sabitlere düşer (offline güvenli).
class CatalogAdapters {
  CatalogAdapters._();

  static List<RightsCategory> rightsCategories() {
    final remote =
        AppCatalogService.instance.categoriesOf('rights');
    if (remote.isEmpty) return rightsCategoriesFallback;
    return [
      for (final r in remote)
        RightsCategory(
          id: r['id']?.toString() ?? '',
          label: r['label']?.toString() ?? '',
          icon: r['icon']?.toString() ?? '',
        ),
    ].where((c) => c.id.isNotEmpty).toList();
  }

  static List<String> uzmanlikSecenekleri() {
    final remote =
        AppCatalogService.instance.categoriesOf('uzmanlik');
    if (remote.isEmpty) {
      return const [
        'Fizyoterapist',
        'Ergoterapist',
        'Dil Konuşma Terapisti',
        'Özel Eğitim Öğretmeni',
        'Psikolog',
      ];
    }
    return [
      for (final r in remote) r['label']?.toString() ?? r['id']?.toString() ?? '',
    ].where((e) => e.isNotEmpty).toList();
  }

  static List<String> centerFilterLabels() {
    final remote =
        AppCatalogService.instance.categoriesOf('centers');
    if (remote.isEmpty) {
      return const ['Tümü', 'Fizik Tedavi', 'Özel Eğitim', 'Dil Terapisi', 'Nöroloji'];
    }
    return [
      for (final r in remote) r['label']?.toString() ?? '',
    ].where((e) => e.isNotEmpty).toList();
  }

  static List<RightItem> rightsItems() {
    final rows = AppCatalogService.instance.list(CatalogPack.rights);
    if (rows.isEmpty) return allRights;
    return [
      for (final r in rows) _rightFromRow(r),
    ];
  }

  static RightItem _rightFromRow(Map<String, dynamic> r) {
    final stepsRaw = r['steps'];
    final steps = <String>[];
    if (stepsRaw is List) {
      for (final s in stepsRaw) {
        final t = s.toString().trim();
        if (t.isNotEmpty) steps.add(t);
      }
    }
    return RightItem(
      id: r['id']?.toString() ?? '',
      title: r['title']?.toString() ?? '',
      amount: r['amount']?.toString() ?? '',
      category: r['category']?.toString() ?? 'maddi',
      icon: r['icon']?.toString() ?? '',
      color: Color((r['color'] as num?)?.toInt() ?? 0xFF1A6B4A),
      bg: Color((r['bg'] as num?)?.toInt() ?? 0xFFE8F5EE),
      minRate: (r['min_rate'] as num?)?.toInt() ?? 0,
      maxAge: (r['max_age'] as num?)?.toInt() ?? 99,
      incomeLimit: r['income_limit'] == true,
      desc: r['description']?.toString() ?? '',
      steps: steps,
      where: r['where_text']?.toString() ?? '',
    );
  }
}

/// Yerel sabitler — remote boşken.
const rightsCategoriesFallback = rightsCategories;
