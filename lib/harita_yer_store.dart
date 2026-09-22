import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/centers_data.dart';
import 'kredi_store.dart';
import 'utils/async_timeout.dart';

const kHaritaYerBildirimPerOdul = 5;
const kHaritaErisimKategori = 'Erişilebilirlik';
const kHaritaYerKategoriSecenekleri = <String>[
  'Özel Eğitim',
  'Fizik Tedavi',
  'Medikal',
];
const kHaritaErisimSecenekleri = <String>[
  'Rampa',
  'Engelli WC',
  'Asansör',
  'Düz giriş',
  'Engelli otopark',
];

bool haritaNoteFotoUrlOk(String url) {
  final raw = url.trim();
  if (!raw.startsWith('https://')) return false;
  if (raw.length < 16 || raw.length > 500) return false;
  if (raw.contains(' ') || raw.contains('..')) return false;
  return true;
}

String haritaEncodeErisimNote(
  Iterable<String> selected,
  String extra, {
  Iterable<String> photoUrls = const [],
}) {
  final parts = <String>[];
  final tags = [
    for (final t in kHaritaErisimSecenekleri)
      if (selected.contains(t)) t,
  ];
  if (tags.isNotEmpty) parts.add('Erişim: ${tags.join(', ')}');
  for (final raw in photoUrls) {
    final url = raw.trim();
    if (haritaNoteFotoUrlOk(url)) parts.add('Foto: $url');
  }
  final extraTrim = extra.trim();
  if (extraTrim.isNotEmpty) parts.add(extraTrim);
  return parts.join('\n');
}

List<String> haritaParseErisimTags(String note) {
  final lines = note.split('\n');
  final tagged = lines.cast<String>().where((l) {
    final s = l.trim().toLowerCase();
    return s.startsWith('erişim:') || s.startsWith('erisim:');
  });
  final line = tagged.isEmpty ? '' : tagged.first;
  if (line.isEmpty) {
    final hay = haritaFoldName(note);
    return [
      for (final t in kHaritaErisimSecenekleri)
        if (hay.contains(haritaFoldName(t))) t,
    ];
  }
  final rest = line.replaceFirst(RegExp(r'^[Ee]ri[şsS]im:\s*'), '');
  final parts = rest.split(',').map(haritaFoldName).toSet();
  return [
    for (final t in kHaritaErisimSecenekleri)
      if (parts.contains(haritaFoldName(t))) t,
  ];
}

List<String> haritaParseFotoUrls(String note) {
  return [
    for (final line in note.split('\n'))
      if (line.trim().toLowerCase().startsWith('foto:'))
        line.trim().substring(5).trim(),
  ].where(haritaNoteFotoUrlOk).toList();
}

String haritaErisimNoteBody(String note) {
  return note
      .split('\n')
      .where((l) {
        final s = l.trim().toLowerCase();
        return s.isNotEmpty &&
            !s.startsWith('erişim:') &&
            !s.startsWith('erisim:') &&
            !s.startsWith('foto:');
      })
      .join('\n')
      .trim();
}

/// Üye bildirimi pinleri (Google Places 800000’den başlar).
const kHaritaUyeYerIdBase = 8000000;

bool isHaritaUyeYeri(int id) => id >= kHaritaUyeYerIdBase;

final Map<String, List<String>> haritaIndexedNotePhotos = {};

String haritaYerSourceKey({
  required String name,
  required double lat,
  required double lng,
}) {
  return '${haritaFoldName(name)}|'
      '${lat.toStringAsFixed(5)}|'
      '${lng.toStringAsFixed(5)}';
}

void indexHaritaNotePhotos(HaritaYerBildirim item) {
  final urls = haritaParseFotoUrls(item.note);
  final key = haritaYerSourceKey(
    name: item.name,
    lat: item.lat,
    lng: item.lng,
  );
  if (urls.isEmpty) {
    haritaIndexedNotePhotos.remove(key);
    return;
  }
  haritaIndexedNotePhotos[key] = urls;
}

final Map<int, HaritaYerBildirim> haritaUyeYerByCenterId = {};

void indexHaritaUyeYer(HaritaYerBildirim item) {
  indexHaritaNotePhotos(item);
  if (item.id <= 0) return;
  haritaUyeYerByCenterId[kHaritaUyeYerIdBase + item.id] = item;
}

