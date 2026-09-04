import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Fotoğrafı boyama kitabı tarzı siyah-beyaz çizgi görseline çevirir (PNG).
///
/// `compute()` ile isolate’ta çalıştırılmak için top-level.
Uint8List photoBytesToColoringPng(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw StateError('Boş görsel seçildi.');
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Görsel okunamadı. JPEG veya PNG deneyin.');
  }

  var src = img.bakeOrientation(decoded);
  const maxSide = 960;
  final longSide = src.width > src.height ? src.width : src.height;
  if (longSide > maxSide) {
    src = img.copyResize(
      src,
      width: src.width >= src.height ? maxSide : null,
      height: src.height > src.width ? maxSide : null,
      interpolation: img.Interpolation.cubic,
    );
  }

  final gray = img.grayscale(img.Image.from(src));
  final base = img.Image.from(gray);
  var blurredInv = img.invert(img.Image.from(gray));
  blurredInv = img.gaussianBlur(blurredInv, radius: 4);
  final edges = img.sobel(img.gaussianBlur(img.Image.from(gray), radius: 1));

  final w = base.width;
  final h = base.height;
  final out = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final g = base.getPixel(x, y).r.toInt();
      final b = blurredInv.getPixel(x, y).r.toInt();
      final dodge = b >= 254 ? 255 : ((g * 255) / (255 - b)).round().clamp(0, 255);
      final mag = edges.getPixel(x, y).r.toInt();
      final line = dodge < 178 || mag > 40;
      final v = line ? 0 : 255;
      out.setPixelRgb(x, y, v, v, v);
    }
  }

  _thickenBlack(out);
  return Uint8List.fromList(img.encodePng(out));
}

void _thickenBlack(img.Image src) {
  final w = src.width;
  final h = src.height;
  final mark = List<bool>.filled(w * h, false);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      if (src.getPixel(x, y).r.toInt() > 32) continue;
      mark[y * w + x] = true;
      mark[y * w + x - 1] = true;
      mark[y * w + x + 1] = true;
      mark[(y - 1) * w + x] = true;
      mark[(y + 1) * w + x] = true;
    }
  }
  for (var i = 0; i < mark.length; i++) {
    if (!mark[i]) continue;
    final x = i % w;
    final y = i ~/ w;
    src.setPixelRgb(x, y, 0, 0, 0);
  }
}
