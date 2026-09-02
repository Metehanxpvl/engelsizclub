// İlan fotoğrafları: mevcut Supabase Edge Function `r2-upload` (uploadBytes).
// Ürün etiketi: istemci AWS SigV4 PUT → bucket engelsizclub-labels (upload).
// Anahtarlar yalnız dart-define; kaynak dosyada yok.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'r2_config.dart';

/// R2 yükleme — etiket görseli için SigV4; ilanlar için Edge Function.
class R2StorageService {
  R2StorageService._();

  static const maxBytes = 8 * 1024 * 1024;
  static const _region = 'auto';
  static const _service = 's3';

  /// Etiket görseli → public HTTPS URL. Önce SigV4, sonra isteğe bağlı Worker.
  static Future<String?> upload({
    required Uint8List bytes,
    required String objectKey,
    String contentType = 'image/jpeg',
  }) async {
    if (bytes.isEmpty || bytes.lengthInBytes > maxBytes) return null;

    final key = _sanitizeKey(objectKey);
    final mime =
        contentType.trim().isEmpty ? 'image/jpeg' : contentType.trim();

    if (R2Config.hasClientSigV4) {
      final url = await _uploadSigV4(
        bytes: bytes,
        objectKey: key,
        contentType: mime,
      );
      if (url != null) return url;
    }

    if (R2Config.hasWorker) {
      final url = await _uploadViaWorker(
        bytes: bytes,
        objectKey: key,
        contentType: mime,
      );
      if (url != null) return url;
    }

    return null;
  }

  /// Görseli R2'ye yükler; public HTTPS URL döner.
  /// İlan / duyuru / gezi — mevcut `r2-upload` Edge Function.
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

  static Future<String?> _uploadSigV4({
    required Uint8List bytes,
    required String objectKey,
    required String contentType,
  }) async {
    try {
      final endpoint = R2Config.trimmedEndpoint;
      final bucket = R2Config.trimmedBucket;
      final host = Uri.parse(endpoint).host;
      if (host.isEmpty) return null;

      final encodedKey = objectKey
          .split('/')
          .where((s) => s.isNotEmpty)
          .map(Uri.encodeComponent)
          .join('/');
      final canonicalUri = '/$bucket/$encodedKey';
      final putUri = Uri.parse('$endpoint$canonicalUri');

      final now = DateTime.now().toUtc();
      final amz = _amzStamp(now);
      final datestamp = amz.substring(0, 8);
      final payloadHash = sha256.convert(bytes).toString();

      const signedHeaders =
          'content-type;host;x-amz-content-sha256;x-amz-date';
      final canonicalHeaders =
          'content-type:$contentType\n'
          'host:$host\n'
          'x-amz-content-sha256:$payloadHash\n'
          'x-amz-date:$amz\n';

      final canonicalRequest = [
        'PUT',
        canonicalUri,
        '',
        canonicalHeaders,
        signedHeaders,
        payloadHash,
      ].join('\n');

      final credentialScope = '$datestamp/$_region/$_service/aws4_request';
      final stringToSign = [
        'AWS4-HMAC-SHA256',
        amz,
        credentialScope,
        sha256.convert(utf8.encode(canonicalRequest)).toString(),
      ].join('\n');

      final signingKey = _signingKey(
        secret: R2Config.secretAccessKey,
        datestamp: datestamp,
      );
      final signature = Hmac(sha256, signingKey)
          .convert(utf8.encode(stringToSign))
          .toString();

      final authorization =
          'AWS4-HMAC-SHA256 Credential=${R2Config.accessKeyId}/$credentialScope, '
          'SignedHeaders=$signedHeaders, Signature=$signature';

      final res = await http
          .put(
            putUri,
            headers: {
              'Content-Type': contentType,
              'x-amz-content-sha256': payloadHash,
              'x-amz-date': amz,
              'Authorization': authorization,
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('R2 SigV4 PUT ${res.statusCode}: ${res.body}');
        return null;
      }
      return R2Config.publicObjectUrl(objectKey);
    } catch (e, st) {
      debugPrint('R2 SigV4 yükleme başarısız: $e\n$st');
      return null;
    }
  }

  static Future<String?> _uploadViaWorker({
    required Uint8List bytes,
    required String objectKey,
    required String contentType,
  }) async {
    final base = R2Config.trimmedWorkerUrl;
    try {
      final signRes = await http
          .post(
            Uri.parse('$base/sign'),
            headers: const {'Content-Type': 'application/json'},
            body:
                '{"key":"${_jsonEscape(objectKey)}","contentType":"${_jsonEscape(contentType)}"}',
          )
          .timeout(const Duration(seconds: 15));
      if (signRes.statusCode < 200 || signRes.statusCode >= 300) {
        debugPrint('R2 worker /sign ${signRes.statusCode}: ${signRes.body}');
        return null;
      }

      final map = _looseJson(signRes.body);
      final uploadUrl = map['uploadUrl']?.toString() ?? '';
      if (!uploadUrl.startsWith('http')) return null;

      final putRes = await http
          .put(
            Uri.parse(uploadUrl),
            headers: {
              'Content-Type': contentType,
              'Content-Length': '${bytes.lengthInBytes}',
            },
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));
      if (putRes.statusCode < 200 || putRes.statusCode >= 300) {
        debugPrint('R2 worker PUT ${putRes.statusCode}');
        return null;
      }
      final workerKey = map['key']?.toString().trim() ?? '';
      return R2Config.publicObjectUrl(
        workerKey.isNotEmpty ? workerKey : objectKey,
      );
    } catch (e, st) {
      debugPrint('R2 worker yükleme başarısız: $e\n$st');
      return null;
    }
  }

  static List<int> _signingKey({
    required String secret,
    required String datestamp,
  }) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$secret'))
        .convert(utf8.encode(datestamp))
        .bytes;
    final kRegion =
        Hmac(sha256, kDate).convert(utf8.encode(_region)).bytes;
    final kService =
        Hmac(sha256, kRegion).convert(utf8.encode(_service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  static String _amzStamp(DateTime utc) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year.toString().padLeft(4, '0')}'
        '${two(utc.month)}${two(utc.day)}T'
        '${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  static String _sanitizeKey(String raw) {
    var s = raw.trim().replaceAll('\\', '/');
    s = s.replaceAll(RegExp(r'\.\.'), '');
    s = s.replaceAll(RegExp(r'[^a-zA-Z0-9._/-]'), '_');
    if (s.startsWith('/')) s = s.substring(1);
    if (s.isEmpty) {
      s = 'product-labels/unknown/${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    return s;
  }

  static String _jsonEscape(String s) =>
      s.replaceAll('\\', '\\\\').replaceAll('"', '\\"');

  static Map<String, String> _looseJson(String body) {
    final out = <String, String>{};
    for (final key in ['uploadUrl', 'publicUrl', 'url', 'key']) {
      final m = RegExp('"$key"\\s*:\\s*"([^"]*)"').firstMatch(body);
      if (m != null) out[key] = m.group(1)!;
    }
    return out;
  }
}
