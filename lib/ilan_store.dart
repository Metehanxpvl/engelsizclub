import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/ilanlar_data.dart';
import 'meto_theme.dart';

/// İlan sahibi e-postası (id → email). Ortak listede "İlanlarım" için.
final Map<int, String> ilanOwnerById = <int, String>{};

String ilanPrefsKey(String email, {String fallback = 'anon'}) {
  final e = email.trim().toLowerCase();
  return 'user_ilanlar_${e.isEmpty ? fallback : e}';
}

String _relativePosted(DateTime? createdAt) {
  if (createdAt == null) return 'Az önce';
  final diff = DateTime.now().difference(createdAt.toLocal());
  if (diff.inMinutes < 1) return 'Az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} saat önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  return '${createdAt.day}.${createdAt.month}.${createdAt.year}';
}

Map<String, dynamic> _uzmanToJson(UzmanIlani i) => {
      'kind': 'uzman',
      'id': i.id,
      'title': i.title,
      'uzmanlik': i.uzmanlik,
      'tani': i.tani,
      'city': i.city,
      'district': i.district,
      'age': i.age,
      'frequency': i.frequency,
      'note': i.note,
      'budget': i.budget,
      'posted': i.posted,
      'views': i.views,
      'offers': i.offers,
      'urgent': i.urgent,
      'posterName': i.poster.name,
      'posterAvatar': i.poster.avatar,
      'ownerEmail': ilanOwnerById[i.id] ?? '',
    };

Map<String, dynamic> _bakiciToJson(BakiciIlani i) => {
      'kind': 'bakici',
      'id': i.id,
      'title': i.title,
      'city': i.city,
      'district': i.district,
      'tani': i.tani,
      'age': i.age,
      'hours': i.hours,
      'note': i.note,
      'budget': i.budget,
      'posted': i.posted,
      'views': i.views,
      'urgent': i.urgent,
      'posterName': i.poster.name,
      'posterAvatar': i.poster.avatar,
      'ownerEmail': ilanOwnerById[i.id] ?? '',
    };

Map<String, dynamic> _ikincielToJson(IkincielIlani i) => {
      'kind': 'ikinciel',
      'id': i.id,
      'title': i.title,
      'category': i.category,
      'city': i.city,
      'district': i.district,
      'condition': i.condition,
      'brand': i.brand,
      'note': i.note,
      'price': i.price,
      'originalPrice': i.originalPrice,
      'posted': i.posted,
      'views': i.views,
      'emoji': i.emoji,
      'photos': i.photos.map((c) => c.toARGB32()).toList(),
      'posterName': i.poster.name,
      'posterAvatar': i.poster.avatar,
      'ownerEmail': ilanOwnerById[i.id] ?? '',
    };

IlanPoster _posterFrom(Map<String, dynamic> j) {
  final name = (j['posterName'] ?? j['poster_name'])?.toString() ?? 'Siz';
  final avatar = (j['posterAvatar'] ?? j['poster_avatar'])?.toString();
  return IlanPoster(
    name: name,
    avatar: (avatar != null && avatar.isNotEmpty)
        ? avatar
        : (name.length >= 2
            ? name.substring(0, 2).toUpperCase()
            : name.toUpperCase()),
    avatarColor: MetoColors.primary,
    rating: 0,
    reviewCount: 0,
    bio: 'İlan sahibi',
    tags: const <String>[],
    reviews: const <IlanReview>[],
  );
}

UzmanIlani _uzmanFromJson(Map<String, dynamic> j) => UzmanIlani(
      id: (j['id'] as num?)?.toInt() ?? nextIlanId(),
      title: j['title']?.toString() ?? '',
      uzmanlik: (j['uzmanlik'] ?? 'Uzman').toString(),
      tani: (j['tani'] ?? 'Belirtilmedi').toString(),
      city: j['city']?.toString() ?? '',
      district: j['district']?.toString() ?? '',
      age: (j['age'] ?? 'Belirtilmedi').toString(),
      frequency: (j['frequency'] ?? 'Belirtilmedi').toString(),
      note: (j['note'] ?? '—').toString(),
      budget: (j['budget'] ?? '').toString(),
      posted: (j['posted'] ?? 'Az önce').toString(),
      views: (j['views'] as num?)?.toInt() ?? 0,
      offers: (j['offers'] as num?)?.toInt() ?? 0,
      urgent: j['urgent'] == true,
      poster: _posterFrom(j),
    );

