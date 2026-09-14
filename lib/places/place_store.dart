import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/centers_data.dart';
import '../utils/async_timeout.dart';
import 'place_models.dart';

/// Mekân satırı yalnız [ensurePlaceForReview] ile açılır (arama/pan/detay yazmaz).
class PlaceStore {
  PlaceStore._();
  static final PlaceStore instance = PlaceStore._();

  SupabaseClient get _db => Supabase.instance.client;

  String lookupKey(MetoCenter c) {
    return normalizeGooglePlaceId(c.googlePlaceId) ?? catalogPlaceKey(c.id);
  }

  Future<List<PlaceReview>> loadReviews(MetoCenter center) async {
    try {
      final key = lookupKey(center);
      final place = await withNetworkTimeout<Map<String, dynamic>?>(
        _db.from('places').select('id').eq('google_place_id', key).maybeSingle(),
      );
      final placeId = place?['id']?.toString();
      if (placeId == null || placeId.isEmpty) return const [];
      final rows = await withNetworkTimeout<List<dynamic>>(
        _db
            .from('place_accessibility_reviews')
            .select()
            .eq('place_id', placeId)
            .order('created_at', ascending: false),
      );
      return rows
          .whereType<Map>()
          .map((e) => PlaceReview.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// İlk değerlendirme / güncelleme. Arama burayı çağırmaz.
  Future<void> submitReview({
    required MetoCenter center,
    required Map<String, int> criteria,
    String note = '',
  }) async {
    final user = _db.auth.currentUser;
    if (user == null) {
      throw StateError('Değerlendirmek için giriş yapın.');
    }
    final placeId = await ensurePlaceForReview(center);
    final payload = {
      'place_id': placeId,
      'user_id': user.id,
      'criteria': criteria,
      'note': note.trim(),
    };
    await withNetworkTimeout(
      _db.from('place_accessibility_reviews').upsert(
            payload,
            onConflict: 'user_id,place_id',
          ),
    );
  }

  Future<String> ensurePlaceForReview(MetoCenter center) async {
    final key = lookupKey(center);
    final existing = await withNetworkTimeout<Map<String, dynamic>?>(
      _db.from('places').select('id').eq('google_place_id', key).maybeSingle(),
    );
    final existingId = existing?['id']?.toString();
    if (existingId != null && existingId.isNotEmpty) return existingId;
    try {
      final row = await withNetworkTimeout<Map<String, dynamic>>(
        _db
            .from('places')
            .insert({
              'google_place_id': key,
              'name': center.name,
              'address': center.address,
              'city': center.city,
              'ilce': center.ilce,
              'lat': center.lat,
              'lng': center.lng,
              'category': center.category,
              'source': normalizeGooglePlaceId(center.googlePlaceId) == null
                  ? 'catalog'
                  : 'google',
            })
            .select('id')
            .single(),
      );
      return row['id'].toString();
    } catch (_) {
      final again = await withNetworkTimeout<Map<String, dynamic>?>(
        _db.from('places').select('id').eq('google_place_id', key).maybeSingle(),
      );
      final againId = again?['id']?.toString();
      if (againId != null && againId.isNotEmpty) return againId;
      rethrow;
    }
  }
}
