import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Kullanıcı fotoğraflarını görsel kaliteyi bozmadan küçültür (JPEG).
class OptimizedImage {
  const OptimizedImage({
    required this.bytes,
    required this.contentType,
    required this.fileName,
  });

  final Uint8List bytes;
  final String contentType;
  final String fileName;
}

class ImageOptimizeService {
  ImageOptimizeService._();

  /// İlan / R2 — telefonda keskin görünür, ~450 KB hedef.
  static Future<OptimizedImage> forListing(Uint8List raw) {
    return Future(
      () => _optimize(
        raw,
        maxSide: 1280,
        maxBytes: 450 * 1024,
        startQuality: 76,
        minQuality: 58,
        filePrefix: 'ilan',
      ),
    );
  }

  /// Forum — R2’ye gitmeden önce sıkıştır (~280 KB).
  static Future<OptimizedImage> forForum(Uint8List raw) {
    return Future(
      () => _optimize(
        raw,
        maxSide: 1080,
        maxBytes: 280 * 1024,
        startQuality: 72,
        minQuality: 55,
        filePrefix: 'forum',
      ),
    );
  }

  /// Profil avatarı — küçük ve hafif (~80 KB).
  static Future<OptimizedImage> forAvatar(Uint8List raw) {
    return Future(
      () => _optimize(
        raw,
        maxSide: 320,
        maxBytes: 80 * 1024,
        startQuality: 70,
        minQuality: 50,
        filePrefix: 'avatar',
      ),
    );
  }

  /// İlan / katalog kartı değil — etiket OCR için daha yüksek çözünürlük.
  static Future<OptimizedImage> forLabelScan(Uint8List raw) {
    return Future(
      () => _optimize(
        raw,
        maxSide: 1600,
        maxBytes: 900 * 1024,
        startQuality: 82,
        minQuality: 68,
        filePrefix: 'label',
      ),
    );
  }

  /// Bilgi kütüphanesi / duyuru kart görselleri.
  static Future<OptimizedImage> forCatalogCard(Uint8List raw) {
    return Future(
      () => _optimize(
        raw,
        maxSide: 960,
        maxBytes: 220 * 1024,
        startQuality: 74,
        minQuality: 55,
        filePrefix: 'card',
      ),
    );
  }

  static OptimizedImage _optimize(
    Uint8List raw, {
    required int maxSide,
    required int maxBytes,
    required int startQuality,
    required int minQuality,
    required String filePrefix,
  }) {
    if (raw.isEmpty) {
      throw StateError('Boş görsel seçildi.');
    }

    final decoded = img.decodeImage(raw);
    if (decoded == null) {
      throw StateError('Görsel okunamadı. Başka bir fotoğraf deneyin.');
    }

    // EXIF yönünü düzelt (telefon fotoğrafları).
    var image = img.bakeOrientation(decoded);

    final longSide =
        image.width > image.height ? image.width : image.height;
    if (longSide > maxSide) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? maxSide : null,
        height: image.height > image.width ? maxSide : null,
        interpolation: img.Interpolation.linear,
      );
    }

    var quality = startQuality;
    var out = Uint8List.fromList(img.encodeJpg(image, quality: quality));

    while (out.lengthInBytes > maxBytes && quality > minQuality) {
      quality -= 6;
      out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    // Hâlâ çok büyükse bir kademe daha küçült.
    if (out.lengthInBytes > maxBytes && maxSide > 720) {
      final softer = (maxSide * 0.82).round();
      image = img.copyResize(
        image,
        width: image.width >= image.height ? softer : null,
        height: image.height > image.width ? softer : null,
        interpolation: img.Interpolation.average,
      );
      quality = (quality - 4).clamp(minQuality, startQuality);
      out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      while (out.lengthInBytes > maxBytes && quality > minQuality) {
        quality -= 5;
        out = Uint8List.fromList(img.encodeJpg(image, quality: quality));
      }
    }

    if (out.isEmpty) {
      throw StateError('Görsel sıkıştırılamadı.');
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    return OptimizedImage(
      bytes: out,
      contentType: 'image/jpeg',
      fileName: '${filePrefix}_$stamp.jpg',
    );
  }
}