void unindexHaritaUyeYer(int dbId) {
  if (dbId <= 0) return;
  final item = haritaUyeYerByCenterId.remove(kHaritaUyeYerIdBase + dbId);
  if (item == null) return;
  haritaIndexedNotePhotos.remove(
    haritaYerSourceKey(name: item.name, lat: item.lat, lng: item.lng),
  );
}

bool haritaYerSahibiMi(int centerId, String email) {
  final item = haritaUyeYerByCenterId[centerId];
  final owner = (item?.userEmail ?? '').trim().toLowerCase();
  final me = email.trim().toLowerCase();
  return owner.isNotEmpty && me.isNotEmpty && owner == me;
}

/// Haritada işaretlenen yer / otomatik ad — Google mekân adıyla eşleşmez.
bool haritaYerNameIsGeneric(String name) {
  final f = haritaFoldName(name);
  return f.isEmpty ||
      f.contains('haritada isaretlenen') ||
      f.contains('isaretlenen yer') ||
      f.endsWith(' isaretlenen yer');
}

/// Üye bildirimi ile Google/katalog pini aynı mekân mı (yaklaşık 180 m).
const kHaritaYerMatchKm = 0.18;

bool haritaYerAyniMekan(MetoCenter center, HaritaYerBildirim item) {
  if (isHaritaUyeYeri(center.id) &&
      haritaUyeYerByCenterId[center.id]?.id == item.id) {
    return true;
  }
  if (item.lat == 0 && item.lng == 0) return false;
  final km = geoDistanceKm(center.lat, center.lng, item.lat, item.lng);
  if (km > kHaritaYerMatchKm) return false;
  final placeName = haritaFoldName(center.name);
  final itemName = haritaFoldName(item.name);
  final namesMatch = placeName.isNotEmpty &&
      itemName.isNotEmpty &&
      (placeName == itemName ||
          placeName.contains(itemName) ||
          itemName.contains(placeName));
  final nearbyOk = haritaYerNameIsGeneric(item.name) || km <= 0.08;
  return namesMatch || nearbyOk;
}

List<HaritaYerBildirim> haritaYerBildirimleriForCenter(MetoCenter center) {
  return [
    for (final item in haritaUyeYerByCenterId.values)
      if (haritaYerAyniMekan(center, item)) item,
  ];
}

/// Aynı mekânı bildiren benzersiz kişi sayısı.
int haritaYerBildirimSayisi(MetoCenter center) {
  final seen = <String>{};
  var n = 0;
  for (final item in haritaYerBildirimleriForCenter(center)) {
    final mail = item.userEmail.trim().toLowerCase();
    final key = mail.isEmpty ? 'id:${item.id}' : mail;
    if (seen.add(key)) n++;
  }
  return n;
}

String haritaYerBildirimSayisiLabel(int n) {
  if (n <= 0) return '';
  return n == 1 ? '1 kişi bildirdi' : '$n kişi bildirdi';
}

/// Her erişim özelliğini kaç benzersiz kişi işaretledi.
Map<String, int> haritaYerOzellikSayilari(MetoCenter center) {
  final usersByTag = <String, Set<String>>{};
  for (final item in haritaYerBildirimleriForCenter(center)) {
    final mail = item.userEmail.trim().toLowerCase();
    final who = mail.isEmpty ? 'id:${item.id}' : mail;
    for (final tag in haritaParseErisimTags(item.note)) {
      usersByTag.putIfAbsent(tag, () => {}).add(who);
    }
  }
  return {
    for (final t in kHaritaErisimSecenekleri)
      if ((usersByTag[t]?.length ?? 0) > 0) t: usersByTag[t]!.length,
  };
}

String haritaYerOzellikLabel(String tag, int n) {
  if (n <= 0) return tag;
  return n == 1 ? '$tag · 1 kişi' : '$tag · $n kişi';
}

HaritaYerBildirim? findHaritaYerForCenter(MetoCenter center) {
  if (isHaritaUyeYeri(center.id)) {
    final own = haritaUyeYerByCenterId[center.id];
    if (own != null) return own;
  }
  HaritaYerBildirim? best;
  var bestKm = kHaritaYerMatchKm;
  for (final item in haritaYerBildirimleriForCenter(center)) {
    final km = geoDistanceKm(center.lat, center.lng, item.lat, item.lng);
    if (km <= bestKm) {
      bestKm = km;
      best = item;
    }
  }
  return best;
}

