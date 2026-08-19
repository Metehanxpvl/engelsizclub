import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/ilanlar_data.dart';
import 'data/location_models.dart';
import 'kredi_store.dart';
import 'meto_theme.dart';
import 'services/broadcast_push_service.dart';
import 'utils/price_format.dart';
import 'widgets/user_avatar.dart';

/// İlan sahibi e-postası (id → email). Ortak listede "İlanlarım" için.
final Map<int, String> ilanOwnerById = <int, String>{};

String ilanPrefsKey(String email, {String fallback = 'anon'}) {
  final e = email.trim().toLowerCase();
  return 'user_ilanlar_${e.isEmpty ? fallback : e}';
}

LocationData locationFromIlanJson(Map<String, dynamic> j) {
  final raw = j['location_data'] ?? j['locationData'];
  if (raw is Map && raw.isNotEmpty) {
    final loc = LocationData.fromJson(raw);
    if (loc.countryCode.isNotEmpty || loc.state.isNotEmpty) return loc;
  }
  final code = (j['country_code'] ?? j['countryCode'] ?? 'TR')
      .toString()
      .trim()
      .toUpperCase();
  return LocationData.fromLegacy(
    city: j['city']?.toString() ?? '',
    district: (j['district'] ?? '').toString(),
    countryCode: code.isEmpty ? 'TR' : code,
  );
}

String _countryCodeOf(Map<String, dynamic> j) {
  final loc = locationFromIlanJson(j);
  return loc.countryCode.isEmpty ? 'TR' : loc.countryCode;
}

Map<String, dynamic> locationDbFields(LocationData loc) {
  final code = loc.countryCode.isEmpty ? 'TR' : loc.countryCode.toUpperCase();
  final normalized = loc.copyWith(countryCode: code);
  return {
    'country_code': code,
    'location_data': normalized.toJson(),
    'city': normalized.legacyCity,
    'district': normalized.legacyDistrict,
  };
}

/// Supabase ilan insert/update hatalarını kullanıcıya anlaşılır metne çevirir.
String formatIlanCloudError(Object error) {
  final msg = error.toString();
  final lower = msg.toLowerCase();
  if (lower.contains('42501') ||
      lower.contains('row-level security') ||
      lower.contains('policy')) {
    return 'İlan kaydedilemedi: yetki hatası. Hesap rolünüzün Aile olduğundan emin olun '
        '(Menü → Hesap rolü → Aile). Uzman/bakıcı rolü ilan paylaşamaz.';
  }
  if (lower.contains('does not exist') &&
      (lower.contains('ilanlar') || lower.contains('relation'))) {
    return 'Supabase ilanlar tablosu bulunamadı. '
        'Dashboard → SQL Editor → supabase/ilanlar_ensure.sql dosyasını çalıştırın.';
  }
  if (lower.contains('country_code') ||
      lower.contains('location_data') ||
      (lower.contains('column') && lower.contains('status'))) {
    return 'Supabase ilanlar şeması güncel değil. '
        'supabase/ilanlar_ensure.sql dosyasını SQL Editor\'da çalıştırın.';
  }
  if (lower.contains('aile rol')) {
    return msg.replaceFirst('Bad state: ', '').replaceFirst('StateError: ', '');
  }
  return 'İlan buluta kaydedilemedi: $msg';
}

