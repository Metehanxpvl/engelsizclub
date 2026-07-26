import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/centers_data.dart';
import 'google_places_config.dart';

/// Google Places Nearby Search ile yakındaki
/// özel eğitim / rehabilitasyon / fizik tedavi merkezlerini bulur.
class CentersGooglePlacesService {
  CentersGooglePlacesService._();

  static const _nearbyUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
  static const _detailsUrl =
      'https://maps.googleapis.com/maps/api/place/details/json';

  /// Nearby Search anahtar kelimeleri.
  static const _keywords = <String>[
    'özel eğitim rehabilitasyon merkezi',
    'özel eğitim merkezi',
    'rehabilitasyon merkezi',
    'fizik tedavi merkezi',
    'fizyoterapi',
    'dil ve konuşma terapisi',
    'ergoterapi',
    'duyu bütünleme',
  ];

  static final Map<String, List<MetoCenter>> _cache = {};

  /// place_id ↔ geçici MetoCenter.id (Place Details için).
  static final Map<int, String> _placeIds = {};

  /// Kullanıcı (veya odak) konumuna göre yakındaki merkezleri döndürür.
  /// [radiusKm] en fazla ~50 km (Google limiti).
  static Future<List<MetoCenter>> searchNearby({
    required double latitude,
    required double longitude,
    required String city,
    double radiusKm = 40,
  }) async {
    if (!GooglePlacesConfig.isConfigured) {
      debugPrint(
        'CentersGooglePlacesService: API anahtarı yok. '
        'google_places_config.dart veya --dart-define=GOOGLE_PLACES_API_KEY kullanın.',
      );
      return const [];
    }

    final radiusM = (radiusKm.clamp(1, 50) * 1000).round();
    final cacheKey =
        '${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}|$radiusM|$city';
    final cached = _cache[cacheKey];
    if (cached != null) return List<MetoCenter>.from(cached);

    final byKey = <String, MetoCenter>{};
    var nextId = 900000;

    for (final keyword in _keywords) {
      try {
        final batch = await _nearbySearch(
          lat: latitude,
          lng: longitude,
          radiusM: radiusM,
          keyword: keyword,
          city: city,
          startId: nextId,
        );
        for (final c in batch) {
          final dedupeKey =
              '${c.name.toLowerCase()}|${c.lat.toStringAsFixed(5)}|${c.lng.toStringAsFixed(5)}';
          if (byKey.containsKey(dedupeKey)) continue;
          byKey[dedupeKey] = c;
          nextId = math.max(nextId, c.id + 1);
        }
      } catch (e) {
        debugPrint('Places Nearby "$keyword" hata: $e');
      }
    }

    final list = byKey.values.toList()
      ..sort((a, b) {
        final da = _haversineKm(latitude, longitude, a.lat, a.lng);
        final db = _haversineKm(latitude, longitude, b.lat, b.lng);
        return da.compareTo(db);
      });

    // İlk 12 sonuç için telefon / saat (Place Details).
    final enriched = <MetoCenter>[];
    for (var i = 0; i < list.length; i++) {
      var c = list[i];
      if (i < 12) {
        final placeId = _placeIds[c.id];
        if (placeId != null) {
          final details = await _placeDetails(placeId);
          if (details != null) {
            c = MetoCenter(
              id: c.id,
              city: c.city,
              ilce: c.ilce,
              name: c.name,
              category: c.category,
              address:
                  details.address.isNotEmpty ? details.address : c.address,
              phone: details.phone.isNotEmpty ? details.phone : c.phone,
              hours: details.hours.isNotEmpty ? details.hours : c.hours,
              services: c.services,
              rating: c.rating,
              reviews: c.reviews,
              color: c.color,
              lat: c.lat,
              lng: c.lng,
            );
          }
        }
      }
      enriched.add(c);
    }

    _cache[cacheKey] = enriched;
    return enriched;
  }