void indexHaritaNotePhotosForPlace(MetoCenter place, HaritaYerBildirim item) {
  final urls = haritaParseFotoUrls(item.note);
  if (urls.isEmpty) return;
  haritaIndexedNotePhotos[haritaYerSourceKey(
    name: place.name,
    lat: place.lat,
    lng: place.lng,
  )] = urls;
}

/// Google/katalog detayına üyenin rampa/WC/not/fotoğrafını işler.
MetoCenter overlayHaritaYerBildirimi(MetoCenter place) {
  final item = findHaritaYerForCenter(place);
  if (item == null) return place;
  final reported = item.toCenter();
  indexHaritaNotePhotosForPlace(place, item);
  for (final other in haritaYerBildirimleriForCenter(place)) {
    indexHaritaNotePhotosForPlace(place, other);
  }
  final tagSet = <String>{
    for (final m in haritaYerBildirimleriForCenter(place))
      ...haritaParseErisimTags(m.note),
  };
  final tags = [
    for (final t in kHaritaErisimSecenekleri)
      if (tagSet.contains(t)) t,
  ];
  final extra = haritaErisimNoteBody(item.note);
  final keepPlaceName =
      haritaYerNameIsGeneric(item.name) && place.name.trim().isNotEmpty;
  final placePhone = place.phone.trim();
  return MetoCenter(
    id: reported.id,
    city: place.city.trim().isEmpty ? item.city : place.city,
    ilce: place.ilce,
    name: keepPlaceName
        ? place.name
        : (item.name.trim().isNotEmpty ? item.name : place.name),
    category: reported.category,
    address: (place.address.trim().isEmpty || place.address.trim() == '—')
        ? reported.address
        : place.address,
    phone: (placePhone.isEmpty || placePhone == '—') ? item.phone : place.phone,
    hours: extra.isNotEmpty ? extra : reported.hours,
    services: tags.isNotEmpty ? tags : reported.services,
    rating: place.rating,
    reviews: place.reviews,
    color: reported.color,
    lat: place.lat != 0 ? place.lat : item.lat,
    lng: place.lng != 0 ? place.lng : item.lng,
  );
}