/// RLS / rol hatalarında yerel kayda düşülmemeli.
bool shouldFallbackIlanLocally(Object error) {
  final lower = error.toString().toLowerCase();
  if (lower.contains('42501') ||
      lower.contains('row-level security') ||
      lower.contains('policy')) {
    return false;
  }
  if (lower.contains('aile rol') || lower.contains('giriş yapmalı')) {
    return false;
  }
  return true;
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

List<IlanPhoto> _photosFromJson(dynamic rawPhotos) {
  final photoVals = <IlanPhoto>[];
  if (rawPhotos is List) {
    for (final e in rawPhotos) {
      photoVals.add(IlanPhoto.fromJson(e));
    }
  }
  return photoVals;
}

List<dynamic> _photosToJson(List<IlanPhoto> photos, {bool forLocalCache = false}) {
  if (forLocalCache) {
    return photos.map(_photoToLocalJson).toList();
  }
  return photos.map((p) => p.toJson()).toList();
}

Map<String, dynamic> _uzmanToJson(UzmanIlani i, {bool forLocalCache = false}) => {
      'kind': 'uzman',
      'id': i.id,
      'title': i.title,
      'uzmanlik': i.uzmanlik,
      'tani': i.tani,
      'city': i.city,
      'district': i.district,
      'country_code': i.countryCode,
      'countryCode': i.countryCode,
      'location_data': LocationData.fromLegacy(
        city: i.city,
        district: i.district,
        countryCode: i.countryCode,
      ).toJson(),
      'age': i.age,
      'frequency': i.frequency,
      'note': i.note,
      'budget': i.budget,
      'posted': i.posted,
      'views': i.views,
      'offers': i.offers,
      'urgent': i.urgent,
      'photos': _photosToJson(i.photos, forLocalCache: forLocalCache),
      'category': i.category,
      'posterName': i.poster.fullName.trim().isNotEmpty
          ? i.poster.fullName
          : i.poster.name,
      'posterAvatar': i.poster.avatar,
      'ownerEmail': ilanOwnerById[i.id] ?? '',
    };

Map<String, dynamic> _bakiciToJson(BakiciIlani i, {bool forLocalCache = false}) => {
      'kind': 'bakici',
      'id': i.id,
      'title': i.title,
      'city': i.city,
      'district': i.district,
      'country_code': i.countryCode,
      'countryCode': i.countryCode,
      'location_data': LocationData.fromLegacy(
        city: i.city,
        district: i.district,
        countryCode: i.countryCode,
      ).toJson(),
      'tani': i.tani,
      'age': i.age,
      'hours': i.hours,
      'note': i.note,
      'budget': i.budget,
      'posted': i.posted,
      'views': i.views,
      'urgent': i.urgent,
      'photos': _photosToJson(i.photos, forLocalCache: forLocalCache),
      'posterName': i.poster.fullName.trim().isNotEmpty
          ? i.poster.fullName
          : i.poster.name,
      'posterAvatar': i.poster.avatar,
      'ownerEmail': ilanOwnerById[i.id] ?? '',
    };

/// Web localStorage (~5MB) dolmasın diye data-URL fotoğrafları önbelleğe yazma.
dynamic _photoToLocalJson(IlanPhoto p) {
  final url = p.dataUrl;
  if (url != null && url.startsWith('data:')) {
    return p.swatchColor.toARGB32();
  }
  return p.toJson();
}

Map<String, dynamic> _ikincielToJson(
  IkincielIlani i, {
  bool forLocalCache = false,
}) =>
    {
      'kind': 'ikinciel',
      'id': i.id,
      'title': i.title,
      'category': i.category,
      'city': i.city,
      'district': i.district,
      'country_code': i.countryCode,
      'countryCode': i.countryCode,
      'location_data': LocationData.fromLegacy(
        city: i.city,
        district: i.district,
        countryCode: i.countryCode,
      ).toJson(),
      'condition': i.condition,
      'brand': i.brand,
      'note': i.note,
      'price': i.price,
      'originalPrice': i.originalPrice,
      'posted': i.posted,
      'views': i.views,
      'emoji': i.emoji,
      'photos': forLocalCache
          ? i.photos.map(_photoToLocalJson).toList()
          : i.photos.map((p) => p.toJson()).toList(),
      'posterName': i.poster.fullName.trim().isNotEmpty
          ? i.poster.fullName
          : i.poster.name,
      'posterAvatar': i.poster.avatar,
      'ownerEmail': ilanOwnerById[i.id] ?? '',
    };

String _safeIlanText(String? raw) =>
    scrubIlanListingText((raw ?? '').toString());

IlanPoster _posterFrom(Map<String, dynamic> j) {
  final rawName = (j['posterName'] ?? j['poster_name'])?.toString() ?? 'Siz';
  final fullName = rawName.trim().isEmpty ? 'Siz' : rawName.trim();
  final name = maskPersonDisplayName(fullName);
  final avatar = (j['posterAvatar'] ?? j['poster_avatar'])?.toString();
  return IlanPoster(
    name: name,
    fullName: fullName,
    avatar: (avatar != null && avatar.isNotEmpty)
        ? avatar
        : posterAvatarInitials(name),
    avatarColor: MetoColors.primary,
    rating: 0,
    reviewCount: 0,
    bio: 'İlan sahibi',
    tags: const <String>[],
    reviews: const <IlanReview>[],
  );
}

UzmanIlani _uzmanFromJson(Map<String, dynamic> j) {
  final photos = _photosFromJson(j['photos']);
  final loc = locationFromIlanJson(j);
  return UzmanIlani(
    id: (j['id'] as num?)?.toInt() ?? nextIlanId(),
    title: _safeIlanText(j['title']),
    uzmanlik: (j['uzmanlik'] ?? 'Uzman').toString(),
    tani: (j['tani'] ?? 'Belirtilmedi').toString(),
    city: loc.state.isNotEmpty ? loc.state : (j['city']?.toString() ?? ''),
    district:
        loc.city.isNotEmpty ? loc.city : ((j['district'] ?? '').toString()),
    countryCode: _countryCodeOf(j),
    age: (j['age'] ?? 'Belirtilmedi').toString(),
    frequency: (j['frequency'] ?? 'Belirtilmedi').toString(),
    note: () {
      final n = _safeIlanText(j['note']);
      return n.isEmpty ? '—' : n;
    }(),
    budget: (j['budget'] ?? '').toString(),
    posted: (j['posted'] ?? 'Az önce').toString(),
    views: (j['views'] as num?)?.toInt() ?? 0,
    offers: (j['offers'] as num?)?.toInt() ?? 0,
    urgent: j['urgent'] == true,
    photos: photos.length > kUzmanBakiciMaxPhotos
        ? photos.take(kUzmanBakiciMaxPhotos).toList()
        : photos,
    poster: _posterFrom(j),
    category: normalizeUzmanListingCategory(j['category']),
  );
}

BakiciIlani _bakiciFromJson(Map<String, dynamic> j) {
  final photos = _photosFromJson(j['photos']);
  final loc = locationFromIlanJson(j);
  return BakiciIlani(
    id: (j['id'] as num?)?.toInt() ?? nextIlanId(),
    title: _safeIlanText(j['title']),
    city: loc.state.isNotEmpty ? loc.state : (j['city']?.toString() ?? ''),
    district:
        loc.city.isNotEmpty ? loc.city : ((j['district'] ?? '').toString()),
    countryCode: _countryCodeOf(j),
    tani: (j['tani'] ?? 'Belirtilmedi').toString(),
    age: (j['age'] ?? 'Belirtilmedi').toString(),
    hours: (j['hours'] ?? 'Belirtilmedi').toString(),
    note: () {
      final n = _safeIlanText(j['note']);
      return n.isEmpty ? '—' : n;
    }(),
    budget: (j['budget'] ?? '').toString(),
    posted: (j['posted'] ?? 'Az önce').toString(),
    views: (j['views'] as num?)?.toInt() ?? 0,
    urgent: j['urgent'] == true,
    photos: photos.length > kUzmanBakiciMaxPhotos
        ? photos.take(kUzmanBakiciMaxPhotos).toList()
        : photos,
    poster: _posterFrom(j),
  );
}

IkincielIlani _ikincielFromJson(Map<String, dynamic> j) {
  final photoVals = _photosFromJson(j['photos']);
  final loc = locationFromIlanJson(j);
  return IkincielIlani(
    id: (j['id'] as num?)?.toInt() ?? nextIlanId(),
    title: _safeIlanText(j['title']),
    category: (j['category'] ?? 'Diğer').toString(),
    city: loc.state.isNotEmpty ? loc.state : (j['city']?.toString() ?? ''),
    district:
        loc.city.isNotEmpty ? loc.city : ((j['district'] ?? '').toString()),
    countryCode: _countryCodeOf(j),
    condition: (j['condition'] ?? 'İyi').toString(),
    brand: (j['brand'] ?? '—').toString(),
    note: () {
      final n = _safeIlanText(j['note']);
      return n.isEmpty ? '—' : n;
    }(),
    price: (j['price'] ?? '').toString(),
    originalPrice: (j['original_price'] ?? j['originalPrice'] ?? '').toString(),
    posted: (j['posted'] ?? 'Az önce').toString(),
    views: (j['views'] as num?)?.toInt() ?? 0,
    emoji: (j['emoji'] ?? '📦').toString(),
    photos: photoVals.isEmpty
        ? const [IlanPhoto.swatch(Color(0xFFDCE8F5))]
        : photoVals,
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
    final status = (row['status']?.toString() ?? 'active').toLowerCase();
    if (status == 'sold') continue;

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
    ...runtimeUzmanIlanlar.map((i) => _uzmanToJson(i, forLocalCache: true)),
    ...runtimeBakiciIlanlar.map((i) => _bakiciToJson(i, forLocalCache: true)),
    ...runtimeIkincielIlanlar.map((i) => _ikincielToJson(i, forLocalCache: true)),
  ];
  final encoded = jsonEncode(payload);
  try {
    await prefs.setString('shared_ilanlar_cache', encoded);
  } catch (_) {
    // QuotaExceeded / ön bellek dolu — eski cache'i temizle, sessizce geç.
    // Asıl kaynak Supabase; fotoğraflar zaten bulutta.
    try {
      await prefs.remove('shared_ilanlar_cache');
    } catch (_) {}
  }
}

Future<bool> _loadFromLocalCache() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('shared_ilanlar_cache');
  if (raw == null || raw.isEmpty) return false;
  // Eski sürümlerde base64 fotoğraflar localStorage'ı şişirmiş olabilir.
  if (raw.length > 1200000) {
    try {
      await prefs.remove('shared_ilanlar_cache');
    } catch (_) {}
    return false;
  }
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
    await enrichRuntimeIlanAvatars(
      ownEmail: preferEmail,
    );
    return;
  } catch (_) {
    // Tablo yok / ağ hatası → yerel önbellek veya eski kullanıcı kaydı
  }

  if (await _loadFromLocalCache()) {
    await enrichRuntimeIlanAvatars(ownEmail: preferEmail);
    return;
  }
  if (preferEmail != null && preferEmail.isNotEmpty) {
    await _loadLegacyUserPrefs(preferEmail);
    await enrichRuntimeIlanAvatars(ownEmail: preferEmail);
  }
}