  static Future<List<MetoCenter>> _nearbySearch({
    required double lat,
    required double lng,
    required int radiusM,
    required String keyword,
    required String city,
    required int startId,
  }) async {
    final uri = Uri.parse(_nearbyUrl).replace(queryParameters: {
      'location': '$lat,$lng',
      'radius': '$radiusM',
      'keyword': keyword,
      'language': 'tr',
      'key': GooglePlacesConfig.apiKey,
    });

    final res = await http
        .get(uri, headers: const {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw StateError('HTTP ${res.statusCode}');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final status = body['status']?.toString() ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      final msg = body['error_message']?.toString() ?? status;
      throw StateError('Places API: $msg');
    }

    final results = (body['results'] as List?) ?? const [];
    final out = <MetoCenter>[];
    var id = startId;

    for (final raw in results) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final name = (m['name']?.toString() ?? '').trim();
      if (name.isEmpty) continue;

      final geo = m['geometry'] as Map?;
      final loc = geo?['location'] as Map?;
      if (loc == null) continue;
      final plat = (loc['lat'] as num?)?.toDouble();
      final plng = (loc['lng'] as num?)?.toDouble();
      if (plat == null || plng == null) continue;

      final placeId = m['place_id']?.toString() ?? '';
      final vicinity = (m['vicinity']?.toString() ??
              m['formatted_address']?.toString() ??
              '')
          .trim();
      final rating = (m['rating'] as num?)?.toDouble() ?? 0;
      final reviews = (m['user_ratings_total'] as num?)?.toInt() ?? 0;
      final types = ((m['types'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final category = _categoryFor(name: name, types: types, keyword: keyword);
      final color = _colorFor(category);
      final services = _servicesFor(category);

      id++;
      final centerId = id;
      if (placeId.isNotEmpty) _placeIds[centerId] = placeId;

      out.add(MetoCenter(
        id: centerId,
        city: city,
        ilce: _guessIlce(vicinity),
        name: name,
        category: category,
        address: vicinity.isEmpty ? city : vicinity,
        phone: '—',
        hours: '—',
        services: services,
        rating: rating,
        reviews: reviews,
        color: color,
        lat: plat,
        lng: plng,
      ));
    }
    return out;
  }

  static Future<({String phone, String hours, String address})?> _placeDetails(
    String placeId,
  ) async {
    try {
      final uri = Uri.parse(_detailsUrl).replace(queryParameters: {
        'place_id': placeId,
        'fields':
            'formatted_phone_number,opening_hours,formatted_address,international_phone_number',
        'language': 'tr',
        'key': GooglePlacesConfig.apiKey,
      });
      final res = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['status']?.toString() != 'OK') return null;
      final r = body['result'] as Map? ?? {};
      final phone = (r['formatted_phone_number'] ??
              r['international_phone_number'] ??
              '')
          .toString()
          .trim();
      final address = (r['formatted_address'] ?? '').toString().trim();
      final weekday =
          ((r['opening_hours'] as Map?)?['weekday_text'] as List?) ?? const [];
      final hours = weekday.isEmpty
          ? ''
          : weekday.take(2).map((e) => e.toString()).join(' · ');
      return (phone: phone, hours: hours, address: address);
    } catch (_) {
      return null;
    }
  }

  static String _categoryFor({
    required String name,
    required List<String> types,
    required String keyword,
  }) {
    final hay =
        '${name.toLowerCase()} ${types.join(' ')} ${keyword.toLowerCase()}';
    final n = hay
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c');
    if (n.contains('fizik') ||
        n.contains('fizyo') ||
        n.contains('physiotherap')) {
      return 'Fizik Tedavi';
    }
    if (n.contains('dil') ||
        n.contains('konusma') ||
        n.contains('speech') ||
        n.contains('language')) {
      return 'Dil Terapisi';
    }
    if (n.contains('ozel egitim') ||
        n.contains('aba') ||
        n.contains('otizm')) {
      return 'Özel Eğitim';
    }
    if (n.contains('ergo') || n.contains('duyu')) {
      return 'Ergoterapi';
    }
    if (n.contains('norolo') || n.contains('neuro')) {
      return 'Nöroloji';
    }
    return 'Rehabilitasyon';
  }

  static Color _colorFor(String category) {
    switch (category) {
      case 'Fizik Tedavi':
        return const Color(0xFF1A6B4A);
      case 'Özel Eğitim':
        return const Color(0xFF2563EB);
      case 'Dil Terapisi':
        return const Color(0xFFE07A5F);
      case 'Ergoterapi':
        return const Color(0xFF7C3AED);
      case 'Nöroloji':
        return const Color(0xFFDB2777);
      default:
        return const Color(0xFF0F766E);
    }
  }

  static List<String> _servicesFor(String category) {
    return switch (category) {
      'Fizik Tedavi' => ['Fizyoterapi', 'Rehabilitasyon'],
      'Özel Eğitim' => ['Özel Eğitim', 'Destek Eğitimi'],
      'Dil Terapisi' => ['Dil ve Konuşma Terapisi'],
      'Ergoterapi' => ['Ergoterapi', 'Duyu Bütünleme'],
      'Nöroloji' => ['Nöroloji', 'Değerlendirme'],
      _ => ['Rehabilitasyon', 'Danışmanlık'],
    };
  }

  static String _guessIlce(String address) {
    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) return parts.last;
    if (parts.isNotEmpty) return parts.first;
    return '—';
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  static double _rad(double d) => d * math.pi / 180;
}
