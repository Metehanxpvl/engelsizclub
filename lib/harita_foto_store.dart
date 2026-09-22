import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/centers_data.dart';
import 'harita_yer_store.dart';
import 'services/image_optimize_service.dart';
import 'services/r2_storage_service.dart';
import 'utils/async_timeout.dart';

const kHaritaFotoSource = 'map';
const kHaritaFotoMaxPerPlace = 8;

String haritaPlaceSourceKey(MetoCenter center) {
  return haritaPlaceSourceKeyParts(
    name: center.name,
    lat: center.lat,
    lng: center.lng,
  );
}

String haritaPlaceSourceKeyParts({
  required String name,
  required double lat,
  required double lng,
}) {
  return haritaYerSourceKey(name: name, lat: lat, lng: lng);
}

bool isPublicHaritaPhotoUrl(String url) {
  final raw = url.trim();
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https') return false;
  if (raw.contains(' ') || raw.contains('..')) return false;
  if (raw.length < 16 || raw.length > 500) return false;
  final host = uri.host.toLowerCase();
  return host.endsWith('.r2.dev') ||
      host.endsWith('.r2.cloudflarestorage.com') ||
      host.endsWith('.engelsizclub.com');
}

class HaritaPlacePhoto {
  const HaritaPlacePhoto({
    required this.id,
    required this.photoUrl,
    required this.thumbnailUrl,
    this.altText = '',
    this.isMine = false,
  });

  final int id;
  final String photoUrl;
  final String thumbnailUrl;
  final String altText;
  final bool isMine;

  String get previewUrl =>
      thumbnailUrl.trim().isEmpty ? photoUrl : thumbnailUrl;

  factory HaritaPlacePhoto.fromJson(Map<String, dynamic> json) {
    return HaritaPlacePhoto(
      id: (json['id'] as num?)?.toInt() ?? 0,
      photoUrl: json['photo_url']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString() ?? '',
      altText: json['alt_text']?.toString() ?? '',
      isMine: json['is_mine'] == true,
    );
  }
}

String _schemaError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('harita_foto') ||
      s.contains('could not find the function') ||
      s.contains('schema cache') ||
      s.contains('place_photos') ||
      s.contains('does not exist')) {
    return 'Harita fotoğrafları için Supabase’de harita_place_photos.sql çalıştırın.';
  }
  return e.toString().replaceFirst('Exception: ', '');
}

List<HaritaPlacePhoto> _mergeNotePhotos(
  MetoCenter center,
  List<HaritaPlacePhoto> fromRpc,
) {
  final keys = <String>{
    haritaPlaceSourceKey(center),
    ...haritaPhotoLookupKeys(center),
  };
  final fromNote = <String>[
    for (final key in keys) ...?haritaIndexedNotePhotos[key],
  ];
  if (fromNote.isEmpty) return fromRpc;
  final seen = {for (final p in fromRpc) p.photoUrl};
  final mineNote = haritaYerSahibiMi(
    center.id,
    Supabase.instance.client.auth.currentUser?.email ?? '',
  );
  return [
    ...fromRpc,
    for (var i = 0; i < fromNote.length; i++)
      if (!seen.contains(fromNote[i]) && isPublicHaritaPhotoUrl(fromNote[i]))
        HaritaPlacePhoto(
          id: -1 - i,
          photoUrl: fromNote[i],
          thumbnailUrl: fromNote[i],
          isMine: mineNote,
        ),
  ];
}

List<String> haritaPhotoLookupKeys(MetoCenter center) {
  final keys = <String>{haritaPlaceSourceKey(center)};
  final item = findHaritaYerForCenter(center);
  if (item != null) {
    keys.add(
      haritaYerSourceKey(name: item.name, lat: item.lat, lng: item.lng),
    );
  }
  return keys.toList();
}

Future<List<HaritaPlacePhoto>> loadHaritaPlacePhotos(MetoCenter center) async {
  try {
    final seen = <String>{};
    final fromRpc = <HaritaPlacePhoto>[];
    for (final key in haritaPhotoLookupKeys(center)) {
      try {
        final raw = await withNetworkTimeout(
          Supabase.instance.client.rpc(
            'harita_foto_liste',
            params: {
              'p_source': kHaritaFotoSource,
              'p_source_key': key,
            },
          ),
          message: 'Fotoğraflar alınamadı.',
        );
        if (raw is! List) continue;
        for (final row in raw) {
          if (row is! Map) continue;
          final photo =
              HaritaPlacePhoto.fromJson(Map<String, dynamic>.from(row));
          if (seen.add(photo.photoUrl)) fromRpc.add(photo);
        }
      } catch (_) {}
    }
    return _mergeNotePhotos(center, fromRpc);
  } catch (_) {
    return _mergeNotePhotos(center, const []);
  }
}

class HaritaStagedPhoto {
  const HaritaStagedPhoto({
    required this.publicUrl,
    required this.thumbUrl,
    required this.objectKey,
    required this.bytesEst,
  });

  final String publicUrl;
  final String thumbUrl;
  final String objectKey;
  final int bytesEst;
}

