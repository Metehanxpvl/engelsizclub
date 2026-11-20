import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/centers_data.dart';
import '../utils/tr_norm.dart';
import 'google_places_config.dart';
import 'harita_google_kota.dart';

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
      // Sadece ad + konum (Pro kademe). Puan/telefon/saat istenmez → Enterprise ücreti yok.
      'places.id,places.displayName,places.formattedAddress,places.shortFormattedAddress,places.location,places.types';

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

  static const _textConcurrency = 4;

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
            '${_norm(c.name)}|${c.lat.toStringAsFixed(5)}|${c.lng.toStringAsFixed(5)}';
        if (byKey.containsKey(key)) continue;
        byKey[key] = c;
        nextId = math.max(nextId, c.id + 1);
      }
    }

    // Harvest text queries in parallel chunks (concurrency ~4).
    for (var i = 0; i < _textQueries.length; i += _textConcurrency) {
      final end = math.min(i + _textConcurrency, _textQueries.length);
      final chunk = _textQueries.sublist(i, end);
      final futures = <Future<List<MetoCenter>>>[];
      for (var j = 0; j < chunk.length; j++) {
        final q = chunk[j];
        final startId = nextId + (j + 1) * 100;
        futures.add(() async {
          try {
            final batch = await _searchText(
              query: '$q $city Türkiye',
              lat: latitude,
              lng: longitude,
              radiusM: radiusM,
              city: city,
              startId: startId,
            );
            return batch
                .where(
                  (c) =>
                      _haversineKm(latitude, longitude, c.lat, c.lng) <=
                      radiusKm + 10,
                )
                .toList();
          } catch (e, st) {
            errors.add('$e');
            debugPrint('[Places] searchText "$q" hata: $e\n$st');
            return const <MetoCenter>[];
          }
        }());
      }
      final batches = await Future.wait(futures);
      for (final batch in batches) {
        ingest(batch);
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

  /// Free-text Places search for a typed center / place name.
  ///
  /// Uses looser relevance than [searchNearby] harvest so named places
  /// (e.g. "Özel … Merkezi") are kept even without rehab keyword hits.
  static Future<List<MetoCenter>> searchByQuery({
    required String query,
    required double latitude,
    required double longitude,
    required String city,
    double radiusKm = 40,
  }) async {
    lastError = null;
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    if (!GooglePlacesConfig.isConfigured) {
      lastError = 'GOOGLE_MAPS_API_KEY tanımlı değil.';
      debugPrint('[Places] $lastError');
      return const [];
    }

    final radiusM = (radiusKm.clamp(1, 50) * 1000).toDouble();
    final cacheKey =
        'q|${_norm(trimmed)}|${_norm(city)}|${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}|${radiusM.round()}';
    final cached = _cache[cacheKey];
    if (cached != null) return List<MetoCenter>.from(cached);

    var textQuery = trimmed;
    final qNorm = _norm(trimmed);
    final cityNorm = _norm(city);
    if (cityNorm.isNotEmpty && !qNorm.contains(cityNorm)) {
      textQuery = '$trimmed $city Türkiye';
    }

    try {
      // Prefer the raw typed query first; city suffix can hide exact names.
      var batch = await _searchText(
        query: trimmed,
        lat: latitude,
        lng: longitude,
        radiusM: radiusM,
        city: city,
        startId: 910000,
        strictRelevance: false,
        relevanceKeyword: trimmed,
        allowSkipCategories: false,
      );

      if (batch.isEmpty && textQuery != trimmed) {
        batch = await _searchText(
          query: textQuery,
          lat: latitude,
          lng: longitude,
          radiusM: radiusM,
          city: city,
          startId: 920000,
          strictRelevance: false,
          relevanceKeyword: trimmed,
          allowSkipCategories: false,
        );
      }

      final byKey = <String, MetoCenter>{};
      // Free-text: keep a wide net; UI listing applies softer distance when
      // an active query is present.
      final maxKm = radiusKm + 80;
      for (final c in batch) {
        if (_haversineKm(latitude, longitude, c.lat, c.lng) > maxKm) {
          continue;
        }
        final key =
            '${_norm(c.name)}|${c.lat.toStringAsFixed(5)}|${c.lng.toStringAsFixed(5)}';
        byKey.putIfAbsent(key, () => c);
      }

      final list = byKey.values.toList()
        ..sort((a, b) {
          final da = _haversineKm(latitude, longitude, a.lat, a.lng);
          final db = _haversineKm(latitude, longitude, b.lat, b.lng);
          return da.compareTo(db);
        });

      // Never poison the cache with empty misses (API blips / filters).
      if (list.isNotEmpty) {
        _cache[cacheKey] = list;
      }
      debugPrint(
        '[Places] query="$trimmed" $city → ${list.length} sonuç',
      );
      return list;
    } catch (e, st) {
      lastError = '$e';
      debugPrint('[Places] searchByQuery hata: $e\n$st');
      return const [];
    }
  }

  static Future<List<MetoCenter>> _searchText({
    required String query,
    required double lat,
    required double lng,
    required double radiusM,
    required String city,
    required int startId,
    bool strictRelevance = true,
    String? relevanceKeyword,
    bool allowSkipCategories = true,
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
      keyword: relevanceKeyword ?? query,
      strictRelevance: strictRelevance,
      allowSkipCategories: allowSkipCategories,
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
    if (!await HaritaGoogleKota.izinAl()) {
      throw StateError('Google harita araması kapalı veya aylık sınır doldu.');
    }
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
    bool strictRelevance = true,
    bool allowSkipCategories = true,
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

      final address = (m['formattedAddress'] ??
              m['shortFormattedAddress'] ??
              city)
          .toString()
          .trim();

      final types = ((m['types'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList();
      final typeHay = types.join(' ');
      final mallType = typeHay.contains('shopping_mall') ||
          typeHay.contains('department_store');
      final keepByMallIntent = !strictRelevance &&
          _isMallQuery(_norm(keyword)) &&
          (mallType || _looksLikeMall(_norm('$name $address')));

      if (!keepByMallIntent &&
          !_isRelevantName(
            name,
            keyword,
            address: address,
            strictRelevance: strictRelevance,
          )) {
        continue;
      }

      final loc = m['location'];
      if (loc is! Map) continue;
      final plat = (loc['latitude'] as num?)?.toDouble();
      final plng = (loc['longitude'] as num?)?.toDouble();
      if (plat == null || plng == null) continue;

      var category = _categoryFor(name: name, types: types, keyword: keyword);
      if (category == 'SKIP') {
        if (allowSkipCategories) continue;
        // Free-text: keep speech/neuro/other hits visible as Özel Eğitim.
        category = 'Özel Eğitim';
      }

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

  static bool _isRelevantName(
    String name,
    String keyword, {
    String address = '',
    bool strictRelevance = true,
  }) {
    final n = _norm('$name $address');
    final k = _norm(keyword);

    // Harvest-only exclusions. Free-text must keep dil/konuşma / nöroloji
    // when the user typed them (or any place Google returned for the query).
    if (strictRelevance) {
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
    }

    // Harvest keeps excluding malls/hotels/etc. Free-text must NOT drop AVMs
    // when the user typed "avm" / mall intent — otherwise Places hits vanish.
    const harvestNegatives = [
      'otel',
      'hotel',
      'restoran',
      'market',
      'banka',
      'cami',
      'avm',
    ];
    const freeTextNegatives = [
      'otel',
      'hotel',
      'restoran',
      'banka',
      'cami',
    ];
    final negatives = strictRelevance ? harvestNegatives : freeTextNegatives;
    final junkHit = negatives.any(n.contains);
    final junkInQuery = negatives.any(k.contains) ||
        (!strictRelevance && _isMallQuery(k));
    if (junkHit && !junkInQuery) return false;

    if (!strictRelevance) {
      if (_isMallQuery(k) && _looksLikeMall(n)) return true;
      final tokens = searchTokens(keyword, minLen: 2);
      if (tokens.isEmpty) return true;
      // Keep if ANY significant token matches (Places already ranked).
      return tokens.any(n.contains);
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

  static String _norm(String s) => normTrForSearch(s);

  static bool _isMallQuery(String k) {
    return k.contains('avm') ||
        k.contains('alisveris') ||
        k.contains('alis veris') ||
        k.contains('mall') ||
        k.contains('shopping');
  }

  static bool _looksLikeMall(String n) {
    return n.contains('avm') ||
        n.contains('alisveris') ||
        n.contains('mall') ||
        n.contains('shopping') ||
        n.contains('forum') ||
        n.contains('outlet') ||
        n.contains('meydan');
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