BakiciIlani _bakiciFromJson(Map<String, dynamic> j) => BakiciIlani(
      id: (j['id'] as num?)?.toInt() ?? nextIlanId(),
      title: j['title']?.toString() ?? '',
      city: j['city']?.toString() ?? '',
      district: j['district']?.toString() ?? '',
      tani: (j['tani'] ?? 'Belirtilmedi').toString(),
      age: (j['age'] ?? 'Belirtilmedi').toString(),
      hours: (j['hours'] ?? 'Belirtilmedi').toString(),
      note: (j['note'] ?? '—').toString(),
      budget: (j['budget'] ?? '').toString(),
      posted: (j['posted'] ?? 'Az önce').toString(),
      views: (j['views'] as num?)?.toInt() ?? 0,
      urgent: j['urgent'] == true,
      poster: _posterFrom(j),
    );

IkincielIlani _ikincielFromJson(Map<String, dynamic> j) {
  final rawPhotos = j['photos'];
  final photoVals = <Color>[];
  if (rawPhotos is List) {
    for (final e in rawPhotos) {
      if (e is num) photoVals.add(Color(e.toInt()));
    }
  }
  return IkincielIlani(
    id: (j['id'] as num?)?.toInt() ?? nextIlanId(),
    title: j['title']?.toString() ?? '',
    category: (j['category'] ?? 'Diğer').toString(),
    city: j['city']?.toString() ?? '',
    district: j['district']?.toString() ?? '',
    condition: (j['condition'] ?? 'İyi').toString(),
    brand: (j['brand'] ?? '—').toString(),
    note: (j['note'] ?? '—').toString(),
    price: (j['price'] ?? '').toString(),
    originalPrice: (j['original_price'] ?? j['originalPrice'] ?? '').toString(),
    posted: (j['posted'] ?? 'Az önce').toString(),
    views: (j['views'] as num?)?.toInt() ?? 0,
    emoji: (j['emoji'] ?? '📦').toString(),
    photos: photoVals.isEmpty ? const [Color(0xFFDCE8F5)] : photoVals,
    poster: _posterFrom(j),
  );
}

Map<String, dynamic> _rowToLocalJson(Map<String, dynamic> row) {
  final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
  return {
    ...row,
    'posterName': row['poster_name'],
    'posterAvatar': row['poster_avatar'],
    'originalPrice': row['original_price'],
    'ownerEmail': row['owner_email'],
    'posted': _relativePosted(created),
  };
}

void _applyRows(List<Map<String, dynamic>> rows) {
  runtimeUzmanIlanlar.clear();
  runtimeBakiciIlanlar.clear();
  runtimeIkincielIlanlar.clear();
  ilanOwnerById.clear();

  var maxId = 1000;
  for (final row in rows) {
    final j = _rowToLocalJson(row);
    final kind = j['kind']?.toString();
    final id = (j['id'] as num?)?.toInt() ?? 0;
    if (id > maxId) maxId = id;
    final owner = (j['ownerEmail'] ?? j['owner_email'])?.toString() ?? '';
    if (owner.isNotEmpty) ilanOwnerById[id] = owner.toLowerCase();

    switch (kind) {
      case 'uzman':
        runtimeUzmanIlanlar.add(_uzmanFromJson(j));
        break;
      case 'bakici':
        runtimeBakiciIlanlar.add(_bakiciFromJson(j));
        break;
      case 'ikinciel':
        runtimeIkincielIlanlar.add(_ikincielFromJson(j));
        break;
    }
  }
  syncIlanIdSeq(maxId);
}

Future<void> _cacheAllLocally() async {
  final prefs = await SharedPreferences.getInstance();
  final payload = <Map<String, dynamic>>[
    ...runtimeUzmanIlanlar.map(_uzmanToJson),
    ...runtimeBakiciIlanlar.map(_bakiciToJson),
    ...runtimeIkincielIlanlar.map(_ikincielToJson),
  ];
  await prefs.setString('shared_ilanlar_cache', jsonEncode(payload));
}

Future<bool> _loadFromLocalCache() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('shared_ilanlar_cache');
  if (raw == null || raw.isEmpty) return false;
  try {
    final list = (jsonDecode(raw) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _applyRows(list);
    return list.isNotEmpty;
  } catch (_) {
    return false;
  }
}

