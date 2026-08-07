// İlan fotoğrafları — yalnızca Cloudflare R2 (Supabase Storage kullanılmaz).
// Yükleme: Supabase Edge Function `r2-upload` → R2 PUT
// Görüntüleme: R2_PUBLIC_URL (r2.dev public access açık olmalı)
//
// Secrets (Supabase Dashboard → Edge Functions → Secrets):
//   R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET_NAME,
//   R2_ACCOUNT_ID, R2_PUBLIC_URL

import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class R2StorageService {
  R2StorageService._();

  static const maxBytes = 8 * 1024 * 1024;

  /// Görseli R2'ye yükler; public HTTPS URL döner.
  static Future<String> uploadBytes({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty) {
      throw StateError('Boş görsel yüklenemez.');
    }
    if (bytes.lengthInBytes > maxBytes) {
      throw StateError(
        'Fotoğraf 8 MB sınırını aşıyor. Daha küçük bir görsel seçin.',
      );
    }

    final client = Supabase.instance.client;
    final session = client.auth.currentSession;
    final user = client.auth.currentUser;
    if (session == null || user == null) {
      throw StateError('Fotoğraf yüklemek için giriş yapmalısınız.');
    }

    final mime = contentType.trim().isEmpty ? 'image/jpeg' : contentType.trim();
    final name = fileName.trim().isEmpty ? 'photo.jpg' : fileName.trim();

    try {
      final res = await client.functions.invoke(
        'r2-upload',
        body: {
          'fileName': name,
          'contentType': mime,
          'dataBase64': base64Encode(bytes),
        },
      );

      final data = res.data;
      if (data is Map) {
        final err = data['error']?.toString();
        if (err != null && err.isNotEmpty) {
          throw StateError(err);
        }
        final url = data['url']?.toString().trim() ?? '';
        if (url.startsWith('http://') || url.startsWith('https://')) {
          return url;
        }
      }
      throw StateError('R2 yanıtında public URL yok.');
    } on FunctionException catch (e) {
      final details = e.details?.toString() ?? e.reasonPhrase ?? '';
      final lower = details.toLowerCase();
      if (lower.contains('secret') || lower.contains('eksik')) {
        throw StateError(
          'R2 ayarları eksik. Supabase’de r2-upload secrets kontrol edin.',
        );
      }
      if (e.status == 404) {
        throw StateError(
          'r2-upload fonksiyonu yok. supabase functions deploy r2-upload',
        );
      }
      throw StateError(
        details.isNotEmpty
            ? 'R2 yükleme hatası: $details'
            : 'R2 yükleme başarısız (${e.status}).',
      );
    }
  }
}
