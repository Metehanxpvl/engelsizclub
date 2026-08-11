import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/condition_data.dart';
import 'data/diseases_data.dart';

List<ConditionItem>? _conditionMemoryCache;
DateTime? _conditionCacheAt;
const _conditionCacheTtl = Duration(minutes: 10);

List<ConditionItem>? get cachedConditions => _conditionMemoryCache;

bool get hasFreshConditionCache {
  final at = _conditionCacheAt;
  final list = _conditionMemoryCache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _conditionCacheTtl;
}

void invalidateConditionCache() {
  _conditionMemoryCache = null;
  _conditionCacheAt = null;
}

void _setConditionCache(List<ConditionItem> items) {
  _conditionMemoryCache = List<ConditionItem>.unmodifiable(items);
  _conditionCacheAt = DateTime.now();
}

ConditionItem conditionFromRow(Map<String, dynamic> json) =>
    ConditionItem.fromRow(json);

Map<String, dynamic> _detailPayload({
  String catalogId = '',
  String icon = '🩺',
  List<String> symptoms = const [],
  String diagnosis = '',
  List<String> support = const [],
  List<FaqItem> faq = const [],
}) =>
    {
      'catalog_id': catalogId.trim(),
      'icon': icon.trim().isEmpty ? '🩺' : icon.trim(),
      'symptoms': symptoms,
      'diagnosis': diagnosis.trim(),
      'support': support,
      'faq': [
        for (final f in faq) {'q': f.q, 'a': f.a},
      ],
    };

/// Admin tüm kayıtları görür; diğerleri yalnız aktifleri.
Future<List<ConditionItem>> loadConditions({
  bool forceRefresh = false,
  String? viewerEmail,
}) async {
  if (!forceRefresh && hasFreshConditionCache) {
    final cached = List<ConditionItem>.from(_conditionMemoryCache!);
    if (isAppAdmin(viewerEmail)) return cached;
    return cached.where((c) => c.isActive).toList();
  }
  try {
    final rows = await Supabase.instance.client
        .from('conditions')
        .select()
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false)
        .limit(100);
    final list = [
      for (final e in (rows as List).whereType<Map>())
        conditionFromRow(Map<String, dynamic>.from(e)),
    ].where((c) => c.id > 0 && c.title.isNotEmpty).toList();
    _setConditionCache(list);
    if (isAppAdmin(viewerEmail)) return list;
    return list.where((c) => c.isActive).toList();
  } catch (_) {
    if (_conditionMemoryCache != null) {
      final cached = List<ConditionItem>.from(_conditionMemoryCache!);
      if (isAppAdmin(viewerEmail)) return cached;
      return cached.where((c) => c.isActive).toList();
    }
    return const [];
  }
}