/// Tüm kullanıcıların ilanlarını Supabase'den yükler (ortak feed).
Future<void> loadAllIlanlar({String? preferEmail}) async {
  try {
    final rows = await Supabase.instance.client
        .from('ilanlar')
        .select()
        .order('created_at', ascending: false);
    final list = (rows as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _applyRows(list);
    await _cacheAllLocally();
    return;
  } catch (_) {
    // Tablo yok / ağ hatası → yerel önbellek veya eski kullanıcı kaydı
  }

  if (await _loadFromLocalCache()) return;
  if (preferEmail != null && preferEmail.isNotEmpty) {
    await _loadLegacyUserPrefs(preferEmail);
  }
}

Future<void> _loadLegacyUserPrefs(String email) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(ilanPrefsKey(email));
  if (raw == null || raw.isEmpty) return;
  try {
    final list = (jsonDecode(raw) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    for (final j in list) {
      j['ownerEmail'] ??= email.toLowerCase();
      j['owner_email'] ??= email.toLowerCase();
    }
    _applyRows(list);
  } catch (_) {}
}

@Deprecated('Ortak feed için loadAllIlanlar kullanın')
Future<void> loadUserIlanlar(String email) => loadAllIlanlar(preferEmail: email);

/// Yerel runtime listesini kaydet (önbellek). Asıl kaynak Supabase.
Future<void> persistUserIlanlar(String email) async {
  await _cacheAllLocally();
  // Eski tek-kullanıcı anahtarı da güncel kalsın (geriye uyumluluk).
  final prefs = await SharedPreferences.getInstance();
  final mine = <Map<String, dynamic>>[
    ...runtimeUzmanIlanlar
        .where((i) => (ilanOwnerById[i.id] ?? '') == email.toLowerCase())
        .map(_uzmanToJson),
    ...runtimeBakiciIlanlar
        .where((i) => (ilanOwnerById[i.id] ?? '') == email.toLowerCase())
        .map(_bakiciToJson),
    ...runtimeIkincielIlanlar
        .where((i) => (ilanOwnerById[i.id] ?? '') == email.toLowerCase())
        .map(_ikincielToJson),
  ];
  await prefs.setString(ilanPrefsKey(email), jsonEncode(mine));
}

Future<void> publishIlanToCloud({
  required String kind,
  required String title,
  required String city,
  required String district,
  required String note,
  required String posterName,
  required String posterAvatar,
  required String ownerEmail,
  String budget = '',
  String price = '',
  String originalPrice = '',
  String uzmanlik = 'Uzman',
  String tani = 'Belirtilmedi',
  String age = 'Belirtilmedi',
  String frequency = 'Belirtilmedi',
  String hours = 'Belirtilmedi',
  String category = 'Diğer',
  String condition = 'İyi',
  String brand = '—',
  String emoji = '📦',
  List<Color> photos = const [],
  bool urgent = false,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('İlan yayınlamak için giriş yapmalısınız.');
  }
  final resolvedEmail = ownerEmail.trim().isNotEmpty
      ? ownerEmail.trim().toLowerCase()
      : (user.email ?? '').trim().toLowerCase();
  if (resolvedEmail.isEmpty) {
    throw StateError('İlan için e-posta bulunamadı. Tekrar giriş yapın.');
  }

  final payload = <String, dynamic>{
    'kind': kind,
    'title': title,
    'city': city,
    'district': district,
    'note': note,
    'budget': budget,
    'price': price,
    'original_price': originalPrice,
    'uzmanlik': uzmanlik,
    'tani': tani,
    'age': age,
    'frequency': frequency,
    'hours': hours,
    'category': category,
    'condition': condition,
    'brand': brand,
    'emoji': emoji,
    'photos': photos.map((c) => c.toARGB32()).toList(),
    'urgent': urgent,
    'views': 0,
    'offers': 0,
    'poster_name': posterName,
    'poster_avatar': posterAvatar,
    'owner_email': resolvedEmail,
    'owner_id': user.id,
  };

  try {
    await Supabase.instance.client.from('ilanlar').insert(payload);
    await loadAllIlanlar(preferEmail: resolvedEmail);
    return;
  } catch (e) {
    // Supabase yoksa yerel düş — yine de cihazlar arası paylaşılmaz.
    final id = nextIlanId();
    final poster = IlanPoster(
      name: posterName,
      avatar: posterAvatar,
      avatarColor: MetoColors.primary,
      rating: 0,
      reviewCount: 0,
      bio: 'İlan sahibi',
      tags: const [],
      reviews: const [],
    );
    switch (kind) {
      case 'uzman':
        runtimeUzmanIlanlar.insert(
          0,
          UzmanIlani(
            id: id,
            title: title,
            uzmanlik: uzmanlik,
            tani: tani,
            city: city,
            district: district,
            age: age,
            frequency: frequency,
            note: note,
            budget: budget,
            posted: 'Az önce',
            views: 0,
            offers: 0,
            urgent: urgent,
            poster: poster,
          ),
        );
        break;
      case 'bakici':
        runtimeBakiciIlanlar.insert(
          0,
          BakiciIlani(
            id: id,
            title: title,
            city: city,
            district: district,
            tani: tani,
            age: age,
            hours: hours,
            note: note,
            budget: budget,
            posted: 'Az önce',
            views: 0,
            urgent: urgent,
            poster: poster,
          ),
        );
        break;
      default:
        runtimeIkincielIlanlar.insert(
          0,
          IkincielIlani(
            id: id,
            title: title,
            category: category,
            city: city,
            district: district,
            condition: condition,
            brand: brand,
            note: note,
            price: price,
            originalPrice: originalPrice,
            posted: 'Az önce',
            views: 0,
            emoji: emoji,
            photos: photos.isEmpty ? const [Color(0xFFDCE8F5)] : photos,
            poster: poster,
          ),
        );
    }
    ilanOwnerById[id] = resolvedEmail;
    await persistUserIlanlar(resolvedEmail);
    throw StateError(
      'İlan yalnızca bu cihaza kaydedildi. Ortak görünüm için Supabase '
      'ilanlar tablosunu oluşturun (supabase/ilanlar.sql). Detay: $e',
    );
  }
}

Future<void> deleteUserIlan({
  required String email,
  required String kind,
  required int id,
}) async {
  final normalized = email.trim().toLowerCase();
  final me = (Supabase.instance.client.auth.currentUser?.email ?? '')
      .trim()
      .toLowerCase();
  final admin = isAppAdmin(me);
  try {
    var q =
        Supabase.instance.client.from('ilanlar').delete().eq('id', id);
    if (!admin) {
      q = q.eq('owner_email', normalized);
    }
    await q;
  } catch (_) {
    // Yerel silmeye devam
  }

  switch (kind) {
    case 'uzman':
      runtimeUzmanIlanlar.removeWhere((i) => i.id == id);
      break;
    case 'bakici':
      runtimeBakiciIlanlar.removeWhere((i) => i.id == id);
      break;
    case 'ikinciel':
      runtimeIkincielIlanlar.removeWhere((i) => i.id == id);
      break;
  }
  ilanOwnerById.remove(id);
  if (!admin || normalized == me) {
    await persistUserIlanlar(email);
  }
  try {
    await loadAllIlanlar(preferEmail: email);
  } catch (_) {}
}

List<UzmanIlani> myUzmanIlanlar(String email) {
  final e = email.trim().toLowerCase();
  return runtimeUzmanIlanlar
      .where((i) => (ilanOwnerById[i.id] ?? '') == e)
      .toList();
}

List<BakiciIlani> myBakiciIlanlar(String email) {
  final e = email.trim().toLowerCase();
  return runtimeBakiciIlanlar
      .where((i) => (ilanOwnerById[i.id] ?? '') == e)
      .toList();
}

List<IkincielIlani> myIkincielIlanlar(String email) {
  final e = email.trim().toLowerCase();
  return runtimeIkincielIlanlar
      .where((i) => (ilanOwnerById[i.id] ?? '') == e)
      .toList();
}

int myIlanCount(String email) =>
    myUzmanIlanlar(email).length +
    myBakiciIlanlar(email).length +
    myIkincielIlanlar(email).length;

void clearRuntimeIlanlar() {
  runtimeUzmanIlanlar.clear();
  runtimeBakiciIlanlar.clear();
  runtimeIkincielIlanlar.clear();
  ilanOwnerById.clear();
}