String haritaFoldName(String raw) {
  const tr = <String, String>{
    'ç': 'c',
    'Ç': 'c',
    'ğ': 'g',
    'Ğ': 'g',
    'ı': 'i',
    'I': 'i',
    'İ': 'i',
    'ö': 'o',
    'Ö': 'o',
    'ş': 's',
    'Ş': 's',
    'ü': 'u',
    'Ü': 'u',
  };
  final buf = StringBuffer();
  for (final rune in raw.trim().runes) {
    final ch = String.fromCharCode(rune);
    buf.write(tr[ch] ?? ch.toLowerCase());
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool haritaYerMatchesQuery(
  String query, {
  required String name,
  String category = '',
  String address = '',
  String ilce = '',
  List<String> services = const [],
}) {
  final q = haritaFoldName(query);
  if (q.isEmpty) return true;
  final hay = haritaFoldName(
    [name, category, address, ilce, ...services].join(' '),
  );
  return hay.contains(q);
}

bool haritaIyilikOdulThisReport(int reportCount) =>
    reportCount > 0 && reportCount % kHaritaYerBildirimPerOdul == 0;

int haritaIyilikKalan(int reportCount) {
  if (reportCount <= 0) return kHaritaYerBildirimPerOdul;
  final rem = reportCount % kHaritaYerBildirimPerOdul;
  return rem == 0 ? 0 : kHaritaYerBildirimPerOdul - rem;
}

Color haritaYerColor(String category) => switch (category) {
      'Fizik Tedavi' => const Color(0xFF1A6B4A),
      'Özel Eğitim' => const Color(0xFF2563EB),
      'Medikal' => const Color(0xFFF4A832),
      kHaritaErisimKategori => const Color(0xFF0F766E),
      _ => const Color(0xFF0F766E),
    };

List<String> haritaYerServices(String category) => switch (category) {
      'Fizik Tedavi' => ['Fizyoterapi', 'Rehabilitasyon'],
      'Özel Eğitim' => ['Özel Eğitim', 'Destek Eğitimi'],
      'Medikal' => ['Medikal Malzeme', 'Ortez / Protez'],
      kHaritaErisimKategori => List<String>.from(kHaritaErisimSecenekleri),
      _ => ['Rehabilitasyon', 'Danışmanlık'],
    };

class HaritaYerBildirim {
  const HaritaYerBildirim({
    required this.id,
    required this.name,
    required this.category,
    required this.city,
    this.ilce = '',
    this.address = '',
    this.phone = '',
    this.note = '',
    this.userEmail = '',
    this.lat = 0,
    this.lng = 0,
  });

  final int id;
  final String name;
  final String category;
  final String city;
  final String ilce;
  final String address;
  final String phone;
  final String note;
  final String userEmail;
  final double lat;
  final double lng;

  HaritaYerBildirim copyWith({String? note}) => HaritaYerBildirim(
        id: id,
        name: name,
        category: category,
        city: city,
        ilce: ilce,
        address: address,
        phone: phone,
        note: note ?? this.note,
        userEmail: userEmail,
        lat: lat,
        lng: lng,
      );

  MetoCenter toCenter() {
    indexHaritaUyeYer(this);
    final tags = haritaParseErisimTags(note);
    final extra = haritaErisimNoteBody(note);
    final isErisim =
        tags.isNotEmpty || category == kHaritaErisimKategori;
    final cat = isErisim
        ? kHaritaErisimKategori
        : (kHaritaYerKategoriSecenekleri.contains(category)
            ? category
            : kHaritaErisimKategori);
    return MetoCenter(
      id: kHaritaUyeYerIdBase + id,
      city: city,
      ilce: ilce.trim().isEmpty ? '—' : ilce.trim(),
      name: name,
      category: cat,
      address: address.trim().isEmpty ? city : address.trim(),
      phone: phone,
      hours: extra,
      services: tags.isNotEmpty
          ? tags
          : (isErisim
              ? const <String>['Erişilebilirlik bildirimi']
              : haritaYerServices(cat)),
      rating: 0,
      reviews: 0,
      color: haritaYerColor(cat),
      lat: lat,
      lng: lng,
    );
  }

  factory HaritaYerBildirim.fromJson(Map<String, dynamic> json) {
    return HaritaYerBildirim(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? kHaritaErisimKategori,
      city: json['city']?.toString() ?? '',
      ilce: json['ilce']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      userEmail: (json['user_email']?.toString() ?? '').trim().toLowerCase(),
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
    );
  }
}

class HaritaYerBildirResult {
  const HaritaYerBildirResult({
    required this.item,
    required this.reportCount,
    required this.awarded,
    this.newBalance,
  });

  final HaritaYerBildirim item;
  final int reportCount;
  final bool awarded;
  final int? newBalance;
}

String _schemaError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('harita_yer_bildir') ||
      s.contains('harita_yer_guncelle') ||
      s.contains('harita_yer_sil') ||
      s.contains('could not find the function') ||
      s.contains('schema cache') ||
      s.contains('does not exist')) {
    return 'Yer bildirimi için Supabase’de harita_yer_bildirimleri.sql dosyasını çalıştırın.';
  }
  return e.toString().replaceFirst('Exception: ', '');
}

Future<List<MetoCenter>> loadHaritaYerBildirimleri({String? city}) async {
  try {
    final cityName = (city ?? '').trim();
    final want = haritaFoldName(cityName);
    final rows = await withNetworkTimeout(
      () async {
        try {
          return await Supabase.instance.client
              .from('harita_yer_bildirimleri')
              .select(
                'id, name, category, city, ilce, address, phone, note, lat, lng, user_email',
              )
              .order('created_at', ascending: false)
              .limit(400);
        } catch (_) {
          return await Supabase.instance.client
              .from('harita_yer_bildirimleri')
              .select(
                'id, name, category, city, ilce, address, phone, note, lat, lng',
              )
              .order('created_at', ascending: false)
              .limit(400);
        }
      }(),
      message: 'Yer bildirimleri alınamadı.',
    );
    if (rows is! List) return const [];
    final out = <MetoCenter>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final item = HaritaYerBildirim.fromJson(Map<String, dynamic>.from(raw));
      item.toCenter();
      if (want.isNotEmpty && haritaFoldName(item.city) != want) continue;
      out.add(item.toCenter());
    }
    return out;
  } catch (_) {
    return const [];
  }
}