IlanPoster _posterWithAvatar(IlanPoster p, String avatar) => IlanPoster(
      name: p.name,
      fullName: p.fullName,
      avatar: avatar,
      avatarColor: p.avatarColor,
      rating: p.rating,
      reviewCount: p.reviewCount,
      bio: p.bio,
      tags: p.tags,
      reviews: p.reviews,
      cv: p.cv,
    );

/// Sahip e-postasından profil fotoğraflarını ilan avatarlarına uygular.
Future<void> enrichRuntimeIlanAvatars({
  String? ownEmail,
  String? ownPhoto,
}) async {
  final emails = <String>{
    for (final i in runtimeUzmanIlanlar) ilanOwnerById[i.id] ?? '',
    for (final i in runtimeBakiciIlanlar) ilanOwnerById[i.id] ?? '',
    for (final i in runtimeIkincielIlanlar) ilanOwnerById[i.id] ?? '',
  }..removeWhere((e) => e.trim().isEmpty);

  final photos = await loadUserPhotosByEmail(emails);
  if (ownEmail != null &&
      ownEmail.trim().isNotEmpty &&
      ownPhoto != null &&
      isAvatarImageSource(ownPhoto)) {
    cacheOwnUserPhoto(ownEmail, ownPhoto);
  }

  String resolvedFor(int id, String stored) => resolveAvatar(
        storedAvatar: stored,
        ownerEmail: ilanOwnerById[id] ?? '',
        photosByEmail: photos,
        ownPhoto: ownPhoto,
        ownEmail: ownEmail,
      );

  for (var i = 0; i < runtimeUzmanIlanlar.length; i++) {
    final item = runtimeUzmanIlanlar[i];
    final next = resolvedFor(item.id, item.poster.avatar);
    if (next != item.poster.avatar) {
      runtimeUzmanIlanlar[i] = UzmanIlani(
        id: item.id,
        title: item.title,
        uzmanlik: item.uzmanlik,
        tani: item.tani,
        city: item.city,
        district: item.district,
        age: item.age,
        frequency: item.frequency,
        note: item.note,
        budget: item.budget,
        posted: item.posted,
        views: item.views,
        offers: item.offers,
        urgent: item.urgent,
        photos: item.photos,
        poster: _posterWithAvatar(item.poster, next),
      );
    }
  }
  for (var i = 0; i < runtimeBakiciIlanlar.length; i++) {
    final item = runtimeBakiciIlanlar[i];
    final next = resolvedFor(item.id, item.poster.avatar);
    if (next != item.poster.avatar) {
      runtimeBakiciIlanlar[i] = BakiciIlani(
        id: item.id,
        title: item.title,
        city: item.city,
        district: item.district,
        tani: item.tani,
        age: item.age,
        hours: item.hours,
        note: item.note,
        budget: item.budget,
        posted: item.posted,
        views: item.views,
        urgent: item.urgent,
        photos: item.photos,
        poster: _posterWithAvatar(item.poster, next),
      );
    }
  }
  for (var i = 0; i < runtimeIkincielIlanlar.length; i++) {
    final item = runtimeIkincielIlanlar[i];
    final next = resolvedFor(item.id, item.poster.avatar);
    if (next != item.poster.avatar) {
      runtimeIkincielIlanlar[i] = IkincielIlani(
        id: item.id,
        title: item.title,
        category: item.category,
        city: item.city,
        district: item.district,
        condition: item.condition,
        brand: item.brand,
        note: item.note,
        price: item.price,
        originalPrice: item.originalPrice,
        posted: item.posted,
        views: item.views,
        emoji: item.emoji,
        photos: item.photos,
        poster: _posterWithAvatar(item.poster, next),
      );
    }
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
        .map((i) => _uzmanToJson(i, forLocalCache: true)),
    ...runtimeBakiciIlanlar
        .where((i) => (ilanOwnerById[i.id] ?? '') == email.toLowerCase())
        .map((i) => _bakiciToJson(i, forLocalCache: true)),
    ...runtimeIkincielIlanlar
        .where((i) => (ilanOwnerById[i.id] ?? '') == email.toLowerCase())
        .map((i) => _ikincielToJson(i, forLocalCache: true)),
  ];
  try {
    await prefs.setString(ilanPrefsKey(email), jsonEncode(mine));
  } catch (_) {
    try {
      await prefs.remove(ilanPrefsKey(email));
    } catch (_) {}
  }
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
  String countryCode = 'TR',
  LocationData? location,
  String budget = '',
  String price = '',
  String originalPrice = '',
  String uzmanlik = 'Uzman',
  String tani = 'Belirtilmedi',
  String age = 'Belirtilmedi',
  String frequency = 'Belirtilmedi',
  String hours = 'Belirtilmedi',
  String category = kIlanCatUzmanAriyorum,
  String condition = 'İyi',
  String brand = '—',
  String emoji = '📦',
  List<IlanPhoto> photos = const [],
  bool urgent = false,
}) async {
  title = _safeIlanText(title);
  note = _safeIlanText(note);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('İlan yayınlamak için giriş yapmalısınız.');
  }
  final userType = currentAuthUserType();
  if (!canPostIlan(
    userType: userType,
    email: user.email,
    listingCategory: category,
  )) {
    throw StateError(
      'İlan yalnızca Aile rolündeki hesaplarla paylaşılabilir. '
      'Uzman ve bakıcı hesapları Menü → Hesap rolü bölümünden Aile rolüne geçmelidir.',
    );
  }
  final resolvedEmail = ownerEmail.trim().isNotEmpty
      ? ownerEmail.trim().toLowerCase()
      : (user.email ?? '').trim().toLowerCase();
  if (resolvedEmail.isEmpty) {
    throw StateError('İlan için e-posta bulunamadı. Tekrar giriş yapın.');
  }

  final fullPosterName =
      posterName.trim().isEmpty ? 'Siz' : posterName.trim();
  final displayPosterName = maskPersonDisplayName(fullPosterName);
  final safePosterAvatar = posterAvatar.trim().isEmpty
      ? posterAvatarInitials(displayPosterName)
      : posterAvatar.trim();

  // Uzman / bakıcı ilanlarında en fazla 2 fotoğraf.
  final cappedPhotos = (kind == 'uzman' || kind == 'bakici')
      ? (photos.length > kUzmanBakiciMaxPhotos
          ? photos.take(kUzmanBakiciMaxPhotos).toList()
          : photos)
      : photos;

  final loc = location ??
      LocationData.fromLegacy(
        city: city,
        district: district,
        countryCode: countryCode,
      );
  final locFields = locationDbFields(loc);

  final payload = <String, dynamic>{
    'kind': kind,
    'title': _safeIlanText(title),
    ...locFields,
    'note': _safeIlanText(note),
    'budget': formatPriceTl(budget),
    'price': formatPriceTl(price),
    'original_price': formatPriceTl(originalPrice),
    'uzmanlik': uzmanlik,
    'tani': tani,
    'age': age,
    'frequency': frequency,
    'hours': hours,
    'category': category,
    'condition': condition,
    'brand': brand,
    'emoji': emoji,
    'photos': cappedPhotos.map((p) => p.toJson()).toList(),
    'urgent': urgent,
    'views': 0,
    'offers': 0,
    'poster_name': fullPosterName,
    'poster_avatar': safePosterAvatar,
    'owner_email': resolvedEmail,
    'owner_id': user.id,
  };

  try {
    try {
      await Supabase.instance.client.from('ilanlar').insert(payload);
    } catch (e) {
      // Kolonlar henüz yoksa (SQL çalıştırılmadı) klasik alanlarla dene
      final msg = e.toString().toLowerCase();
      if (msg.contains('country_code') || msg.contains('location_data')) {
        final legacy = Map<String, dynamic>.from(payload)
          ..remove('country_code')
          ..remove('location_data');
        await Supabase.instance.client.from('ilanlar').insert(legacy);
      } else {
        rethrow;
      }
    }
    try {
      await loadAllIlanlar(preferEmail: resolvedEmail);
    } catch (_) {
      // Ön bellek / ağ yenilemesi başarısız olsa da ilan buluta yazıldı.
    }
    unawaited(
      BroadcastPushService.instance.yeniIlan(
        title: title,
        kind: kind,
      ),
    );
    return;
  } catch (e) {
    if (!shouldFallbackIlanLocally(e)) {
      throw StateError(formatIlanCloudError(e));
    }
    // Supabase yoksa / şema eksikse yerel düş — yine de cihazlar arası paylaşılmaz.
    final id = nextIlanId();
    final poster = IlanPoster(
      name: displayPosterName,
      fullName: fullPosterName,
      avatar: safePosterAvatar,
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
            city: loc.legacyCity,
            district: loc.legacyDistrict,
            countryCode: loc.countryCode,
            age: age,
            frequency: frequency,
            note: note,
            budget: budget,
            posted: 'Az önce',
            views: 0,
            offers: 0,
            urgent: urgent,
            photos: cappedPhotos,
            poster: poster,
            category: normalizeUzmanListingCategory(category),
          ),
        );
        break;
      case 'bakici':
        runtimeBakiciIlanlar.insert(
          0,
          BakiciIlani(
            id: id,
            title: title,
            city: loc.legacyCity,
            district: loc.legacyDistrict,
            countryCode: loc.countryCode,
            tani: tani,
            age: age,
            hours: hours,
            note: note,
            budget: budget,
            posted: 'Az önce',
            views: 0,
            urgent: urgent,
            photos: cappedPhotos,
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
            city: loc.legacyCity,
            district: loc.legacyDistrict,
            countryCode: loc.countryCode,
            condition: condition,
            brand: brand,
            note: note,
            price: price,
            originalPrice: originalPrice,
            posted: 'Az önce',
            views: 0,
            emoji: emoji,
            photos: cappedPhotos.isEmpty
                ? const [IlanPhoto.swatch(Color(0xFFDCE8F5))]
                : cappedPhotos,
            poster: poster,
          ),
        );
    }
    ilanOwnerById[id] = resolvedEmail;
    await persistUserIlanlar(resolvedEmail);
    throw StateError('LOCAL_ILAN_SAVED:${formatIlanCloudError(e)}');
  }
}

