import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/rights_data.dart';
import 'services/app_catalog_service.dart';

String rightsSlugFromTitle(String title) {
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
  if (s.isEmpty) s = 'hak-${DateTime.now().millisecondsSinceEpoch}';
  return s.length > 64 ? s.substring(0, 64) : s;
}

Map<String, dynamic> rightToRow(
  RightItem r, {
  int sortOrder = 0,
  bool active = true,
}) {
  return {
    'id': r.id,
    'title': r.title.trim(),
    'amount': r.amount.trim(),
    'category': r.category.trim().isEmpty ? 'maddi' : r.category.trim(),
    'icon': r.icon.trim().isEmpty ? '📋' : r.icon.trim(),
    'color': r.color.toARGB32(),
    'bg': r.bg.toARGB32(),
    'min_rate': r.minRate,
    'max_age': r.maxAge,
    'income_limit': r.incomeLimit,
    'description': r.desc.trim(),
    'steps': r.steps,
    'where_text': r.where.trim(),
    'sort_order': sortOrder,
    'active': active,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
}

Future<RightItem> upsertAppRight(
  RightItem item, {
  int? sortOrder,
  bool active = true,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  if (!isAppAdmin(user.email)) throw StateError('Yalnızca admin düzenleyebilir.');
  final id = item.id.trim();
  if (id.isEmpty) throw StateError('Geçersiz hak kimliği.');
  if (item.title.trim().isEmpty) throw StateError('Başlık gerekli.');

  final existing = AppCatalogService.instance.list(CatalogPack.rights);
  var order = sortOrder ?? existing.length;
  if (sortOrder == null) {
    for (final e in existing) {
      if (e['id']?.toString() == id) {
        order = (e['sort_order'] as num?)?.toInt() ?? 0;
        break;
      }
    }
  }

  final payload = rightToRow(item, sortOrder: order, active: active);
  final row = Map<String, dynamic>.from(
    await Supabase.instance.client
        .from('app_rights')
        .upsert(payload)
        .select()
        .single(),
  );
  await AppCatalogService.instance.replaceRightRow(row);
  return item;
}

Future<void> deleteAppRight(String id, {bool hard = false}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  if (!isAppAdmin(user.email)) throw StateError('Yalnızca admin silebilir.');
  final key = id.trim();
  if (key.isEmpty) return;

  if (hard) {
    await Supabase.instance.client.from('app_rights').delete().eq('id', key);
  } else {
    await Supabase.instance.client.from('app_rights').update({
      'active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', key);
  }
  await AppCatalogService.instance.removeRightRow(key);
}

Future<List<Map<String, dynamic>>> loadRightsForAdmin() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || !isAppAdmin(user.email)) return const [];
  final rows = await Supabase.instance.client
      .from('app_rights')
      .select()
      .order('sort_order');
  return [
    for (final r in (rows as List))
      if (r is Map) Map<String, dynamic>.from(r),
  ];
}

Future<List<Map<String, dynamic>>> loadRightsCategoriesForAdmin() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || !isAppAdmin(user.email)) return const [];
  final rows = await Supabase.instance.client
      .from('app_categories')
      .select()
      .eq('scope', 'rights')
      .order('sort_order');
  return [
    for (final r in (rows as List))
      if (r is Map) Map<String, dynamic>.from(r),
  ];
}

Future<void> upsertRightsCategory({
  required String id,
  required String label,
  required String icon,
  int? sortOrder,
  bool active = true,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  if (!isAppAdmin(user.email)) throw StateError('Yalnızca admin düzenleyebilir.');
  final key = id.trim().toLowerCase();
  if (key.isEmpty) throw StateError('Kategori kimliği gerekli.');
  if (label.trim().isEmpty) throw StateError('Kategori adı gerekli.');

  final existing = AppCatalogService.instance.categoriesOf('rights');
  var order = sortOrder ?? existing.length;
  if (sortOrder == null) {
    for (final e in existing) {
      if (e['id']?.toString() == key) {
        order = (e['sort_order'] as num?)?.toInt() ?? 0;
        break;
      }
    }
  }

  final payload = {
    'id': key,
    'scope': 'rights',
    'label': label.trim(),
    'icon': icon.trim().isEmpty ? '📁' : icon.trim(),
    'sort_order': order,
    'active': active,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  final row = Map<String, dynamic>.from(
    await Supabase.instance.client
        .from('app_categories')
        .upsert(payload)
        .select()
        .single(),
  );
  await AppCatalogService.instance.replaceCategoryRow(row);
}

Future<void> deleteRightsCategory(String id, {bool hard = false}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  if (!isAppAdmin(user.email)) throw StateError('Yalnızca admin silebilir.');
  final key = id.trim();
  if (key.isEmpty || key == 'tümü') {
    throw StateError('"Tümü" kategorisi silinemez.');
  }

  if (hard) {
    await Supabase.instance.client
        .from('app_categories')
        .delete()
        .eq('id', key)
        .eq('scope', 'rights');
  } else {
    await Supabase.instance.client.from('app_categories').update({
      'active': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', key).eq('scope', 'rights');
  }
  await AppCatalogService.instance.removeCategoryRow(key);
}

RightItem emptyRightItem({String category = 'maddi'}) {
  return RightItem(
    id: '',
    title: '',
    amount: '',
    category: category,
    icon: '📋',
    color: const Color(0xFF1A6B4A),
    bg: const Color(0xFFE8F5EE),
    minRate: 0,
    maxAge: 99,
    incomeLimit: false,
    desc: '',
    steps: const [],
    where: '',
  );
}
