import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cocuk_profil_store.dart';
import 'kullanici_profil_store.dart';

class BildirimAyarlari {
  const BildirimAyarlari({
    this.ilanlar = true,
    this.mesajlar = true,
    this.duyurular = true,
  });

  final bool ilanlar;
  final bool mesajlar;
  final bool duyurular;

  int get acikSayisi =>
      (ilanlar ? 1 : 0) + (mesajlar ? 1 : 0) + (duyurular ? 1 : 0);

  String get menuSub {
    if (acikSayisi == 0) return 'Kapalı';
    if (acikSayisi == 3) return 'Tümü açık';
    return '$acikSayisi bildirim açık';
  }

  Map<String, dynamic> toJson() => {
        'ilanlar': ilanlar,
        'mesajlar': mesajlar,
        'duyurular': duyurular,
      };

  factory BildirimAyarlari.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BildirimAyarlari();
    return BildirimAyarlari(
      ilanlar: json['ilanlar'] != false,
      mesajlar: json['mesajlar'] != false,
      duyurular: json['duyurular'] != false,
    );
  }

  BildirimAyarlari copyWith({
    bool? ilanlar,
    bool? mesajlar,
    bool? duyurular,
  }) =>
      BildirimAyarlari(
        ilanlar: ilanlar ?? this.ilanlar,
        mesajlar: mesajlar ?? this.mesajlar,
        duyurular: duyurular ?? this.duyurular,
      );
}

class FavoriIlanRef {
  const FavoriIlanRef({
    required this.kind,
    required this.id,
    required this.title,
    this.konum = '',
    this.fiyat = '',
  });

  final String kind;
  final int id;
  final String title;
  final String konum;
  final String fiyat;

  String get key => '$kind:$id';

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'id': id,
        'title': title,
        'konum': konum,
        'fiyat': fiyat,
      };

  factory FavoriIlanRef.fromJson(Map<String, dynamic> json) => FavoriIlanRef(
        kind: json['kind']?.toString() ?? 'uzman',
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString() ?? '',
        konum: json['konum']?.toString() ?? '',
        fiyat: json['fiyat']?.toString() ?? '',
      );
}

class UserCloudProfile {
  const UserCloudProfile({
    this.photoData,
    this.profil = const KullaniciProfil(),
    this.cocuk = const CocukProfil(),
    this.favorites = const [],
    this.notifications = const BildirimAyarlari(),
  });

  final String? photoData;
  final KullaniciProfil profil;
  final CocukProfil cocuk;
  final List<FavoriIlanRef> favorites;
  final BildirimAyarlari notifications;
}

String _localKey(String email, String suffix) {
  final e = email.trim().toLowerCase();
  return 'user_cloud_${e.isEmpty ? 'anon' : e}_$suffix';
}

Future<UserCloudProfile> loadUserCloudProfile(String email) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final local = await _loadLocal(email);

  if (user != null) {
    try {
      final row = await client
          .from('user_profiles')
          .select()
          .eq('owner_id', user.id)
          .maybeSingle();
      if (row != null) {
        var profile = _fromRow(Map<String, dynamic>.from(row));

        // Bulutta favori yok ama yerelde varsa: eski sessiz kayıt
        // hatalarından kurtar ve buluta geri yaz.
        if (profile.favorites.isEmpty && local.favorites.isNotEmpty) {
          profile = UserCloudProfile(
            photoData: profile.photoData ?? local.photoData,
            profil: profile.profil.isEmpty ? local.profil : profile.profil,
            cocuk: profile.cocuk,
            favorites: local.favorites,
            notifications: profile.notifications,
          );
          await _persistCloudProfile(email: email, profile: profile);
        }

        await _cacheLocally(email, profile);
        return profile;
      }

      // Bulutta satır yok → yereli yükle ve ilk kez senkronla
      if (local.favorites.isNotEmpty ||
          (local.photoData != null && local.photoData!.isNotEmpty) ||
          !local.profil.isEmpty) {
        await _persistCloudProfile(email: email, profile: local);
      }
      return local;
    } catch (_) {
      // Tablo yok / ağ → yerel
    }
  }

  return local;
}

Future<void> upsertUserCloudProfile({
  required String email,
  String? photoData,
  bool clearPhoto = false,
  KullaniciProfil? profil,
  CocukProfil? cocuk,
  List<FavoriIlanRef>? favorites,
  BildirimAyarlari? notifications,
}) async {
  final current = await loadUserCloudProfile(email);
  final next = UserCloudProfile(
    photoData: clearPhoto
        ? null
        : (photoData ?? current.photoData),
    profil: profil ?? current.profil,
    cocuk: cocuk ?? current.cocuk,
    favorites: favorites ?? current.favorites,
    notifications: notifications ?? current.notifications,
  );
  await _cacheLocally(email, next);
  await _persistCloudProfile(
    email: email,
    profile: next,
    photoChanged: clearPhoto || photoData != null,
  );
}