Future<ConditionItem> addCondition({
  required String title,
  required String imageUrl,
  required String description,
  required String adminEmail,
  bool isActive = true,
  int? sortOrder,
  String catalogId = '',
  String icon = '🩺',
  List<String> symptoms = const [],
  String diagnosis = '',
  List<String> support = const [],
  List<FaqItem> faq = const [],
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  final t = title.trim();
  if (t.isEmpty) throw StateError('Başlık gerekli.');

  final prev = _conditionMemoryCache ?? const <ConditionItem>[];
  final nextOrder = sortOrder ??
      (prev.isEmpty
          ? 0
          : prev.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1);

  final payload = <String, dynamic>{
    'title': t,
    'image_url': imageUrl.trim(),
    'description': description.trim(),
    'is_active': isActive,
    'sort_order': nextOrder,
    'created_by': adminEmail.trim().toLowerCase(),
    ..._detailPayload(
      catalogId: catalogId,
      icon: icon,
      symptoms: symptoms,
      diagnosis: diagnosis,
      support: support,
      faq: faq,
    ),
  };

  final row = Map<String, dynamic>.from(
    await client.from('conditions').insert(payload).select().single(),
  );
  final item = conditionFromRow(row);
  _setConditionCache([item, ...prev.where((c) => c.id != item.id)]);
  return item;
}

Future<ConditionItem> updateCondition({
  required int id,
  required String title,
  required String imageUrl,
  required String description,
  bool isActive = true,
  int? sortOrder,
  String? catalogId,
  String? icon,
  List<String>? symptoms,
  String? diagnosis,
  List<String>? support,
  List<FaqItem>? faq,
}) async {
  if (id <= 0) throw StateError('Geçersiz kayıt.');
  final t = title.trim();
  if (t.isEmpty) throw StateError('Başlık gerekli.');

  final payload = <String, dynamic>{
    'title': t,
    'image_url': imageUrl.trim(),
    'description': description.trim(),
    'is_active': isActive,
    if (sortOrder != null) 'sort_order': sortOrder,
    if (catalogId != null) 'catalog_id': catalogId.trim(),
    if (icon != null) 'icon': icon.trim().isEmpty ? '🩺' : icon.trim(),
    if (symptoms != null) 'symptoms': symptoms,
    if (diagnosis != null) 'diagnosis': diagnosis.trim(),
    if (support != null) 'support': support,
    if (faq != null)
      'faq': [
        for (final f in faq) {'q': f.q, 'a': f.a},
      ],
  };

  final row = Map<String, dynamic>.from(
    await Supabase.instance.client
        .from('conditions')
        .update(payload)
        .eq('id', id)
        .select()
        .single(),
  );
  final item = conditionFromRow(row);
  final prev = _conditionMemoryCache ?? const <ConditionItem>[];
  _setConditionCache([
    for (final c in prev)
      if (c.id == id) item else c,
  ]);
  if (!prev.any((c) => c.id == id)) {
    _setConditionCache([item, ...prev]);
  }
  return item;
}

Future<void> deleteCondition(int id) async {
  if (id <= 0) return;
  await Supabase.instance.client.from('conditions').delete().eq('id', id);
  final prev = _conditionMemoryCache;
  if (prev != null) {
    _setConditionCache(prev.where((c) => c.id != id).toList());
  }
}

bool _conditionCoversDisease(ConditionItem c, DiseaseInfo d) {
  final cid = c.catalogId.trim().toLowerCase();
  if (cid.isNotEmpty && cid == d.id.trim().toLowerCase()) return true;
  return c.title.trim().toLowerCase() == d.name.trim().toLowerCase();
}

/// Katalogdaki (yerel/app_diseases) kutular `conditions` tablosunda yoksa ekler.
/// Yeni kart eklenince eski kutuların kaybolmasını önler; admin sürükle-bırak için gerekir.
Future<List<ConditionItem>> ensureCatalogConditionsSeeded({
  required String adminEmail,
  required List<DiseaseInfo> catalog,
}) async {
  final email = adminEmail.trim();
  if (email.isEmpty || catalog.isEmpty) {
    return loadConditions(forceRefresh: true, viewerEmail: adminEmail);
  }

  final existing = await loadConditions(
    forceRefresh: true,
    viewerEmail: adminEmail,
  );
  final missing = <DiseaseInfo>[
    for (final d in catalog)
      if (!existing.any((c) => _conditionCoversDisease(c, d))) d,
  ];
  if (missing.isEmpty) return existing;

  var nextOrder = existing.isEmpty
      ? 0
      : existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

  for (final d in missing) {
    await addCondition(
      title: d.name,
      imageUrl: d.photo ?? '',
      description: d.desc,
      adminEmail: email,
      isActive: true,
      sortOrder: nextOrder++,
      catalogId: d.id,
      icon: d.icon,
      symptoms: d.symptoms,
      diagnosis: d.diagnosis,
      support: d.support,
      faq: d.faq,
    );
  }

  return loadConditions(forceRefresh: true, viewerEmail: adminEmail);
}

/// Aktif kartların yeni sırasını `sort_order` olarak yazar (0..n-1).
Future<void> reorderConditions(List<ConditionItem> ordered) async {
  if (ordered.isEmpty) return;
  final client = Supabase.instance.client;
  final withOrder = <ConditionItem>[
    for (var i = 0; i < ordered.length; i++)
      ordered[i].copyWith(sortOrder: i),
  ];

  await Future.wait([
    for (final c in withOrder)
      client.from('conditions').update({'sort_order': c.sortOrder}).eq('id', c.id),
  ]);

  final prev = List<ConditionItem>.from(
    _conditionMemoryCache ?? const <ConditionItem>[],
  );
  final byId = {for (final c in withOrder) c.id: c};
  final merged = [
    for (final c in prev) byId[c.id] ?? c,
  ];
  for (final c in withOrder) {
    if (!merged.any((e) => e.id == c.id)) merged.add(c);
  }
  merged.sort((a, b) {
    final o = a.sortOrder.compareTo(b.sortOrder);
    if (o != 0) return o;
    return b.createdAt.compareTo(a.createdAt);
  });
  _setConditionCache(merged);
}