Future<void> updateIlanInCloud({
  required int id,
  required String kind,
  required String title,
  required String city,
  required String district,
  required String note,
  required String ownerEmail,
  String countryCode = 'TR',
  LocationData? location,
  String budget = '',
  String price = '',
  String uzmanlik = 'Uzman',
  String condition = 'İyi',
  String category = kIlanCatUzmanAriyorum,
  List<IlanPhoto> photos = const [],
}) async {
  title = _safeIlanText(title);
  note = _safeIlanText(note);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('İlan düzenlemek için giriş yapmalısınız.');
  }
  if (id <= 0) throw StateError('Geçersiz ilan.');

  final resolvedEmail = ownerEmail.trim().isNotEmpty
      ? ownerEmail.trim().toLowerCase()
      : (user.email ?? '').trim().toLowerCase();

  final cappedPhotos = (kind == 'uzman' || kind == 'bakici')
      ? (photos.length > kUzmanBakiciMaxPhotos
          ? photos.take(kUzmanBakiciMaxPhotos).toList()
          : photos)
      : photos;

  final loc = location ??
      LocationData.fromLegacy(
        city: city,
        district: district,
        countryCode: countryCode,
      );
  final locFields = locationDbFields(loc);

  final myEmail = (user.email ?? '').trim().toLowerCase();
  final payload = <String, dynamic>{
    'title': _safeIlanText(title),
    ...locFields,
    'note': _safeIlanText(note),
    'budget': budget,
    'price': price,
    'uzmanlik': uzmanlik,
    'photos': cappedPhotos.map((p) => p.toJson()).toList(),
    if (kind == 'uzman') 'category': normalizeUzmanListingCategory(category),
    if (kind == 'ikinciel') ...{
      'condition': condition,
      'category': category,
    },
    // Legacy kayıtlarda boş owner_id varsa sahipliği bağla
    'owner_id': user.id,
  };

  // RLS: owner_id veya owner_email eşleşmesi; istemci filtresi de aynı mantık
  var updated = await Supabase.instance.client
      .from('ilanlar')
      .update(payload)
      .eq('id', id)
      .eq('owner_id', user.id)
      .select('id');

  if (updated.isEmpty && myEmail.isNotEmpty) {
    updated = await Supabase.instance.client
        .from('ilanlar')
        .update(payload)
        .eq('id', id)
        .eq('owner_email', myEmail)
        .select('id');
  }

  if (updated.isEmpty &&
      resolvedEmail.isNotEmpty &&
      resolvedEmail != myEmail) {
    updated = await Supabase.instance.client
        .from('ilanlar')
        .update(payload)
        .eq('id', id)
        .eq('owner_email', resolvedEmail)
        .select('id');
  }

  if (updated.isEmpty) {
    throw StateError(
      'İlan güncellenemedi (yetki yok). Supabase’de '
      'ilanlar_update_own.sql çalıştırın.',
    );
  }

  try {
    await loadAllIlanlar(preferEmail: resolvedEmail);
  } catch (_) {}
}

