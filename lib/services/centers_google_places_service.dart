import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/centers_data.dart';
import 'google_places_config.dart';

/// Google Places API (New) — searchText / searchNearby.
///
/// Eski legacy endpoint'ler (`/maps/api/place/nearbysearch/json`) kullanılmaz;
/// bunlar referer kısıtlı anahtarla REQUEST_DENIED üretir ve Cloud Errors doldurur.
class CentersGooglePlacesService {
  CentersGooglePlacesService._();

  static const _searchTextUrl =
      'https://places.googleapis.com/v1/places:searchText';
  static const _searchNearbyUrl =
      'https://places.googleapis.com/v1/places:searchNearby';

  static const _fieldMask =
      'places.id,places.displayName,places.formattedAddress,places.shortFormattedAddress,places.location,places.types,places.rating,places.userRatingCount,places.nationalPhoneNumber,places.regularOpeningHours';

  static const _textQueries = <String>[
    'özel eğitim ve rehabilitasyon merkezi',
    'özel eğitim rehabilitasyon merkezi',
    'özel eğitim merkezi',
    'rehabilitasyon merkezi',
    'fizik tedavi merkezi',
    'fizik tedavi ve rehabilitasyon',
    'fizyoterapi merkezi',
    'medikal malzeme',
    'medikal malzeme satışı',
    'ortopedik medikal',
    'ortez protez',
    'engelli yürüteç medikal',
    'empower inovasyon',
  ];

  static const _nearbyTypes = <String>[
    'physiotherapist',
  ];

  static final Map<String, List<MetoCenter>> _cache = {};
  static String? lastError;

  static Future<List<MetoCenter>> searchNearby({
    required double latitude,
    required double longitude,
    required String city,
    double radiusKm = 40,
  }) async {
    lastError = null;
    if (!GooglePlacesConfig.isConfigured) {
      lastError = 'GOOGLE_MAPS_API_KEY tanımlı değil.';
      debugPrint('[Places] $lastError');
      return const [];
    }

    final radiusM = (radiusKm.clamp(1, 50) * 1000).toDouble();
    final cacheKey =
        'new-v1|${latitude.toStringAsFixed(3)},${longitude.toStringAsFixed(3)}|${radiusM.round()}|$city';
    final cached = _cache[cacheKey];
    if (cached != null) return List<MetoCenter>.from(cached);

    final byKey = <String, MetoCenter>{};
    var nextId = 900000;
    final errors = <String>[];

    void ingest(List<MetoCenter> batch) {
      for (final c in batch) {
        final key =
            '${c.name.toLowerCase()}|${c.lat.toStringAsFixed(5)}|${c.lng.toStringAsFixed(5)}';
        if (byKey.containsKey(key)) continue;
        byKey[key] = c;
        nextId = math.max(nextId, c.id + 1);
      }
    }

    for (final q in _textQueries) {
      try {
        final batch = await _searchText(
          query: '$q $city Türkiye',
          lat: latitude,
          lng: longitude,
          radiusM: radiusM,
          city: city,
          startId: nextId,
        );
        ingest(batch.where((c) {
          return _haversineKm(latitude, longitude, c.lat, c.lng) <=
              radiusKm + 10;
        }).toList());
      } catch (e, st) {
        errors.add('$e');
        debugPrint('[Places] searchText "$q" hata: $e\n$st');
      }
    }

    for (final type in _nearbyTypes) {
      try {
        final batch = await _searchNearbyType(
          includedType: type,
          lat: latitude,
          lng: longitude,
          radiusM: radiusM,
          city: city,
          startId: nextId,
          keywordHint: type,
        );
        ingest(batch.where((c) {
          return _haversineKm(latitude, longitude, c.lat, c.lng) <=
              radiusKm + 10;
        }).toList());
      } catch (e, st) {
        errors.add('$e');
        debugPrint('[Places] searchNearby type=$type hata: $e\n$st');
      }
    }

    if (byKey.isEmpty && errors.isNotEmpty) {
      final joined = errors.join(' | ');
      if (joined.contains('referer') ||
          joined.contains('PERMISSION_DENIED') ||
          joined.contains('403')) {
        lastError =
            'Google API key HTTP referrer kısıtı yüzünden engellendi. '
            'Cloud Console → Credentials → Application restrictions = None yapın.';
      } else {
        lastError = errors.first;
      }
    }

    final list = byKey.values.toList()
      ..sort((a, b) {
        final da = _haversineKm(latitude, longitude, a.lat, a.lng);
        final db = _haversineKm(latitude, longitude, b.lat, b.lng);
        return da.compareTo(db);
      });

    _cache[cacheKey] = list;
    debugPrint('[Places] $city → ${list.length} sonuç (Places API New)');
    return list;
  }

