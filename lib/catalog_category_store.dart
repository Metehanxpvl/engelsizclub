import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_catalog_extras.dart';
import 'admin_config.dart';
import 'data/ilanlar_data.dart';
import 'services/app_catalog_service.dart';
import 'services/catalog_adapters.dart';

String catalogOptionSlug(String title, {String prefix = ''}) {
  const map = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'Ç': 'c',
    'Ğ': 'g',
    'İ': 'i',
    'Ö': 'o',
    'Ş': 's',
    'Ü': 'u',
  };
  var s = title.trim().toLowerCase();
  map.forEach((k, v) => s = s.replaceAll(k.toLowerCase(), v));
  s = s
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (s.isEmpty) s = 'opt-${DateTime.now().millisecondsSinceEpoch}';
  final withPrefix = prefix.isEmpty ? s : '$prefix-$s';
  return withPrefix.length > 64 ? withPrefix.substring(0, 64) : withPrefix;
}

Map<String, dynamic>? _rowFromDynamic(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.trim().startsWith('{')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return null;
}

typedef CatalogDeleteResult = ({
  bool synced,
  String? warning,
});

typedef CatalogOptionRef = ({String id, String label});

const _ilanBuiltinLabels = <String>{
  'uzman arıyorum',
  'bakıcı/temizlik görevlisi arıyorum',
  '2. el alet',
};

bool isBuiltinCatalogOption(String scope, String label) {
  final l = label.trim().toLowerCase();
  if (l.isEmpty) return true;
  switch (scope) {
    case 'uzmanlik':
      return kUzmanlikSecenekleri.any((e) => e.toLowerCase() == l);
    case 'ikinciel':
      return kIkincielAltKategoriler.any((e) => e.toLowerCase() == l);
    case 'ilan':
      return _ilanBuiltinLabels.contains(l);
    default:
      return false;
  }
}

String? _categoryIdForLabel(String scope, String label) {
  final target = label.trim().toLowerCase();
  for (final row in AppCatalogService.instance.categoriesOf(scope)) {
    final rowLabel = (row['label']?.toString() ?? '').trim().toLowerCase();
    if (rowLabel == target) return row['id']?.toString();
  }
  return null;
}

/// Admin'in silebileceği özel seçenekler (sabitler hariç — UI'da görünenler).
List<CatalogOptionRef> deletableCatalogOptions(String scope) {
  final out = <CatalogOptionRef>[];
  final seen = <String>{};

  void push(String label) {
    final name = label.trim();
    if (name.isEmpty || isBuiltinCatalogOption(scope, name)) return;
    if (AdminCatalogExtras.instance.isRemoved(scope, name)) return;
    if (!seen.add(name.toLowerCase())) return;
    out.add((
      id: _categoryIdForLabel(scope, name) ??
          catalogOptionSlug(name, prefix: scope),
      label: name,
    ));
  }

  switch (scope) {
    case 'ilan':
      for (final o in CatalogAdapters.ilanFormKategorileri()) {
        if (!o.builtin) push(o.value);
      }
    case 'uzmanlik':
      for (final label in CatalogAdapters.uzmanlikSecenekleri()) {
        push(label);
      }
    case 'ikinciel':
      for (final label in CatalogAdapters.ikincielAltKategoriler()) {
        push(label);
      }
    default:
      for (final row in AppCatalogService.instance.categoriesOf(scope)) {
        push(row['label']?.toString() ?? '');
      }
      for (final label in AdminCatalogExtras.instance.labelsFor(scope)) {
        push(label);
      }
  }

  out.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return out;
}

