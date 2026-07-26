import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/centers_data.dart';
import 'centers_nominatim_service.dart';

/// Yakındaki özel eğitim / rehabilitasyon merkezlerini ücretsiz kaynaklardan çeker:
/// - Photon (Komoot / OSM) — tarayıcıda CORS dostu, konum odaklı arama
/// - Overpass API — OSM etiketli POI'ler (birden fazla mirror)
class CentersOsmService {
  CentersOsmService._();

  static const _photonUrl = 'https://photon.komoot.io/api/';
  static const _nominatimUrl = 'https://nominatim.openstreetmap.org/search';

  static const _overpassMirrors = <String>[
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  static const _ua = 'EngelsizClub/1.0 (https://engelsizclub-e5842.web.app)';

  /// Arama anahtar kelimeleri (Photon / Nominatim).
  static const _searchQueries = <String>[
    'özel eğitim rehabilitasyon merkezi',
    'özel eğitim merkezi',
    'rehabilitasyon merkezi',
    'fizyoterapi merkezi çocuk',
    'dil ve konuşma terapisi',
    'ergoterapi merkezi',
    'duyu bütünleme merkezi',
    'ABA terapi merkezi',
  ];

  static final Map<String, ({double lat, double lng})> _geoCache = {};
  static final Map<String, List<MetoCenter>> _centersCache = {};

  /// İl veya ilçe merkezinin yaklaşık koordinatı.
  static Future<({double lat, double lng})?> geocodePlace({
    required String city,
    String? ilce,
  }) async {
    final key = '${city.toLowerCase()}|${(ilce ?? '').toLowerCase()}';
    final cached = _geoCache[key];
    if (cached != null) return cached;

    final q = (ilce != null && ilce.isNotEmpty && ilce != kAllIlceler)
        ? '$ilce, $city, Türkiye'
        : '$city, Türkiye';

    // 1) Photon
    try {
      final uri = Uri.parse(_photonUrl).replace(queryParameters: {
        'q': q,
        'limit': '1',
        'lang': 'en',
      });
      final res = await http
          .get(uri, headers: const {'User-Agent': _ua, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final features = (body['features'] as List?) ?? const [];
        if (features.isNotEmpty) {
          final f = features.first as Map;
          final coords = (f['geometry'] as Map?)?['coordinates'] as List?;
          if (coords != null && coords.length >= 2) {
            final lng = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final point = (lat: lat, lng: lng);
            _geoCache[key] = point;
            return point;
          }
        }
      }
    } catch (_) {}

    // 2) Nominatim yedek
    try {
      final uri = Uri.parse(_nominatimUrl).replace(queryParameters: {
        'q': q,
        'format': 'json',
        'limit': '1',
        'countrycodes': 'tr',
      });
      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': _ua,
          'Accept-Language': 'tr',
        },
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
        if (list is List && list.isNotEmpty) {
          final first = list.first as Map;
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lng = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lng != null) {
            final point = (lat: lat, lng: lng);
            _geoCache[key] = point;
            return point;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Konum civarındaki gerçek merkezleri birleştirir (Photon + Overpass).
  static Future<List<MetoCenter>> fetchNear({
    required double lat,
    required double lng,
    required String city,
    double radiusKm = 45,
  }) async {
    final cacheKey =
        '${city.toLowerCase()}_${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}_${radiusKm.round()}';
    final cached = _centersCache[cacheKey];
    if (cached != null) return List<MetoCenter>.from(cached);

    final results = await Future.wait([
      CentersNominatimService.searchNearby(
        latitude: lat,
        longitude: lng,
        city: city,
        radiusKm: radiusKm,
      ),
      _fetchFromPhoton(lat: lat, lng: lng, city: city, radiusKm: radiusKm),
      _fetchFromOverpass(lat: lat, lng: lng, city: city, radiusKm: radiusKm),
    ]);

    final merged = _mergeAndRank(
      [...results[0], ...results[1], ...results[2]],
      originLat: lat,
      originLng: lng,
      radiusKm: radiusKm,
    );

    _centersCache[cacheKey] = merged;
    return List<MetoCenter>.from(merged);
  }

  static Future<List<MetoCenter>> _fetchFromPhoton({
    required double lat,
    required double lng,
    required String city,
    required double radiusKm,
  }) async {
    final out = <MetoCenter>[];
    final seen = <String>{};
    var id = 20000;

    // Paralel ama nazik: 4 sorgu birden, sonra kalanlar
    for (var i = 0; i < _searchQueries.length; i += 4) {
      final batch = _searchQueries.skip(i).take(4);
      final parts = await Future.wait(
        batch.map((q) => _photonSearch(
              query: q,
              lat: lat,
              lng: lng,
              city: city,
              radiusKm: radiusKm,
              startId: id,
              seen: seen,
            )),
      );
      for (final list in parts) {
        out.addAll(list);
        id += list.length + 5;
      }
    }
    return out;
  }

  static Future<List<MetoCenter>> _photonSearch({
    required String query,
    required double lat,
    required double lng,
    required String city,
    required double radiusKm,
    required int startId,
    required Set<String> seen,
  }) async {
    try {
      final uri = Uri.parse(_photonUrl).replace(queryParameters: {
        'q': '$query $city Türkiye',
        'lat': lat.toString(),
        'lon': lng.toString(),
        'limit': '25',
        'lang': 'en',
        'location_bias_scale': '0.9',
      });
      final res = await http
          .get(uri, headers: const {'User-Agent': _ua, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final features = (body['features'] as List?) ?? const [];
      final out = <MetoCenter>[];
      var id = startId;

      for (final raw in features) {
        if (raw is! Map) continue;
        final props = (raw['properties'] as Map?)?.cast<String, dynamic>() ?? {};
        final name = (props['name'] ?? props['osm_value'] ?? '').toString().trim();
        if (name.isEmpty || !_isRelevantCenter(name, props)) continue;

        final country = (props['country'] ?? props['countrycode'] ?? '')
            .toString()
            .toLowerCase();
        if (country.isNotEmpty &&
            country != 'turkey' &&
            country != 'türkiye' &&
            country != 'tr') {
          continue;
        }

        final coords = (raw['geometry'] as Map?)?['coordinates'] as List?;
        if (coords == null || coords.length < 2) continue;
        final plng = (coords[0] as num).toDouble();
        final plat = (coords[1] as num).toDouble();

        final dist = geoDistanceKm(lat, lng, plat, plng);
        if (dist > radiusKm + 8) continue;

        final dedupe =
            '${_norm(name)}_${plat.toStringAsFixed(4)}_${plng.toStringAsFixed(4)}';
        if (!seen.add(dedupe)) continue;

        final ilce = (props['district'] ??
                    props['suburb'] ??
                    props['city'] ??
                    props['county'] ??
                    'Merkez')
                .toString()
                .trim();
        final street = props['street']?.toString();
        final no = props['housenumber']?.toString();
        final addressParts = <String>[];
        if (street != null && street.isNotEmpty) {
          addressParts
              .add(no != null && no.isNotEmpty ? '$street No:$no' : street);
        }
        addressParts.add('$ilce / $city');

        final category = _categoryFromName(name);
        out.add(MetoCenter(
          id: id++,
          city: city,
          ilce: ilce.isEmpty ? 'Merkez' : ilce,
          name: name,
          category: category,
          address: addressParts.join(', '),
          phone: props['phone']?.toString() ?? '—',
          hours: 'Saat bilgisi yok',
          services: _servicesFrom(category),
          rating: 0,
          reviews: 0,
          color: _colorFor(category),
          lat: plat,
          lng: plng,
        ));
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('Photon search error: $e');
      return const [];
    }
  }

  static Future<List<MetoCenter>> _fetchFromOverpass({
    required double lat,
    required double lng,
    required String city,
    required double radiusKm,
  }) async {
    final radiusM = (radiusKm * 1000).round();
    final query = '''
[out:json][timeout:40];
(
  nwr["name"~"özel eğitim|ozel egitim|özel egitim|rehabilitasyon|fizyoterapi|fizik tedavi|ergoterapi|dil ve konuşma|dil terapi|konuşma terapi|çocuk gelişim|cocuk gelisim|aba terapi|duyu bütünleme|duyu butunleme|özel rehabilitasyon",i](around:$radiusM,$lat,$lng);
  nwr["healthcare"="rehabilitation"](around:$radiusM,$lat,$lng);
  nwr["healthcare"="physiotherapist"](around:$radiusM,$lat,$lng);
  nwr["healthcare"="speech_therapist"](around:$radiusM,$lat,$lng);
  nwr["healthcare"="occupational_therapist"](around:$radiusM,$lat,$lng);
  nwr["amenity"="clinic"]["name"~"özel|rehab|fizyo|terapi|eğitim|egitim|dil|ergo",i](around:$radiusM,$lat,$lng);
  nwr["amenity"="school"]["name"~"özel eğitim|rehabilitasyon|ozel egitim",i](around:$radiusM,$lat,$lng);
  nwr["office"="therapist"](around:$radiusM,$lat,$lng);
  nwr["social_facility:for"~"child|disabled|mental_health",i](around:$radiusM,$lat,$lng);
);
out center tags 120;
''';

    for (final mirror in _overpassMirrors) {
      try {
        final res = await http
            .post(
              Uri.parse(mirror),
              headers: const {
                'Content-Type': 'application/x-www-form-urlencoded',
                'User-Agent': _ua,
                'Accept': 'application/json',
              },
              body: {'data': query},
            )
            .timeout(const Duration(seconds: 40));
        if (res.statusCode != 200) continue;

        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final elements = (body['elements'] as List?) ?? const [];
        final out = <MetoCenter>[];
        final seen = <String>{};
        var id = 10000;

        for (final el in elements) {
          if (el is! Map) continue;
          final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? {};
          final name = tags['name']?.toString().trim();
          if (name == null || name.isEmpty) continue;
          if (!_isRelevantCenter(name, tags)) continue;

          double? plat;
          double? plng;
          if (el['type'] == 'node') {
            plat = (el['lat'] as num?)?.toDouble();
            plng = (el['lon'] as num?)?.toDouble();
          } else {
            final c = el['center'] as Map?;
            plat = (c?['lat'] as num?)?.toDouble();
            plng = (c?['lon'] as num?)?.toDouble();
          }
          if (plat == null || plng == null) continue;

          final dedupe =
              '${_norm(name)}_${plat.toStringAsFixed(4)}_${plng.toStringAsFixed(4)}';
          if (!seen.add(dedupe)) continue;

          final ilce = _districtFromTags(tags) ?? 'Merkez';
          final category = _categoryFromTags(tags, name);
          out.add(MetoCenter(
            id: id++,
            city: city,
            ilce: ilce,
            name: name,
            category: category,
            address: _addressFromTags(tags, city, ilce),
            phone: tags['phone']?.toString() ??
                tags['contact:phone']?.toString() ??
                '—',
            hours: tags['opening_hours']?.toString() ?? 'Saat bilgisi yok',
            services: _servicesFrom(category),
            rating: 0,
            reviews: 0,
            color: _colorFor(category),
            lat: plat,
            lng: plng,
          ));
        }
        if (out.isNotEmpty) return out;
      } catch (e) {
        if (kDebugMode) debugPrint('Overpass $mirror error: $e');
        continue;
      }
    }
    return const [];
  }

  static List<MetoCenter> _mergeAndRank(
    List<MetoCenter> raw, {
    required double originLat,
    required double originLng,
    required double radiusKm,
  }) {
    final seen = <String>{};
    final out = <MetoCenter>[];
    for (final c in raw) {
      final dist = geoDistanceKm(originLat, originLng, c.lat, c.lng);
      if (dist > radiusKm + 10) continue;
      final key =
          '${_norm(c.name)}_${c.lat.toStringAsFixed(3)}_${c.lng.toStringAsFixed(3)}';
      if (!seen.add(key)) continue;
      out.add(c);
    }
    out.sort((a, b) {
      final da = geoDistanceKm(originLat, originLng, a.lat, a.lng);
      final db = geoDistanceKm(originLat, originLng, b.lat, b.lng);
      return da.compareTo(db);
    });
    if (out.length > 80) return out.sublist(0, 80);
    return out;
  }

  static bool _isRelevantCenter(String name, Map<String, dynamic> tags) {
    final n = _norm(name);
    final hay = [
      n,
      _norm(tags['healthcare']?.toString() ?? ''),
      _norm(tags['amenity']?.toString() ?? ''),
      _norm(tags['office']?.toString() ?? ''),
      _norm(tags['osm_value']?.toString() ?? ''),
      _norm(tags['osm_key']?.toString() ?? ''),
    ].join(' ');

    const positives = [
      'ozel egitim',
      'rehabilitasyon',
      'fizyoterapi',
      'fizik tedavi',
      'ergoterapi',
      'dil terapi',
      'dil ve konusma',
      'konusma terapi',
      'duyu butunleme',
      'aba',
      'cocuk gelisim',
      'ozel rehabilitasyon',
      'speech',
      'occupational',
      'physiotherapist',
      'rehabilitation',
      'therapist',
    ];
    const negatives = [
      'otel',
      'hotel',
      'restoran',
      'restaurant',
      'market',
      'eczane',
      'pharmacy',
      'banka',
      'cami',
      'mosque',
      'benzin',
    ];
    if (negatives.any((k) => hay.contains(k))) return false;
    return positives.any((k) => hay.contains(k));
  }

  static String? _districtFromTags(Map<String, dynamic> tags) {
    for (final key in [
      'addr:district',
      'addr:suburb',
      'addr:city_district',
      'addr:neighbourhood',
      'addr:county',
    ]) {
      final v = tags[key]?.toString().trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static String _addressFromTags(
    Map<String, dynamic> tags,
    String city,
    String ilce,
  ) {
    final street = tags['addr:street']?.toString();
    final no = tags['addr:housenumber']?.toString();
    final parts = <String>[];
    if (street != null && street.isNotEmpty) {
      parts.add(no != null && no.isNotEmpty ? '$street No:$no' : street);
    }
    parts.add('$ilce / $city');
    return parts.join(', ');
  }

  static String _categoryFromTags(Map<String, dynamic> tags, String name) {
    final hc = tags['healthcare']?.toString().toLowerCase() ?? '';
    if (hc.contains('speech')) return 'Dil & Konuşma Terapisi';
    if (hc.contains('occupational')) return 'Ergoterapi';
    if (hc.contains('physio')) return 'Fizik Tedavi & Rehabilitasyon';
    return _categoryFromName(name);
  }

  static String _categoryFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('özel eğitim') ||
        n.contains('ozel egitim') ||
        n.contains('aba')) {
      return 'Özel Eğitim & Rehabilitasyon';
    }
    if (n.contains('dil') || n.contains('konuşma') || n.contains('konusma')) {
      return 'Dil & Konuşma Terapisi';
    }
    if (n.contains('ergo') || n.contains('duyu')) {
      return 'Ergoterapi';
    }
    if (n.contains('nöro') || n.contains('noro')) {
      return 'Çocuk Nörolojisi';
    }
    if (n.contains('fizyo') ||
        n.contains('fizik') ||
        n.contains('rehabilitasyon')) {
      return 'Fizik Tedavi & Rehabilitasyon';
    }
    if (n.contains('gelişim') || n.contains('gelisim')) {
      return 'Çocuk Gelişimi';
    }
    return 'Özel Eğitim & Rehabilitasyon';
  }

  static List<String> _servicesFrom(String category) {
    if (category.contains('Özel Eğitim')) {
      return const ['Özel Eğitim', 'ABA Terapisi', 'Sosyal Beceri'];
    }
    if (category.contains('Dil')) {
      return const ['Konuşma Terapisi', 'Dil Terapisi', 'AAC'];
    }
    if (category.contains('Ergo')) {
      return const ['Ergoterapi', 'Duyu Bütünleme'];
    }
    if (category.contains('Nöro')) {
      return const ['Çocuk Nöroloji', 'Gelişim Değerlendirme'];
    }
    if (category.contains('Gelişim')) {
      return const ['Gelişim Değerlendirme', 'Oyun Terapisi'];
    }
    return const ['Fizik Tedavi', 'Rehabilitasyon', 'Ergoterapi'];
  }

  static Color _colorFor(String category) {
    if (category.contains('Özel Eğitim')) return const Color(0xFFE07A5F);
    if (category.contains('Dil')) return const Color(0xFF9C6DB3);
    if (category.contains('Ergo')) return const Color(0xFFF4A832);
    if (category.contains('Nöro')) return const Color(0xFF6B9AC4);
    if (category.contains('Gelişim')) return const Color(0xFF1A6B4A);
    return const Color(0xFF1A6B4A);
  }

  static bool matchesIlce(MetoCenter c, String selectedIlce) {
    if (selectedIlce == kAllIlceler) return true;
    final a = _norm(selectedIlce);
    final b = _norm(c.ilce);
    if (a.isEmpty || b.isEmpty) return true;
    return b.contains(a) || a.contains(b);
  }

  static String _norm(String s) {
    return s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .trim();
  }
}
