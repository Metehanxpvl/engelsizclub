import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/centers_data.dart';

/// OpenStreetMap Nominatim üzerinden koordinat çevresindeki özel eğitim ve
/// fizik tedavi merkezlerini bulur. API anahtarı gerektirmez.
///
/// Public Nominatim servisi yoğun/toplu kullanım için değildir. Bu sınıf:
/// - aynı aramayı bellekte önbelleğe alır,
/// - istekleri en az 1100 ms arayla gönderir,
/// - koordinat çevresini viewbox ile sınırlar.
class CentersNominatimService {
  CentersNominatimService._();

  static const _endpoint = 'https://nominatim.openstreetmap.org/search';
  static const _contactEmail = 'sakir.caykara@gmail.com';

  static const _queries = <String>[
    'rehabilitasyon merkezi',
    'fizik tedavi',
  ];

  static final Map<String, List<MetoCenter>> _cache = {};
  static DateTime? _lastRequest;

  static Future<List<MetoCenter>> searchNearby({
    required double latitude,
    required double longitude,
    required String city,
    double radiusKm = 40,
  }) async {
    final cacheKey =
        '${latitude.toStringAsFixed(2)}|${longitude.toStringAsFixed(2)}|'
        '${radiusKm.round()}|${city.toLowerCase()}';
    final cached = _cache[cacheKey];
    if (cached != null) return List<MetoCenter>.from(cached);

    final latDelta = radiusKm / 111.0;
    final cosLat = math.cos(latitude * math.pi / 180).abs();
    final lngDelta = radiusKm / (111.0 * math.max(cosLat, 0.2));
    final viewbox =
        '${longitude - lngDelta},${latitude + latDelta},'
        '${longitude + lngDelta},${latitude - latDelta}';

    final found = <MetoCenter>[];
    final seen = <String>{};
    var id = 30000;

    for (final query in _queries) {
      await _respectRateLimit();
      try {
        final uri = Uri.parse(_endpoint).replace(queryParameters: {
          // Bölge zaten viewbox + bounded ile sınırlandığı için sorguya şehir
          // eklemiyoruz. Nominatim POI adlarını bu şekilde daha iyi buluyor.
          'q': query,
          'format': 'jsonv2',
          'addressdetails': '1',
          'namedetails': '1',
          'layer': 'poi',
          'limit': '25',
          'countrycodes': 'tr',
          'bounded': '1',
          'viewbox': viewbox,
          'accept-language': 'tr',
          // Public servis politikasında uygulamayı tanımlamak için.
          'email': _contactEmail,
        });
        final response = await http.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Accept-Language': 'tr',
          },
        ).timeout(const Duration(seconds: 15));
        _lastRequest = DateTime.now();
        if (response.statusCode != 200) continue;

        final decoded = jsonDecode(response.body);
        if (decoded is! List) continue;

        for (final raw in decoded) {
          if (raw is! Map) continue;
          final row = raw.cast<String, dynamic>();
          final lat = double.tryParse(row['lat']?.toString() ?? '');
          final lng = double.tryParse(row['lon']?.toString() ?? '');
          if (lat == null || lng == null) continue;

          final distance =
              geoDistanceKm(latitude, longitude, lat, lng);
          if (distance > radiusKm + 5) continue;

          final displayName = row['display_name']?.toString().trim() ?? '';
          final names =
              (row['namedetails'] as Map?)?.cast<String, dynamic>() ?? {};
          final name = (names['name:tr'] ??
                  names['name'] ??
                  displayName.split(',').first)
              .toString()
              .trim();
          if (name.isEmpty || !_isRelevant(name, displayName)) continue;

          final dedupe =
              '${_normalize(name)}_${lat.toStringAsFixed(4)}_'
              '${lng.toStringAsFixed(4)}';
          if (!seen.add(dedupe)) continue;

          final address =
              (row['address'] as Map?)?.cast<String, dynamic>() ?? {};
          final district = (address['town'] ??
                  address['county'] ??
                  address['suburb'] ??
                  address['city_district'] ??
                  address['village'] ??
                  'Merkez')
              .toString();
          final category = _categoryFor(name);

          found.add(MetoCenter(
            id: id++,
            city: city,
            ilce: district,
            name: name,
            category: category,
            address: displayName.isEmpty
                ? '$district / $city'
                : displayName,
            phone: '—',
            hours: 'Saat bilgisi yok',
            services: _servicesFor(category),
            rating: 0,
            reviews: 0,
            color: _colorFor(category),
            lat: lat,
            lng: lng,
          ));
        }
      } catch (_) {
        _lastRequest = DateTime.now();
      }
    }

    found.sort((a, b) {
      final da = geoDistanceKm(latitude, longitude, a.lat, a.lng);
      final db = geoDistanceKm(latitude, longitude, b.lat, b.lng);
      return da.compareTo(db);
    });
    _cache[cacheKey] = found;
    return List<MetoCenter>.from(found);
  }

  static Future<void> _respectRateLimit() async {
    final previous = _lastRequest;
    if (previous == null) return;
    final elapsed = DateTime.now().difference(previous);
    const minimum = Duration(milliseconds: 1100);
    if (elapsed < minimum) {
      await Future<void>.delayed(minimum - elapsed);
    }
  }

  static bool _isRelevant(String name, String displayName) {
    final haystack = _normalize('$name $displayName');
    const terms = [
      'ozel egitim',
      'rehabilitasyon',
      'fizik tedavi',
      'fizyoterapi',
      'ergoterapi',
      'dil ve konusma',
      'konusma terap',
      'duyu butunleme',
      'aba terapi',
    ];
    return terms.any(haystack.contains);
  }

  static String _categoryFor(String name) {
    final normalized = _normalize(name);
    if (normalized.contains('ozel egitim') ||
        normalized.contains('aba')) {
      return 'Özel Eğitim & Rehabilitasyon';
    }
    if (normalized.contains('dil') ||
        normalized.contains('konusma')) {
      return 'Dil & Konuşma Terapisi';
    }
    if (normalized.contains('ergo') ||
        normalized.contains('duyu')) {
      return 'Ergoterapi';
    }
    return 'Fizik Tedavi & Rehabilitasyon';
  }

  static List<String> _servicesFor(String category) {
    if (category.contains('Özel Eğitim')) {
      return const ['Özel Eğitim', 'ABA Terapisi', 'Sosyal Beceri'];
    }
    if (category.contains('Dil')) {
      return const ['Konuşma Terapisi', 'Dil Terapisi', 'AAC'];
    }
    if (category.contains('Ergo')) {
      return const ['Ergoterapi', 'Duyu Bütünleme'];
    }
    return const ['Fizik Tedavi', 'Rehabilitasyon', 'Fizyoterapi'];
  }

  static Color _colorFor(String category) {
    if (category.contains('Özel Eğitim')) return const Color(0xFFE07A5F);
    if (category.contains('Dil')) return const Color(0xFF9C6DB3);
    if (category.contains('Ergo')) return const Color(0xFFF4A832);
    return const Color(0xFF1A6B4A);
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }
}