String _normalizedIlanKind(String kind) {
  final k = kind.trim().toLowerCase();
  return switch (k) {
    'uzman' || 'bakici' || 'ikinciel' => k,
    _ => '',
  };
}

void _applySingleIlanRow(Map<String, dynamic> row) {
  final status = (row['status']?.toString() ?? 'active').toLowerCase();
  final id = (row['id'] as num?)?.toInt() ?? 0;
  if (id <= 0) return;

  runtimeUzmanIlanlar.removeWhere((i) => i.id == id);
  runtimeBakiciIlanlar.removeWhere((i) => i.id == id);
  runtimeIkincielIlanlar.removeWhere((i) => i.id == id);

  if (status == 'sold') return;

  final j = _rowToLocalJson(row);
  final owner = (j['ownerEmail'] ?? j['owner_email'])?.toString() ?? '';
  if (owner.isNotEmpty) ilanOwnerById[id] = owner.toLowerCase();

  switch (j['kind']?.toString()) {
    case 'uzman':
      runtimeUzmanIlanlar.insert(0, _uzmanFromJson(j));
      break;
    case 'bakici':
      runtimeBakiciIlanlar.insert(0, _bakiciFromJson(j));
      break;
    case 'ikinciel':
      runtimeIkincielIlanlar.insert(0, _ikincielFromJson(j));
      break;
  }
}