  static Future<List<MetoCenter>> _searchText({
    required String query,
    required double lat,
    required double lng,
    required double radiusM,
    required String city,
    required int startId,
  }) async {
    final body = <String, dynamic>{
      'textQuery': query,
      'languageCode': 'tr',
      'regionCode': 'TR',
      'pageSize': 20,
      'locationBias': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radiusM,
        },
      },
    };

    final json = await _postJson(_searchTextUrl, body);
    final places = (json['places'] as List?) ?? const [];
    return _parseNewPlaces(
      places,
      city: city,
      startId: startId,
      keyword: query,
    );
  }

  static Future<List<MetoCenter>> _searchNearbyType({
    required String includedType,
    required double lat,
    required double lng,
    required double radiusM,
    required String city,
    required int startId,
    required String keywordHint,
  }) async {
    final body = <String, dynamic>{
      'includedTypes': [includedType],
      'maxResultCount': 20,
      'languageCode': 'tr',
      'regionCode': 'TR',
      'locationRestriction': {
        'circle': {
          'center': {'latitude': lat, 'longitude': lng},
          'radius': radiusM,
        },
      },
    };

    final json = await _postJson(_searchNearbyUrl, body);
    final places = (json['places'] as List?) ?? const [];
    return _parseNewPlaces(
      places,
      city: city,
      startId: startId,
      keyword: keywordHint,
    );
  }

  static Future<Map<String, dynamic>> _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    final res = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': GooglePlacesConfig.apiKey,
            'X-Goog-FieldMask': _fieldMask,
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));

    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(res.body);
      decoded = raw is Map<String, dynamic>
          ? raw
          : <String, dynamic>{'raw': raw};
    } catch (_) {
      throw StateError(
        'Places HTTP ${res.statusCode}: geçersiz JSON (${res.body.length} byte)',
      );
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = decoded['error'] is Map
          ? (decoded['error'] as Map)['message']?.toString()
          : decoded['message']?.toString();
      throw StateError(
        'Places HTTP ${res.statusCode}: ${msg ?? res.reasonPhrase ?? 'error'}',
      );
    }

    if (decoded['error'] is Map) {
      final err = decoded['error'] as Map;
      throw StateError(
        'Places API: ${err['status'] ?? ''} ${err['message'] ?? err}',
      );
    }

    return decoded;
  }

  static List<MetoCenter> _parseNewPlaces(
    List places, {
    required String city,
    required int startId,
    required String keyword,
  }) {
    final out = <MetoCenter>[];
    var id = startId;

    for (final raw in places) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);

      final display = m['displayName'];
      final name = display is Map
          ? (display['text']?.toString() ?? '').trim()
          : (m['name']?.toString() ?? '').trim();
      if (name.isEmpty) continue;
      if (!_isRelevantName(name, keyword)) continue;

      final loc = m['location'];
      if (loc is! Map) continue;
      final plat = (loc['latitude'] as num?)?.toDouble();
      final plng = (loc['longitude'] as num?)?.toDouble();
      if (plat == null || plng == null) continue;

      final types = ((m['types'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final category = _categoryFor(name: name, types: types, keyword: keyword);
      if (category == 'SKIP') continue;

      final address = (m['formattedAddress'] ??
              m['shortFormattedAddress'] ??
              city)
          .toString()
          .trim();
      final rating = (m['rating'] as num?)?.toDouble() ?? 0;
      final reviews = (m['userRatingCount'] as num?)?.toInt() ?? 0;
      final phone = (m['nationalPhoneNumber']?.toString() ?? '').trim();
      final hours = _hoursFrom(m['regularOpeningHours']);

      id++;
      out.add(MetoCenter(
        id: id,
        city: city,
        ilce: _guessIlce(address),
        name: name,
        category: category,
        address: address.isEmpty ? city : address,
        phone: phone.isEmpty ? '—' : phone,
        hours: hours.isEmpty ? '—' : hours,
        services: _servicesFor(category),
        rating: rating,
        reviews: reviews,
        color: _colorFor(category),
        lat: plat,
        lng: plng,
      ));
    }
    return out;
  }

  static String _hoursFrom(dynamic opening) {
    if (opening is! Map) return '';
    final weekday = opening['weekdayDescriptions'];
    if (weekday is! List || weekday.isEmpty) return '';
    return weekday.take(2).map((e) => e.toString()).join(' · ');
  }

  static bool _isRelevantName(String name, String keyword) {
    final n = _norm(name);
    final k = _norm(keyword);

    if ((n.contains('dil ve konusma') ||
            n.contains('konusma terapi') ||
            n.contains('dil terapi')) &&
        !n.contains('rehabilitasyon') &&
        !n.contains('ozel egitim') &&
        !n.contains('fizik')) {
      return false;
    }
    if ((n.contains('noroloji') || n.contains('neuro')) &&
        !n.contains('rehabilitasyon') &&
        !n.contains('fizik')) {
      return false;
    }

    const positives = [
      'ozel egitim',
      'egitim ve rehabilitasyon',
      'egitim rehabilitasyon',
      'ozel rehabilitasyon',
      'rehabilitasyon',
      'fizik tedavi',
      'fizyoterapi',
      'physiotherap',
      'medikal',
      'ortopedik',
      'ortez',
      'protez',
      'saglik malzem',
      'tibbi cihaz',
      'oerm',
      'empower',
      'inovasyon',
      'yurutec',
      'walker',
    ];
    if (positives.any(n.contains)) return true;

    if (k.contains('physio') ||
        k.contains('hospital') ||
        k.contains('medical') ||
        k.contains('drugstore')) {
      if (n.contains('eczane') ||
          n.contains('hastane') ||
          n.contains('hospital')) {
        return n.contains('rehab') ||
            n.contains('fizik') ||
            n.contains('fizyo') ||
            n.contains('ozel egitim') ||
            n.contains('rehabilitasyon');
      }
    }

    const negatives = [
      'otel',
      'hotel',
      'restoran',
      'market',
      'banka',
      'cami',
      'avm',
    ];
    if (negatives.any(n.contains)) return false;

    return k.contains('egitim') ||
        k.contains('rehabilitasyon') ||
        k.contains('fizyo') ||
        k.contains('fizik') ||
        k.contains('medikal') ||
        k.contains('ortoped') ||
        k.contains('malzeme');
  }

  static String _categoryFor({
    required String name,
    required List<String> types,
    required String keyword,
  }) {
    final n = _norm('$name ${types.join(' ')} $keyword');
    if (n.contains('medikal') ||
        n.contains('ortoped') ||
        n.contains('ortez') ||
        n.contains('protez') ||
        n.contains('saglik malzem') ||
        n.contains('tibbi cihaz') ||
        n.contains('empower') ||
        n.contains('yurutec') ||
        n.contains('walker')) {
      return 'Medikal';
    }
    if (n.contains('eczane') && !n.contains('medikal')) return 'SKIP';
    if (n.contains('ozel egitim') ||
        n.contains('egitim ve rehabilitasyon') ||
        n.contains('egitim rehabilitasyon') ||
        n.contains('ozel rehabilitasyon') ||
        n.contains('aba') ||
        n.contains('otizm') ||
        n.contains('oerm') ||
        n.contains('rehabilitasyon')) {
      return 'Özel Eğitim';
    }
    if (n.contains('fizik') ||
        n.contains('fizyo') ||
        n.contains('physiotherap')) {
      return 'Fizik Tedavi';
    }
    if (n.contains('dil') ||
        n.contains('konusma') ||
        n.contains('speech') ||
        n.contains('norolo') ||
        n.contains('neuro')) {
      return 'SKIP';
    }
    return 'Özel Eğitim';
  }

  static Color _colorFor(String category) => switch (category) {
        'Fizik Tedavi' => const Color(0xFF1A6B4A),
        'Özel Eğitim' => const Color(0xFF2563EB),
        'Medikal' => const Color(0xFFF4A832),
        _ => const Color(0xFF0F766E),
      };

  static List<String> _servicesFor(String category) => switch (category) {
        'Fizik Tedavi' => ['Fizyoterapi', 'Rehabilitasyon'],
        'Özel Eğitim' => ['Özel Eğitim', 'Destek Eğitimi'],
        'Medikal' => ['Medikal Malzeme', 'Ortez / Protez'],
        _ => ['Rehabilitasyon', 'Danışmanlık'],
      };

  static String _guessIlce(String address) {
    final parts = address
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length >= 2) return parts[parts.length - 2];
    if (parts.isNotEmpty) return parts.first;
    return '—';
  }

  static String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll('İ', 'i')
        .replaceAll('I', 'i')
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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
