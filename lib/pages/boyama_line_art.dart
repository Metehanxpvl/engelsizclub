import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Fotoğrafı çizgi filme çevirirken Gemini’ye giden stil istemi.
/// Telif: bilinen karakter / logo yok — “Disney çizimi” yalnızca görünüm referansı.
const kBoyamaCartoonPrompt =
    'Redraw this photograph as a friendly children\'s cartoon illustration '
    'in a 2D animated movie style. Original character, not a known franchise. '
    'Keep the same person, pose, clothing, and setting, but stylize them: '
    'big expressive eyes, clean simple shapes, soft rounded features, '
    'smooth flat colors, warm and kind. Not photorealistic, not horror, '
    'not grotesque, not uncanny, not a pencil sketch of a real face. '
    'No logos, no copyrighted characters, no watermarks, no text overlay.';

class BoyamaPhotoPrep {
  const BoyamaPhotoPrep({
    required this.jpeg,
    required this.aspectRatio,
  });

  final Uint8List jpeg;
  final String aspectRatio;
}

/// Galeri fotoğrafını Gemini’ye göndermek için küçült (JPEG).
/// `compute()` ile isolate’ta çalıştırılmak için top-level.
BoyamaPhotoPrep preparePhotoForCartoon(Uint8List bytes) {
  if (bytes.isEmpty) {
    throw StateError('Boş görsel seçildi.');
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Görsel okunamadı. JPEG veya PNG deneyin.');
  }

  var src = img.bakeOrientation(decoded);
  const maxSide = 768;
  final longSide = src.width > src.height ? src.width : src.height;
  if (longSide > maxSide) {
    src = img.copyResize(
      src,
      width: src.width >= src.height ? maxSide : null,
      height: src.height > src.width ? maxSide : null,
      interpolation: img.Interpolation.cubic,
    );
  }
  return BoyamaPhotoPrep(
    jpeg: Uint8List.fromList(img.encodeJpg(src, quality: 78)),
    aspectRatio: _aspectRatioFor(src.width, src.height),
  );
}

String _aspectRatioFor(int w, int h) {
  if (w <= 0 || h <= 0) return '1:1';
  final r = w / h;
  const options = <(double, String)>[
    (1, '1:1'),
    (4 / 3, '4:3'),
    (3 / 4, '3:4'),
    (16 / 9, '16:9'),
    (9 / 16, '9:16'),
    (3 / 2, '3:2'),
    (2 / 3, '2:3'),
    (4 / 5, '4:5'),
    (5 / 4, '5:4'),
  ];
  var best = '1:1';
  var bestDiff = 999.0;
  for (final o in options) {
    final d = (r - o.$1).abs();
    if (d < bestDiff) {
      bestDiff = d;
      best = o.$2;
    }
  }
  return best;
}

img.Image _decodeOriented(Uint8List bytes, {required int maxSide}) {
  if (bytes.isEmpty) {
    throw StateError('Boş görsel seçildi.');
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw StateError('Görsel okunamadı. JPEG veya PNG deneyin.');
  }
  var src = img.bakeOrientation(decoded);
  final longSide = src.width > src.height ? src.width : src.height;
  if (longSide > maxSide) {
    src = img.copyResize(
      src,
      width: src.width >= src.height ? maxSide : null,
      height: src.height > src.width ? maxSide : null,
      interpolation: img.Interpolation.cubic,
    );
  }
  return src;
}

/// Çizgi film illüstrasyonunu boyama kitabı (siyah çizgi, beyaz zemin) PNG’sine çevirir.
Uint8List cartoonBytesToColoringPng(Uint8List bytes) {
  final src = _decodeOriented(bytes, maxSide: 960);
  return _posterizeToColoringPng(
    src,
    blurRadius: 1,
    colors: 18,
    fillVeryDark: true,
  );
}

/// Gemini yok / ülke kısıtı vb. iken yerel yedek.
/// Ham Sobel değil: güçlü bulanıklaştırma + az renk + bölge kenarları
/// (yüzlerde “korku” gölge dolgusu yok).
Uint8List photoBytesToLocalColoringPng(Uint8List bytes) {
  final src = _decodeOriented(bytes, maxSide: 720);
  return _posterizeToColoringPng(
    src,
    blurRadius: 3,
    colors: 8,
    fillVeryDark: false,
  );
}

Uint8List _posterizeToColoringPng(
  img.Image src, {
  required int blurRadius,
  required int colors,
  required bool fillVeryDark,
}) {
  var work = img.gaussianBlur(src, radius: blurRadius);
  if (blurRadius >= 2) {
    work = img.gaussianBlur(work, radius: 1);
  }
  final q = img.quantize(
    work,
    numberOfColors: colors,
    method: img.QuantizeMethod.octree,
    dither: img.DitherKernel.none,
  );

  final w = q.width;
  final h = q.height;
  final out = img.Image(width: w, height: h);
  out.clear(img.ColorRgb8(255, 255, 255));

  int pack(img.Pixel p) =>
      (p.r.toInt() << 16) | (p.g.toInt() << 8) | p.b.toInt();

  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final p = q.getPixel(x, y);
      final c = pack(p);
      var edge = pack(q.getPixel(x + 1, y)) != c ||
          pack(q.getPixel(x, y + 1)) != c;
      if (fillVeryDark) {
        final lum =
            0.299 * p.r.toInt() + 0.587 * p.g.toInt() + 0.114 * p.b.toInt();
        if (lum < 42) edge = true;
      }
      if (edge) {
        out.setPixelRgb(x, y, 0, 0, 0);
      }
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