Future<bool> _deleteCategoryRow(String id, String scope) async {
  final client = Supabase.instance.client;
  try {
    await client.rpc(
      'admin_delete_app_category',
      params: {'p_id': id, 'p_scope': scope},
    );
    return true;
  } on PostgrestException catch (e) {
    if (e.code != '42883' &&
        !e.message.contains('Could not find') &&
        !e.message.contains('category not found')) {
      // RPC var ama başka hata — doğrudan güncellemeyi dene
    }
  } catch (_) {}

  try {
    final res = await client.functions.invoke(
      'admin-catalog',
      body: {'action': 'delete', 'id': id, 'scope': scope},
    );
    if (res.status >= 200 && res.status < 300) return true;
  } catch (_) {}

  try {
    await client.from('app_categories').update({
      'active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('scope', scope);
    return true;
  } catch (_) {
    return false;
  }
}

/// Admin: özel katalog seçeneğini kaldırır (soft delete + yerel gizleme).
Future<CatalogDeleteResult> deleteCatalogOption({
  required String scope,
  required String label,
  String? id,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  if (!isAppAdmin(user.email)) {
    throw StateError('Yalnızca admin seçenek silebilir.');
  }
  final name = label.trim();
  if (name.isEmpty) throw StateError('Ad gerekli.');
  if (isBuiltinCatalogOption(scope, name)) {
    throw StateError('Bu seçenek sabittir; silinemez.');
  }

  final catId =
      id ?? _categoryIdForLabel(scope, name) ?? catalogOptionSlug(name, prefix: scope);

  // Önce yerel gizle — sync gelse bile listede görünmez
  await AdminCatalogExtras.instance.markRemoved(scope, name);
  await AppCatalogService.instance.removeCategoryRow(catId);

  final synced = await _deleteCategoryRow(catId, scope);
  return (
    synced: synced,
    warning: synced ? null : 'Buluttan silinemedi; listeden gizlendi.',
  );
}

void showCatalogDeleteSnackBar(
  BuildContext context,
  CatalogDeleteResult result, {
  required String successText,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result.warning == null
            ? successText
            : '$successText (${result.warning})',
      ),
      backgroundColor: result.warning == null ? null : const Color(0xFF92400E),
    ),
  );
}

Future<CatalogOptionRef?> promptAdminRemoveOption({
  required BuildContext context,
  required String scope,
  required String title,
}) async {
  final options = deletableCatalogOptions(scope);
  if (options.isEmpty) return null;
  return showDialog<CatalogOptionRef>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final opt in options)
              ListTile(
                title: Text(opt.label),
                trailing: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
                onTap: () => Navigator.pop(ctx, opt),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Vazgeç'),
        ),
      ],
    ),
  );
}

typedef CatalogUpsertResult = ({
  Map<String, dynamic> row,
  bool synced,
  String? warning,
});

String _catalogUpsertError(Object e) {
  final msg = e.toString();
  if (msg.contains('app_catalog_versions') && msg.contains('42501')) {
    return 'Katalog RLS hatası. Edge function admin-catalog deploy edilmeli '
        'veya Supabase’de admin_catalog_category.sql çalıştırın.';
  }
  if (msg.contains('not allowed') ||
      msg.contains('42883') ||
      msg.contains('admin-catalog')) {
    return 'Admin katalog servisi yok. Terminalde: '
        'supabase functions deploy admin-catalog';
  }
  return 'Eklenemedi: $e';
}

Future<Map<String, dynamic>> _upsertCategoryRow(
  Map<String, dynamic> payload,
) async {
  final client = Supabase.instance.client;
  final id = payload['id']?.toString() ?? '';
  final scope = payload['scope']?.toString() ?? '';
  final label = payload['label']?.toString() ?? '';

  // 1) RPC (varsa)
  try {
    final meta = payload['meta'];
    final raw = await client.rpc(
      'admin_upsert_app_category',
      params: {
        'p_id': id,
        'p_scope': scope,
        'p_label': label,
        'p_icon': payload['icon']?.toString() ?? '',
        'p_sort_order': (payload['sort_order'] as num?)?.toInt() ?? 0,
        'p_meta': meta is Map
            ? Map<String, dynamic>.from(meta)
            : <String, dynamic>{},
      },
    );
    final row = _rowFromDynamic(raw);
    if (row != null) return row;
  } on PostgrestException catch (e) {
    if (e.code != '42883' && !e.message.contains('Could not find')) {
      rethrow;
    }
  }

  // 2) Edge function (deploy edilmişse — yoksa sessizce atla)
  try {
    final res = await client.functions.invoke(
      'admin-catalog',
      body: {
        'id': id,
        'scope': scope,
        'label': label,
        'icon': payload['icon']?.toString() ?? '',
        'sort_order': (payload['sort_order'] as num?)?.toInt() ?? 0,
        'meta': payload['meta'] is Map
            ? Map<String, dynamic>.from(payload['meta'] as Map)
            : <String, dynamic>{},
      },
    );
    if (res.status >= 200 && res.status < 300) {
      final data = res.data;
      if (data is Map && data['row'] is Map) {
        return Map<String, dynamic>.from(data['row'] as Map);
      }
      final row = _rowFromDynamic(data);
      if (row != null) return row;
    }
  } catch (_) {
    // Deploy edilmemiş / ağ hatası
  }

  // 3) Doğrudan upsert (SQL fix sonrası)
  return Map<String, dynamic>.from(
    await client.from('app_categories').upsert(payload).select().single(),
  );
}

