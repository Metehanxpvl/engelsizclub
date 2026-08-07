import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/cards_data.dart';
import '../data/diseases_data.dart';
import '../data/rights_data.dart';
import '../services/app_catalog_service.dart';

/// Forum chip / dropdown sırası (kullanıcı tercihi).
const _forumDiseaseOrder = <String>[
  'Serebral Palsi',
  'Otizm',
  'Down Sendromu',
  'SMA',
  'DEHB',
  'Gelişim Geriliği',
  'Duyu Bütünleme',
  'İletişim Bozuklukları',
  'Nadir Hastalıklar',
];

/// Forum paylaşım / filtre kategorileri — ana sayfa hastalıkları + genel + köşe.
List<String> forumDiseaseCategoryLabels() {
  final short = <String>[
    for (final d in CatalogAdapters.diseases())
      d.name
          .replaceFirst('Otizm Spektrum Bozukluğu', 'Otizm')
          .replaceFirst('SMA (Spinal Müsküler Atrofi)', 'SMA')
          .replaceFirst('Duyu Bütünleme Sorunları', 'Duyu Bütünleme'),
  ];
  final seen = <String>{};
  final ordered = <String>[];
  for (final preferred in _forumDiseaseOrder) {
    final hit = short.where((n) => n == preferred).toList();
    for (final n in hit) {
      if (seen.add(n)) ordered.add(n);
    }
  }
  for (final n in short) {
    if (seen.add(n)) ordered.add(n);
  }
  return ordered;
}

/// Haklar / uzmanlık / merkez / hastalık / kart / forum — remote katalog;
/// boşsa yerel sabitlere düşer (offline + store sürümü güvenli).
class CatalogAdapters {
  CatalogAdapters._();

  /// Store build’inde demo ilanları gizle: `app_settings.show_demo_ilanlar = false`
  static bool showDemoIlanlar() {
    final v = AppCatalogService.instance.setting('show_demo_ilanlar', true);
    if (v is bool) return v;
    if (v is Map && v['value'] is bool) return v['value'] as bool;
    final s = v?.toString().toLowerCase();
    if (s == 'false' || s == '0') return false;
    return true;
  }

  static List<RightsCategory> rightsCategories() {
    final remote = AppCatalogService.instance.categoriesOf('rights');
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
    final remote = AppCatalogService.instance.categoriesOf('uzmanlik');
    if (remote.isEmpty) {
      return const [
        'Fizyoterapist',
        'Ergoterapist',
        'Dil Konuşma Terapisti',
        'Özel Eğitim Öğretmeni',
        'Gölge Öğretmen',
        'Psikolog',
      ];
    }
    return [
      for (final r in remote) r['label']?.toString() ?? r['id']?.toString() ?? '',
    ].where((e) => e.isNotEmpty).toList();
  }

  static List<String> centerFilterLabels() {
    final remote = AppCatalogService.instance.categoriesOf('centers');
    if (remote.isEmpty) {
      return const [
        'Tümü',
        'Özel Eğitim',
        'Fizik Tedavi',
        'Medikal',
      ];
    }
    return [
      for (final r in remote) r['label']?.toString() ?? '',
    ].where((e) => e.isNotEmpty).toList();
  }

  static List<String> forumFeedCategories() {
    final cats = <String>[
      'Tümü',
      ...forumDiseaseCategoryLabels(),
      'Genel Konular',
      'Köşe Yazısı',
      'Doktor',
    ];
    final seen = <String>{};
    return [
      for (final c in cats)
        if (seen.add(c.toLowerCase())) c,
    ];
  }

  static List<String> forumPostCategories() {
    return [
      ...forumDiseaseCategoryLabels(),
      'Genel Konular',
      'Köşe Yazısı',
    ];
  }

  static List<RightItem> rightsItems() {
    final rows = AppCatalogService.instance.list(CatalogPack.rights);
    if (rows.isEmpty) return allRights;
    return [for (final r in rows) _rightFromRow(r)];
  }

  static List<DiseaseInfo> diseases() {
    final rows = AppCatalogService.instance.list(CatalogPack.diseases);
    if (rows.isEmpty) return kDiseases;
    final mapped = <DiseaseInfo>[
      for (final r in rows) _diseaseFromRow(r),
    ].where((d) => d.id.isNotEmpty).toList();
    return mapped.isEmpty ? kDiseases : mapped;
  }

