import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'google_places_config.dart';

/// İl/ilçe koordinatı — Places API (New) textSearch ile (ayrı Geocoding API yok).
/// Böylece Cloud Console'da Geocoding API hataları oluşmaz.
class CentersGoogleGeocodeService {
  CentersGoogleGeocodeService._();

  static const _searchTextUrl =
      'https://places.googleapis.com/v1/places:searchText';

  static final Map<String, ({double lat, double lng})> _cache = {};

  static Future<({double lat, double lng})?> geocodePlace({
    required String city,
    String? ilce,
  }) async {
    final key = '${city.toLowerCase()}|${(ilce ?? '').toLowerCase()}';
    final cached = _cache[key];
    if (cached != null) return cached;

    if (!GooglePlacesConfig.isConfigured) {
      debugPrint('[Geocode] API key yok');
      return null;
    }

    final query = (ilce != null &&
            ilce.isNotEmpty &&
            !ilce.toLowerCase().contains('tümü'))
        ? '$ilce, $city, Türkiye'
        : '$city, Türkiye';

    try {
      final res = await http
          .post(
            Uri.parse(_searchTextUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': GooglePlacesConfig.apiKey,
              'X-Goog-FieldMask': 'places.location,places.displayName',
            },
            body: jsonEncode({
              'textQuery': query,
              'languageCode': 'tr',
              'regionCode': 'TR',
              'pageSize': 1,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Geocode] HTTP ${res.statusCode}: ${res.body}');
        return null;
      }

      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      if (body['error'] != null) {
        debugPrint('[Geocode] API error: ${body['error']}');
        return null;
      }

      final places = body['places'];
      if (places is! List || places.isEmpty) return null;
      final first = places.first;
      if (first is! Map) return null;
      final loc = first['location'];
      if (loc is! Map) return null;
      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;

      final point = (lat: lat, lng: lng);
      _cache[key] = point;
      return point;
    } catch (e, st) {
      debugPrint('[Geocode] hata: $e\n$st');
      return null;
    }
  }
}