void showCatalogUpsertSnackBar(
  BuildContext context,
  CatalogUpsertResult result, {
  required String successText,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        result.synced
            ? successText
            : '$successText (Yalnızca bu cihazda — ${result.warning ?? 'buluta kaydedilemedi'})',
      ),
      backgroundColor: result.synced ? null : const Color(0xFF92400E),
    ),
  );
}

/// Admin: `app_categories` satırı ekler / günceller (uzmanlık, ilan, 2. el alt).
Future<CatalogUpsertResult> upsertCatalogOption({
  required String scope,
  required String label,
  String icon = '',
  Map<String, dynamic>? meta,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  if (!isAppAdmin(user.email)) {
    throw StateError('Yalnızca admin yeni seçenek ekleyebilir.');
  }
  final name = label.trim();
  if (name.isEmpty) throw StateError('Ad gerekli.');
  if (name.length > 48) throw StateError('Ad en fazla 48 karakter olabilir.');

  final existing = AppCatalogService.instance.categoriesOf(scope);
  for (final e in existing) {
    final current = (e['label']?.toString() ?? '').trim();
    if (current.toLowerCase() == name.toLowerCase()) {
      return (
        row: Map<String, dynamic>.from(e),
        synced: true,
        warning: null,
      );
    }
  }
  for (final extra in AdminCatalogExtras.instance.labelsFor(scope)) {
    if (extra.toLowerCase() == name.toLowerCase()) {
      return (
        row: <String, dynamic>{
          'id': catalogOptionSlug(name, prefix: scope),
          'scope': scope,
          'label': extra,
          'meta': meta ?? const <String, dynamic>{},
        },
        synced: false,
        warning: null,
      );
    }
  }

  var order = existing.length + 10;
  for (final e in existing) {
    final n = (e['sort_order'] as num?)?.toInt() ?? 0;
    if (n >= order) order = n + 1;
  }

  final payload = <String, dynamic>{
    'id': catalogOptionSlug(name, prefix: scope),
    'scope': scope,
    'label': name,
    'icon': icon.trim(),
    'sort_order': order,
    'active': true,
    'meta': meta ?? const <String, dynamic>{},
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  try {
    final row = await _upsertCategoryRow(payload);
    await AppCatalogService.instance.replaceCategoryRow(row);
    await AdminCatalogExtras.instance.addLabel(scope, name);
    return (row: row, synced: true, warning: null);
  } catch (e) {
    // Bulut başarısız — en azından admin cihazında seçenek görünsün
    await AdminCatalogExtras.instance.addLabel(scope, name);
    await AppCatalogService.instance.replaceCategoryRow(payload);
    return (
      row: payload,
      synced: false,
      warning: _catalogUpsertError(e),
    );
  }
}

Future<String?> promptAdminNewOption({
  required BuildContext context,
  required String title,
  String hint = 'Yeni seçenek adı',
}) async {
  final ctrl = TextEditingController();
  final added = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Ekle'),
        ),
      ],
    ),
  );
  ctrl.dispose();
  final name = (added ?? '').trim();
  return name.isEmpty ? null : name;
}

Future<({String label, String kind})?> promptAdminNewIlanKategori(
  BuildContext context,
) async {
  final ctrl = TextEditingController();
  var kind = 'uzman';
  final added = await showDialog<({String label, String kind})>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Yeni ilan kategorisi'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Örn. Kiralık cihaz',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hangi sekmede görünsün?',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  for (final opt in const [
                    ('uzman', 'Uzman Ara'),
                    ('bakici', 'Bakıcı/Temizlik'),
                    ('ikinciel', '2. El Aletler'),
                  ])
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(opt.$2),
                      value: opt.$1,
                      groupValue: kind,
                      onChanged: (v) {
                        if (v != null) setLocal(() => kind = v);
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () {
                  final name = ctrl.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx, (label: name, kind: kind));
                },
                child: const Text('Ekle'),
              ),
            ],
          );
        },
      );
    },
  );
  ctrl.dispose();
  return added;
}