  static List<NeedCard> needCards() {
    final rows = AppCatalogService.instance
        .list(CatalogPack.content)
        .where((e) => (e['scope']?.toString() ?? '') == 'cards')
        .toList()
      ..sort((a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
          .compareTo((b['sort_order'] as num?)?.toInt() ?? 0));
    if (rows.isEmpty) return kNeedCards;
    final mapped = <NeedCard>[
      for (final r in rows) _cardFromContent(r),
    ].where((c) => c.id > 0 && c.label.isNotEmpty).toList();
    return mapped.isEmpty ? kNeedCards : mapped;
  }

  static RightItem _rightFromRow(Map<String, dynamic> r) {
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
      steps: _stepsFrom(r['steps']),
      where: r['where_text']?.toString() ?? '',
    );
  }

  /// Katalogdan gelen steps: dizi, JSON string veya satır ayrılmış metin.
  /// Karakter karakter parçalanmış bozuk dizileri de toparlar.
  static List<String> _stepsFrom(dynamic raw) {
    if (raw == null) return const [];
    var items = <String>[];
    if (raw is List) {
      for (final s in raw) {
        final t = s.toString().trim();
        if (t.isNotEmpty) items.add(t);
      }
    } else if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return const [];
      if (t.startsWith('[')) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is List) return _stepsFrom(decoded);
        } catch (_) {}
      }
      items = t
          .split(RegExp(r'\n+|\r+|;'))
          .map((e) => e.replaceFirst(RegExp(r'^[\s•\-\d.)]+'), '').trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    // Bozuk import: her öğe tek karakter → birleştirip satıra böl
    if (items.length > 6 && items.every((e) => e.length <= 1)) {
      final joined = items.join();
      return joined
          .split(RegExp(r'\n+|;\s*|·\s*'))
          .map((e) => e.trim())
          .where((e) => e.length > 1)
          .toList();
    }
    return items;
  }

  static DiseaseInfo _diseaseFromRow(Map<String, dynamic> r) {
    final symptoms = _stringList(r['symptoms']);
    final support = _stringList(r['support']);
    final faq = <FaqItem>[];
    final faqRaw = r['faq'];
    if (faqRaw is List) {
      for (final item in faqRaw) {
        if (item is! Map) continue;
        final q = item['q']?.toString() ?? item['question']?.toString() ?? '';
        final a = item['a']?.toString() ?? item['answer']?.toString() ?? '';
        if (q.isNotEmpty) faq.add(FaqItem(q, a));
      }
    }
    final photo = r['photo']?.toString().trim();
    return DiseaseInfo(
      id: r['id']?.toString() ?? '',
      name: r['name']?.toString() ?? '',
      icon: r['icon']?.toString() ?? '',
      color: Color((r['color'] as num?)?.toInt() ?? 0xFF1A6B4A),
      bg: Color((r['bg'] as num?)?.toInt() ?? 0xFFE8F5EE),
      photo: (photo == null || photo.isEmpty) ? null : photo,
      desc: r['description']?.toString() ?? '',
      symptoms: symptoms,
      diagnosis: r['diagnosis']?.toString() ?? '',
      support: support,
      faq: faq,
    );
  }

  static NeedCard _cardFromContent(Map<String, dynamic> r) {
    final meta = r['meta'];
    final m = meta is Map
        ? Map<String, dynamic>.from(meta)
        : const <String, dynamic>{};
    final id = (m['id'] as num?)?.toInt() ??
        int.tryParse(
            r['id']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '') ??
        0;
    final colorVal = m['color'];
    final bgVal = m['bg'];
    Color color = const Color(0xFF1A6B4A);
    Color bg = const Color(0xFFE8F5EE);
    if (colorVal is num) {
      color = Color(colorVal.toInt());
    } else if (colorVal is String && colorVal.isNotEmpty) {
      color = colorFromHex(colorVal);
    }
    if (bgVal is num) {
      bg = Color(bgVal.toInt());
    } else if (bgVal is String && bgVal.isNotEmpty) {
      bg = colorFromHex(bgVal);
    }
    final photo = (r['media_url']?.toString().trim().isNotEmpty == true)
        ? r['media_url'].toString()
        : m['photo']?.toString();
    return NeedCard(
      id: id,
      label: r['title']?.toString() ?? '',
      emoji: m['emoji']?.toString() ?? '💬',
      color: color,
      bg: bg,
      category: m['category']?.toString() ?? 'genel',
      desc: r['body']?.toString(),
      photo: (photo == null || photo.isEmpty) ? null : photo,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is! List) return const [];
    return [
      for (final s in raw)
        if (s.toString().trim().isNotEmpty) s.toString().trim(),
    ];
  }
}

const rightsCategoriesFallback = rightsCategories;
