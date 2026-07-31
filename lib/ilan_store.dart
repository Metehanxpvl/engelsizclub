import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/ilanlar_data.dart';
import 'meto_theme.dart';
import 'widgets/user_avatar.dart';

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
      'age': i.age,
      'frequency': i.frequency,
      'note': i.note,
      'budget': i.budget,
      'posted': i.posted,
      'views': i.views,
      'offers': i.offers,
      'urgent': i.urgent,
      'photos': _photosToJson(i.photos, forLocalCache: forLocalCache),
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
  return UzmanIlani(
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
    photos: photos.length > kUzmanBakiciMaxPhotos
        ? photos.take(kUzmanBakiciMaxPhotos).toList()
        : photos,
    poster: _posterFrom(j),
  );
}

BakiciIlani _bakiciFromJson(Map<String, dynamic> j) {
  final photos = _photosFromJson(j['photos']);
  return BakiciIlani(
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
    photos: photos.length > kUzmanBakiciMaxPhotos
        ? photos.take(kUzmanBakiciMaxPhotos).toList()
        : photos,
    poster: _posterFrom(j),
  );
}

IkincielIlani _ikincielFromJson(Map<String, dynamic> j) {
  final photoVals = _photosFromJson(j['photos']);
  return IkincielIlani(
    id: (j['id'] as num?)?.toInt() ?? nextIlanId(),
    title: j['title']?.toString() ?? '',
    category: (j['category'] ?? 'Diğer').toString(),
    city: j['city']?.toString() ?? '',
    district: (j['district'] ?? '').toString(),
    condition: (j['condition'] ?? 'İyi').toString(),
    brand: (j['brand'] ?? '—').toString(),
    note: (j['note'] ?? '—').toString(),
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
  List<IlanPhoto> photos = const [],
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
    await Supabase.instance.client.from('ilanlar').insert(payload);
    try {
      await loadAllIlanlar(preferEmail: resolvedEmail);
    } catch (_) {
      // Ön bellek / ağ yenilemesi başarısız olsa da ilan buluta yazıldı.
    }
    return;
  } catch (e) {
    // Supabase yoksa yerel düş — yine de cihazlar arası paylaşılmaz.
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
            photos: cappedPhotos,
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
            photos: cappedPhotos.isEmpty
                ? const [IlanPhoto.swatch(Color(0xFFDCE8F5))]
                : cappedPhotos,
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

Future<void> updateIlanInCloud({
  required int id,
  required String kind,
  required String title,
  required String city,
  required String district,
  required String note,
  required String ownerEmail,
  String budget = '',
  String price = '',
  String uzmanlik = 'Uzman',
  String condition = 'İyi',
  List<IlanPhoto> photos = const [],
}) async {
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

  final myEmail = (user.email ?? '').trim().toLowerCase();
  final payload = <String, dynamic>{
    'title': title,
    'city': city,
    'district': district,
    'note': note,
    'budget': budget,
    'price': price,
    'uzmanlik': uzmanlik,
    'photos': cappedPhotos.map((p) => p.toJson()).toList(),
    if (kind == 'ikinciel') 'condition': condition,
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
