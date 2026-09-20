import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/centers_data.dart';
import 'kredi_store.dart';
import 'utils/async_timeout.dart';

const kHaritaYerBildirimPerOdul = 5;
const kHaritaYerKategoriSecenekleri = <String>[
  'Özel Eğitim',
  'Fizik Tedavi',
  'Medikal',
];

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
      _ => const Color(0xFF0F766E),
    };

List<String> haritaYerServices(String category) => switch (category) {
      'Fizik Tedavi' => ['Fizyoterapi', 'Rehabilitasyon'],
      'Özel Eğitim' => ['Özel Eğitim', 'Destek Eğitimi'],
      'Medikal' => ['Medikal Malzeme', 'Ortez / Protez'],
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
  final double lat;
  final double lng;

  MetoCenter toCenter() {
    final cat = kHaritaYerKategoriSecenekleri.contains(category)
        ? category
        : 'Özel Eğitim';
    return MetoCenter(
      id: 8000000 + id,
      city: city,
      ilce: ilce.trim().isEmpty ? '—' : ilce.trim(),
      name: name,
      category: cat,
      address: address.trim().isEmpty ? city : address.trim(),
      phone: phone,
      hours: '',
      services: haritaYerServices(cat),
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
      category: json['category']?.toString() ?? 'Özel Eğitim',
      city: json['city']?.toString() ?? '',
      ilce: json['ilce']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
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
    final query = Supabase.instance.client
        .from('harita_yer_bildirimleri')
        .select(
          'id, name, category, city, ilce, address, phone, note, lat, lng',
        );
    final filtered = cityName.isEmpty
        ? query
        : query.eq('city_norm', haritaFoldName(cityName));
    final rows = await withNetworkTimeout(
      filtered.order('created_at', ascending: false).limit(400),
      message: 'Yer bildirimleri alınamadı.',
    );
    if (rows is! List) return const [];
    return [
      for (final raw in rows)
        if (raw is Map)
          HaritaYerBildirim.fromJson(Map<String, dynamic>.from(raw)).toCenter(),
    ];
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
  final cat = kHaritaYerKategoriSecenekleri.contains(category)
      ? category
      : 'Özel Eğitim';
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

Map<String, dynamic>? _asMap(dynamic raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is List && raw.isNotEmpty && raw.first is Map) {
    return Map<String, dynamic>.from(raw.first as Map);
  }
  return null;
}