Future<void> _reloadIlanAfterKindChange(int id, String preferEmail) async {
  final client = Supabase.instance.client;
  try {
    final row = await client.from('ilanlar').select().eq('id', id).maybeSingle();
    if (row != null) {
      _applySingleIlanRow(Map<String, dynamic>.from(row));
    }
  } catch (_) {}
  try {
    await loadAllIlanlar(preferEmail: preferEmail);
  } catch (_) {}
}

String _adminKindChangeError(Object e, String email) {
  final msg = e.toString();
  if (msg.contains('not allowed') || msg.contains('Yalnızca admin')) {
    return 'Admin yetkisi tanınmadı ($email). '
        'sakir.caykara@gmail.com ile giriş yapın.';
  }
  if (msg.contains('ilanlar_photos_max_check') ||
      msg.contains('photos') && msg.contains('check')) {
    return 'Fotoğraf sayısı fazla. 2. el ilanı uzman/bakıcıya taşınırken '
        'en fazla 2 fotoğraf kalır.';
  }
  if (msg.contains('42883') ||
      msg.contains('admin_change_ilan_kind') ||
      msg.contains('admin-ilan-kind')) {
    return 'Sunucu güncellemesi gerekli. Supabase’de '
        'ilanlar_admin_change_kind.sql çalıştırın veya '
        'admin-ilan-kind edge function deploy edin.';
  }
  if (msg.contains('42501') || msg.contains('policy')) {
    return 'Güncelleme yetkisi yok. Supabase’de '
        'ilanlar_admin_change_kind.sql çalıştırın.';
  }
  return 'Taşınamadı: $e';
}