/// Favori / profil alanlarını buluta yazar.
/// Fotoğraf her seferinde gönderilmez (büyük base64 upsert'i bozmasın).
Future<void> _persistCloudProfile({
  required String email,
  required UserCloudProfile profile,
  bool photoChanged = false,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  final payload = <String, dynamic>{
    'owner_id': user.id,
    'owner_email': email.trim().toLowerCase(),
    'profil': profile.profil.toJson(),
    'cocuk': profile.cocuk.toJson(),
    'favorites': profile.favorites.map((e) => e.toJson()).toList(),
    'notifications': profile.notifications.toJson(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  if (photoChanged) {
    payload['photo_data'] = profile.photoData;
  }

  try {
    await client.from('user_profiles').upsert(
      payload,
      onConflict: 'owner_id',
    );
  } catch (_) {
    // Fotoğraf boyutu / ağ: en azından favorileri ayrı dene
    try {
      await client.from('user_profiles').upsert(
        {
          'owner_id': user.id,
          'owner_email': email.trim().toLowerCase(),
          'favorites': profile.favorites.map((e) => e.toJson()).toList(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'owner_id',
      );
    } catch (_) {
      // Yerel kayıt duruyor; sonraki girişte merge ile kurtarılır
    }
  }
}

UserCloudProfile _fromRow(Map<String, dynamic> row) {
  final profilRaw = row['profil'];
  final cocukRaw = row['cocuk'];
  final favRaw = row['favorites'];
  final notifRaw = row['notifications'];

  return UserCloudProfile(
    photoData: row['photo_data']?.toString(),
    profil: profilRaw is Map
        ? KullaniciProfil.fromJson(Map<String, dynamic>.from(profilRaw))
        : const KullaniciProfil(),
    cocuk: cocukRaw is Map
        ? CocukProfil.fromJson(Map<String, dynamic>.from(cocukRaw))
        : const CocukProfil(),
    favorites: favRaw is List
        ? favRaw
            .whereType<Map>()
            .map((e) => FavoriIlanRef.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const [],
    notifications: notifRaw is Map
        ? BildirimAyarlari.fromJson(Map<String, dynamic>.from(notifRaw))
        : const BildirimAyarlari(),
  );
}

Future<UserCloudProfile> _loadLocal(String email) async {
  final prefs = await SharedPreferences.getInstance();
  final photo = prefs.getString(_localKey(email, 'photo'));
  KullaniciProfil profil = const KullaniciProfil();
  CocukProfil cocuk = const CocukProfil();
  var favorites = <FavoriIlanRef>[];
  var notifications = const BildirimAyarlari();

  final profilRaw = prefs.getString(_localKey(email, 'profil'));
  if (profilRaw != null && profilRaw.isNotEmpty) {
    try {
      profil = KullaniciProfil.fromJson(
        Map<String, dynamic>.from(jsonDecode(profilRaw) as Map),
      );
    } catch (_) {}
  } else {
    profil = await loadKullaniciProfil(email);
  }

  final cocukRaw = prefs.getString(_localKey(email, 'cocuk'));
  if (cocukRaw != null && cocukRaw.isNotEmpty) {
    try {
      cocuk = CocukProfil.fromJson(
        Map<String, dynamic>.from(jsonDecode(cocukRaw) as Map),
      );
    } catch (_) {}
  } else {
    cocuk = await loadCocukProfil(email);
  }

  final favRaw = prefs.getString(_localKey(email, 'favorites'));
  if (favRaw != null && favRaw.isNotEmpty) {
    try {
      favorites = (jsonDecode(favRaw) as List)
          .whereType<Map>()
          .map((e) => FavoriIlanRef.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {}
  }

  final notifRaw = prefs.getString(_localKey(email, 'notifications'));
  if (notifRaw != null && notifRaw.isNotEmpty) {
    try {
      notifications = BildirimAyarlari.fromJson(
        Map<String, dynamic>.from(jsonDecode(notifRaw) as Map),
      );
    } catch (_) {}
  }

  // Eski foto anahtarı
  final legacyPhoto = prefs.getString(
    'user_profil_foto_${email.trim().toLowerCase().isEmpty ? 'anon' : email.trim().toLowerCase()}',
  );

  return UserCloudProfile(
    photoData: (photo != null && photo.isNotEmpty) ? photo : legacyPhoto,
    profil: profil,
    cocuk: cocuk,
    favorites: favorites,
    notifications: notifications,
  );
}

Future<void> _cacheLocally(String email, UserCloudProfile profile) async {
  final prefs = await SharedPreferences.getInstance();
  if (profile.photoData == null || profile.photoData!.isEmpty) {
    await prefs.remove(_localKey(email, 'photo'));
  } else {
    await prefs.setString(_localKey(email, 'photo'), profile.photoData!);
  }
  await prefs.setString(
    _localKey(email, 'profil'),
    jsonEncode(profile.profil.toJson()),
  );
  await prefs.setString(
    _localKey(email, 'cocuk'),
    jsonEncode(profile.cocuk.toJson()),
  );
  await prefs.setString(
    _localKey(email, 'favorites'),
    jsonEncode(profile.favorites.map((e) => e.toJson()).toList()),
  );
  await prefs.setString(
    _localKey(email, 'notifications'),
    jsonEncode(profile.notifications.toJson()),
  );

  // Eski store'larla uyumluluk
  await saveKullaniciProfil(email, profile.profil);
  await saveCocukProfil(email, profile.cocuk);
  final fotoKey =
      'user_profil_foto_${email.trim().toLowerCase().isEmpty ? 'anon' : email.trim().toLowerCase()}';
  if (profile.photoData == null || profile.photoData!.isEmpty) {
    await prefs.remove(fotoKey);
  } else {
    await prefs.setString(fotoKey, profile.photoData!);
  }
}