Future<HaritaStagedPhoto> stageHaritaPlacePhoto(Uint8List bytes) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Fotoğraf yüklemek için giriş yapın.');
  }
  final pair = await ImageOptimizeService.forMapPlace(bytes);
  final photoPut = await R2StorageService.uploadPresigned(
    bytes: pair.photo.bytes,
    contentType: pair.photo.contentType,
    purpose: 'map-photo',
    variant: 'full',
  );
  if (photoPut == null) {
    throw StateError(
      'R2 yükleme alınamadı. Worker /sign veya R2 dart-define kontrol edin.',
    );
  }
  if (!isPublicHaritaPhotoUrl(photoPut.publicUrl)) {
    throw StateError('R2 public URL geçersiz.');
  }

  var thumbUrl = photoPut.publicUrl;
  final thumbPut = await R2StorageService.uploadPresigned(
    bytes: pair.thumb.bytes,
    contentType: pair.thumb.contentType,
    purpose: 'map-photo',
    variant: 'thumb',
  );
  if (thumbPut != null && isPublicHaritaPhotoUrl(thumbPut.publicUrl)) {
    thumbUrl = thumbPut.publicUrl;
  }
  return HaritaStagedPhoto(
    publicUrl: photoPut.publicUrl,
    thumbUrl: thumbUrl,
    objectKey: photoPut.key,
    bytesEst: pair.photo.bytes.lengthInBytes,
  );
}

Future<HaritaPlacePhoto> confirmHaritaPlacePhoto({
  required MetoCenter center,
  required HaritaStagedPhoto staged,
}) async {
  try {
    final raw = await withNetworkTimeout(
      Supabase.instance.client.rpc(
        'harita_foto_onayla',
        params: {
          'p_source': kHaritaFotoSource,
          'p_source_key': haritaPlaceSourceKey(center),
          'p_name': center.name,
          'p_city': center.city,
          'p_category': center.category,
          'p_lat': center.lat,
          'p_lng': center.lng,
          'p_photo_url': staged.publicUrl,
          'p_thumbnail_url': staged.thumbUrl,
          'p_alt_text': center.name,
          'p_object_key': staged.objectKey,
          'p_bytes_est': staged.bytesEst,
        },
      ),
      message: 'Fotoğraf kaydedilemedi.',
    );
    Map<String, dynamic> map = const {};
    if (raw is Map<String, dynamic>) {
      map = raw;
    } else if (raw is Map) {
      map = Map<String, dynamic>.from(raw);
    }
    return HaritaPlacePhoto(
      id: (map['id'] as num?)?.toInt() ?? 0,
      photoUrl: map['photo_url']?.toString() ?? staged.publicUrl,
      thumbnailUrl: map['thumbnail_url']?.toString() ?? staged.thumbUrl,
      altText: center.name,
      isMine: true,
    );
  } catch (e) {
    if (e is StateError) rethrow;
    throw StateError(_schemaError(e));
  }
}

Future<HaritaPlacePhoto> uploadHaritaPlacePhoto({
  required MetoCenter center,
  required Uint8List bytes,
}) async {
  final staged = await stageHaritaPlacePhoto(bytes);
  try {
    return await confirmHaritaPlacePhoto(center: center, staged: staged);
  } catch (_) {
    return HaritaPlacePhoto(
      id: 0,
      photoUrl: staged.publicUrl,
      thumbnailUrl: staged.thumbUrl,
      altText: center.name,
      isMine: true,
    );
  }
}

bool haritaFotoSilinebilir(MetoCenter center, HaritaPlacePhoto photo) {
  if (photo.isMine) return true;
  final email = Supabase.instance.client.auth.currentUser?.email ?? '';
  return photo.id <= 0 && haritaYerSahibiMi(center.id, email);
}

Future<void> deleteHaritaPlacePhoto({
  required MetoCenter center,
  required HaritaPlacePhoto photo,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Fotoğraf silmek için giriş yapın.');
  }
  if (!haritaFotoSilinebilir(center, photo)) {
    throw StateError('Bu fotoğrafı silme yetkiniz yok.');
  }

  var removed = false;
  if (photo.id > 0) {
    try {
      await withNetworkTimeout(
        Supabase.instance.client.rpc(
          'harita_foto_sil',
          params: {'p_id': photo.id},
        ),
        message: 'Fotoğraf silinemedi.',
      );
      removed = true;
    } catch (e) {
      try {
        await withNetworkTimeout(
          Supabase.instance.client
              .from('place_photos')
              .delete()
              .eq('id', photo.id),
          message: 'Fotoğraf silinemedi.',
        );
        removed = true;
      } catch (e2) {
        final hint = _schemaError(e);
        if (!hint.contains('harita_place_photos.sql')) {
          throw StateError(_schemaError(e2));
        }
      }
    }
  }

  final item = haritaUyeYerByCenterId[center.id];
  final me = (user.email ?? '').trim().toLowerCase();
  if (item != null && haritaYerSahibiMi(center.id, me)) {
    final drop = {photo.photoUrl.trim(), photo.thumbnailUrl.trim()}
      ..removeWhere((u) => u.isEmpty);
    final kept = [
      for (final u in haritaParseFotoUrls(item.note))
        if (!drop.contains(u)) u,
    ];
    if (kept.length != haritaParseFotoUrls(item.note).length) {
      await updateHaritaYerBildirimi(
        existing: item,
        note: haritaEncodeErisimNote(
          haritaParseErisimTags(item.note),
          haritaErisimNoteBody(item.note),
          photoUrls: kept,
        ),
      );
      removed = true;
    }
  }

  if (!removed) {
    throw StateError('Fotoğraf silinemedi.');
  }
}