Future<HaritaYerBildirResult> submitHaritaYerBildirimi({
  required String email,
  required String name,
  required String category,
  required String city,
  String ilce = '',
  String address = '',
  String phone = '',
  String note = '',
  double lat = 0,
  double lng = 0,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Yer bildirmek için giriş yapın.');
  }
  final trimmed = name.trim();
  if (trimmed.length < 3) {
    throw StateError('Yer adı en az 3 karakter olmalı.');
  }
  if (city.trim().isEmpty) {
    throw StateError('İl seçin.');
  }
  final cat = category.trim().isEmpty
      ? kHaritaErisimKategori
      : category.trim();
  try {
    final raw = await withNetworkTimeout(
      Supabase.instance.client.rpc(
        'harita_yer_bildir',
        params: {
          'p_name': trimmed,
          'p_category': cat,
          'p_city': city.trim(),
          'p_ilce': ilce.trim(),
          'p_address': address.trim(),
          'p_phone': phone.trim(),
          'p_note': note.trim(),
          'p_lat': lat,
          'p_lng': lng,
        },
      ),
      message: 'Yer bildirilemedi.',
    );
    final map = _asMap(raw);
    if (map == null) {
      throw StateError('Yer kaydedilemedi.');
    }
    final id = (map['id'] as num?)?.toInt() ?? 0;
    final count = (map['report_count'] as num?)?.toInt() ?? 0;
    final awarded = map['awarded'] == true;
    final balance = (map['new_balance'] as num?)?.toInt();
    if (awarded && balance != null) {
      await saveUserKredi(
        email: email,
        balance: balance,
        welcomeGiftGiven: true,
      );
    }
    return HaritaYerBildirResult(
      item: HaritaYerBildirim(
        id: id,
        name: trimmed,
        category: cat,
        city: city.trim(),
        ilce: ilce.trim(),
        address: address.trim(),
        phone: phone.trim(),
        note: note.trim(),
        userEmail: email.trim().toLowerCase(),
        lat: lat,
        lng: lng,
      ),
      reportCount: count,
      awarded: awarded,
      newBalance: balance,
    );
  } catch (e) {
    if (e is StateError) rethrow;
    throw StateError(_schemaError(e));
  }
}

Future<HaritaYerBildirResult> updateHaritaYerBildirimi({
  required HaritaYerBildirim existing,
  required String note,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Yer bildirimini değiştirmek için giriş yapın.');
  }
  if (existing.id <= 0) {
    throw StateError('Geçersiz yer bildirimi.');
  }
  final nextNote = note.trim();
  try {
    try {
      await withNetworkTimeout(
        Supabase.instance.client.rpc(
          'harita_yer_guncelle',
          params: {
            'p_id': existing.id,
            'p_note': nextNote,
          },
        ),
        message: 'Yer bildirimi güncellenemedi.',
      );
    } catch (e) {
      if (_schemaError(e).contains('harita_yer_bildirimleri.sql')) {
        await withNetworkTimeout(
          Supabase.instance.client
              .from('harita_yer_bildirimleri')
              .update({'note': nextNote})
              .eq('id', existing.id),
          message: 'Yer bildirimi güncellenemedi.',
        );
      } else {
        rethrow;
      }
    }
    final item = existing.copyWith(note: nextNote);
    item.toCenter();
    return HaritaYerBildirResult(
      item: item,
      reportCount: 0,
      awarded: false,
    );
  } catch (e) {
    if (e is StateError) rethrow;
    throw StateError(_schemaError(e));
  }
}

Future<void> deleteHaritaYerBildirimi(int id) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Yer bildirimini silmek için giriş yapın.');
  }
  if (id <= 0) {
    throw StateError('Geçersiz yer bildirimi.');
  }
  try {
    try {
      await withNetworkTimeout(
        Supabase.instance.client.rpc(
          'harita_yer_sil',
          params: {'p_id': id},
        ),
        message: 'Yer bildirimi silinemedi.',
      );
    } catch (e) {
      if (_schemaError(e).contains('harita_yer_bildirimleri.sql')) {
        await withNetworkTimeout(
          Supabase.instance.client
              .from('harita_yer_bildirimleri')
              .delete()
              .eq('id', id),
          message: 'Yer bildirimi silinemedi.',
        );
      } else {
        rethrow;
      }
    }
    unindexHaritaUyeYer(id);
  } catch (e) {
    if (e is StateError) rethrow;
    throw StateError(_schemaError(e));
  }
}

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return null;
}