/// Admin: ilanı başka sekmeye taşır (ör. uzman → ikinciel).
Future<void> adminChangeIlanKind({
  required int id,
  required String toKind,
  String ikincielCategory = kIkincielAltDiger,
  String uzmanlik = 'Uzman',
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null) {
    throw StateError('Kategori değiştirmek için giriş yapmalısınız.');
  }
  if (!isAppAdmin(me)) {
    throw StateError('Yalnızca admin kategori değiştirebilir.');
  }
  if (id <= 0) throw StateError('Geçersiz ilan.');

  final kind = _normalizedIlanKind(toKind);
  if (kind.isEmpty) throw StateError('Geçersiz kategori.');

  final category = ikincielAltKategoriOf(ikincielCategory);
  final uzman = uzmanlik.trim().isEmpty ? 'Uzman' : uzmanlik.trim();
  final client = Supabase.instance.client;

  Future<void> finishAfterDbOk() async {
    await _reloadIlanAfterKindChange(id, me);
  }

  // 1) RPC (Supabase'de zaten var — edge function gerekmez)
  try {
    await client.rpc(
      'admin_change_ilan_kind',
      params: {
        'p_id': id,
        'p_kind': kind,
        'p_category': category,
        'p_uzmanlik': uzman,
      },
    );
    await finishAfterDbOk();
    return;
  } on PostgrestException catch (e) {
    if (e.code != '42883' && !e.message.contains('Could not find')) {
      throw StateError(_adminKindChangeError(e, me));
    }
    // RPC yok → edge function / doğrudan güncelleme dene
  }

  // 2) Edge function (deploy edilmişse — yoksa sessizce atla)
  try {
    final res = await client.functions.invoke(
      'admin-ilan-kind',
      body: {
        'id': id,
        'kind': kind,
        'category': category,
        'uzmanlik': uzman,
      },
    );
    if (res.status >= 200 && res.status < 300) {
      final data = res.data;
      if (data is Map && data['row'] is Map) {
        _applySingleIlanRow(Map<String, dynamic>.from(data['row'] as Map));
      }
      await finishAfterDbOk();
      return;
    }
  } catch (_) {
    // Deploy edilmemiş / ağ hatası — doğrudan güncellemeye geç
  }

  // 3) Doğrudan güncelleme (admin RLS policy sonrası)
  final row = await client
        .from('ilanlar')
        .select(
          'photos, budget, price, condition, brand, emoji, uzmanlik, category',
        )
        .eq('id', id)
        .maybeSingle();
    if (row == null) {
      throw StateError('İlan bulunamadı (id: $id).');
    }

    final payload = <String, dynamic>{
      'kind': kind,
    };
    if (kind == 'ikinciel') {
      payload['category'] = category;
      final price = (row['price'] ?? '').toString().trim();
      final budget = (row['budget'] ?? '').toString().trim();
      if (price.isEmpty && budget.isNotEmpty) payload['price'] = budget;
      if ((row['condition'] ?? '').toString().trim().isEmpty) {
        payload['condition'] = 'İyi';
      }
      if ((row['brand'] ?? '').toString().trim().isEmpty) {
        payload['brand'] = '—';
      }
      if ((row['emoji'] ?? '').toString().trim().isEmpty) {
        payload['emoji'] = '📦';
      }
    }
    if (kind == 'uzman') {
      payload['uzmanlik'] = uzman;
    }
    if (kind == 'uzman' || kind == 'bakici') {
      final budget = (row['budget'] ?? '').toString().trim();
      final price = (row['price'] ?? '').toString().trim();
      if (budget.isEmpty && price.isNotEmpty) payload['budget'] = price;
      final photos = _photosFromJson(row['photos']);
      if (photos.length > kUzmanBakiciMaxPhotos) {
        payload['photos'] =
            photos.take(kUzmanBakiciMaxPhotos).map((p) => p.toJson()).toList();
      }
    }

    final updated = await client
        .from('ilanlar')
        .update(payload)
        .eq('id', id)
        .select()
        .maybeSingle();
    if (updated == null) {
      throw StateError(_adminKindChangeError('policy/42501', me));
    }
    _applySingleIlanRow(Map<String, dynamic>.from(updated));
  await finishAfterDbOk();
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

/// Satıldı → yayından kaldır (status=sold; kolon yoksa siler).
Future<void> markIlanSold({
  required String email,
  required String kind,
  required int id,
}) async {
  final normalized = email.trim().toLowerCase();
  final me = (Supabase.instance.client.auth.currentUser?.email ?? '')
      .trim()
      .toLowerCase();
  final admin = isAppAdmin(me);
  var marked = false;
  try {
    var q = Supabase.instance.client
        .from('ilanlar')
        .update({'status': 'sold'}).eq('id', id);
    if (!admin) {
      q = q.eq('owner_email', normalized);
    }
    await q;
    marked = true;
  } catch (_) {
    marked = false;
  }
  if (!marked) {
    await deleteUserIlan(email: email, kind: kind, id: id);
    return;
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

void applyRuntimeIlanViews(int id, int views) {
  if (id <= 0 || views < 0) return;
  for (var i = 0; i < runtimeUzmanIlanlar.length; i++) {
    if (runtimeUzmanIlanlar[i].id == id) {
      runtimeUzmanIlanlar[i] = runtimeUzmanIlanlar[i].copyWith(views: views);
    }
  }
  for (var i = 0; i < runtimeBakiciIlanlar.length; i++) {
    if (runtimeBakiciIlanlar[i].id == id) {
      runtimeBakiciIlanlar[i] = runtimeBakiciIlanlar[i].copyWith(views: views);
    }
  }
  for (var i = 0; i < runtimeIkincielIlanlar.length; i++) {
    if (runtimeIkincielIlanlar[i].id == id) {
      runtimeIkincielIlanlar[i] =
          runtimeIkincielIlanlar[i].copyWith(views: views);
    }
  }
}

/// Teklif / sohbet için ilan sahibinin tam adı (e-posta ile).
String? revealedPosterNameForOwner(String email) {
  final e = email.trim().toLowerCase();
  if (e.isEmpty) return null;
  for (final i in runtimeUzmanIlanlar) {
    if ((ilanOwnerById[i.id] ?? '') == e) {
      final n = i.poster.revealedName.trim();
      if (n.isNotEmpty && n != 'Üye') return n;
    }
  }
  for (final i in runtimeBakiciIlanlar) {
    if ((ilanOwnerById[i.id] ?? '') == e) {
      final n = i.poster.revealedName.trim();
      if (n.isNotEmpty && n != 'Üye') return n;
    }
  }
  for (final i in runtimeIkincielIlanlar) {
    if ((ilanOwnerById[i.id] ?? '') == e) {
      final n = i.poster.revealedName.trim();
      if (n.isNotEmpty && n != 'Üye') return n;
    }
  }
  return null;
}

void clearRuntimeIlanlar() {
  runtimeUzmanIlanlar.clear();
  runtimeBakiciIlanlar.clear();
  runtimeIkincielIlanlar.clear();
  ilanOwnerById.clear();
}
