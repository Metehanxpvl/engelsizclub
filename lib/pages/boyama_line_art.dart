import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Boyama kalıbı tamamen cihazda üretilir — görsel üretim servisi yok.
///
/// Kural: beyaz zemin + ince siyah çizgi. Koyu alanlar (saç, gölge, koyu
/// kıyafet, koyu arka plan) **doldurulmaz**; yalnız sınırı çizilir, içi
/// çocuk boyayabilsin diye beyaz kalır. Gri ton hiç yok.
///
/// Siyah oranı ölçülür: çok siyah = korkutucu maske. Oran üst sınırı aşarsa
/// daha yüksek kenar eşiği + daha büyük en küçük bölge ile yeniden denenir.
const double kBoyamaMinBlackRatio = 0.05;
const double kBoyamaMaxBlackRatio = 0.12;

const int _kMaxSide = 900;

/// Eşik yükseldikçe ve en küçük bölge büyüdükçe çizgi azalır.
/// Sıra: en detaylı → en sade. Siyah oranı sınırın altına düşen ilk adım kazanır.
///
/// [minEdge]: bölge sınırı yalnız gerçek kontrast varsa çizilir. Yumuşak ışık
/// geçişleri (yanak, duvar, zemin) “harita eşyükselti çizgisi” gibi çizilmesin.
class _Step {
  const _Step(this.levels, this.minEdge, this.minAreaFrac);
  final int levels;
  final int minEdge;
  final double minAreaFrac;
}

const _kSteps = <_Step>[
  _Step(7, 14, 0.00010),
  _Step(7, 22, 0.00018),
  _Step(6, 32, 0.00035),
  _Step(6, 46, 0.00080),
  _Step(5, 64, 0.00200),
  _Step(4, 90, 0.00600),
];

/// Galeri fotoğrafı → boyama sayfası PNG (siyah çizgi, beyaz zemin).
/// `compute()` ile isolate’ta çalıştırılmak için top-level.
Uint8List photoBytesToColoringPng(Uint8List bytes) {
  final src = _decodeOriented(bytes, maxSide: _kMaxSide);
  final w = src.width;
  final h = src.height;
  final n = w * h;

  final gray = Uint8List(n);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = src.getPixel(x, y);
      final lum =
          0.299 * p.r.toInt() + 0.587 * p.g.toInt() + 0.114 * p.b.toInt();
      gray[y * w + x] = lum < 0 ? 0 : (lum > 255 ? 255 : lum.round());
    }
  }

  // Güçlü yumuşatma: doku/gürültü çizgiye dönüşmesin.
  final smooth = _boxBlur(gray, w, h, 2, 2);
  _stretchContrast(smooth);

  final grad = _gradient(smooth, w, h);

  final speck = math.max(10, (math.min(w, h) * 0.025).round());
  Uint8List mask = Uint8List(n)..fillRange(0, n, 255);
  var ratio = 1.0;
  for (final step in _kSteps) {
    final q = _quantize(smooth, step.levels);
    _mergeSmallRegions(q, w, h, math.max(32, (n * step.minAreaFrac).round()));
    final edges = _edgeMask(q, grad, step.minEdge, w, h);
    _pruneSpecks(edges, w, h, speck);
    mask = edges;
    ratio = _blackRatio(edges);
    if (ratio <= kBoyamaMaxBlackRatio) break;
  }

  // Çizgi 1 px; yalnız fazla soluk kaldıysa ve üst sınırı aşmıyorsa kalınlaşır.
  if (ratio < kBoyamaMinBlackRatio) {
    final thick = _dilate(mask, w, h);
    if (_blackRatio(thick) <= kBoyamaMaxBlackRatio) mask = thick;
  }

  final out = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final v = mask[y * w + x];
      out.setPixelRgb(x, y, v, v, v);
    }
  }
  return Uint8List.fromList(img.encodePng(out));
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

/// Ayrılabilir kutu bulanıklığı (kayan toplam). Web sürümüyle birebir aynı.
Uint8List _boxBlur(Uint8List src, int w, int h, int radius, int passes) {
  final cur = Uint8List.fromList(src);
  final tmp = Uint8List(w * h);
  final n = radius * 2 + 1;
  for (var pass = 0; pass < passes; pass++) {
    for (var y = 0; y < h; y++) {
      final row = y * w;
      var sum = 0;
      for (var i = -radius; i <= radius; i++) {
        sum += cur[row + _clampInt(i, 0, w - 1)];
      }
      for (var x = 0; x < w; x++) {
        tmp[row + x] = sum ~/ n;
        sum += cur[row + _clampInt(x + radius + 1, 0, w - 1)] -
            cur[row + _clampInt(x - radius, 0, w - 1)];
      }
    }
    for (var x = 0; x < w; x++) {
      var sum = 0;
      for (var i = -radius; i <= radius; i++) {
        sum += tmp[_clampInt(i, 0, h - 1) * w + x];
      }
      for (var y = 0; y < h; y++) {
        cur[y * w + x] = sum ~/ n;
        sum += tmp[_clampInt(y + radius + 1, 0, h - 1) * w + x] -
            tmp[_clampInt(y - radius, 0, h - 1) * w + x];
      }
    }
  }
  return cur;
}

int _clampInt(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);

/// %2–%98 aralığını 0–255’e yayar: az kontrastlı karede çizgi kaybolmasın.
void _stretchContrast(Uint8List gray) {
  final hist = Int32List(256);
  for (var i = 0; i < gray.length; i++) {
    hist[gray[i]]++;
  }
  final cut = (gray.length * 0.02).round();
  var acc = 0;
  var lo = 0;
  for (var i = 0; i < 256; i++) {
    acc += hist[i];
    if (acc >= cut) {
      lo = i;
      break;
    }
  }
  acc = 0;
  var hi = 255;
  for (var i = 255; i >= 0; i--) {
    acc += hist[i];
    if (acc >= cut) {
      hi = i;
      break;
    }
  }
  if (hi - lo < 16) return;
  final scale = 255.0 / (hi - lo);
  for (var i = 0; i < gray.length; i++) {
    final v = ((gray[i] - lo) * scale).round();
    gray[i] = v < 0 ? 0 : (v > 255 ? 255 : v);
  }
}

Uint8List _quantize(Uint8List gray, int levels) {
  final out = Uint8List(gray.length);
  for (var i = 0; i < gray.length; i++) {
    var v = (gray[i] * levels) ~/ 256;
    if (v >= levels) v = levels - 1;
    out[i] = v;
  }
  return out;
}

/// Küçük lekeleri en büyük komşusuna kat: fotoğraf karalamaya dönmesin,
/// bölgeler boyanabilecek kadar geniş ve kapalı kalsın.
void _mergeSmallRegions(Uint8List q, int w, int h, int minArea) {
  for (var pass = 0; pass < 2; pass++) {
    if (!_mergePass(q, w, h, minArea)) break;
  }
}

bool _mergePass(Uint8List q, int w, int h, int minArea) {
  final n = w * h;
  final labels = Int32List(n)..fillRange(0, n, -1);
  final stack = Int32List(n);
  final areas = <int>[];
  final values = <int>[];
  var next = 0;

  for (var start = 0; start < n; start++) {
    if (labels[start] != -1) continue;
    final value = q[start];
    final label = next++;
    var sp = 0;
    stack[sp++] = start;
    labels[start] = label;
    var count = 0;
    while (sp > 0) {
      final idx = stack[--sp];
      count++;
      final x = idx % w;
      if (x > 0 && labels[idx - 1] == -1 && q[idx - 1] == value) {
        labels[idx - 1] = label;
        stack[sp++] = idx - 1;
      }
      if (x < w - 1 && labels[idx + 1] == -1 && q[idx + 1] == value) {
        labels[idx + 1] = label;
        stack[sp++] = idx + 1;
      }
      if (idx >= w && labels[idx - w] == -1 && q[idx - w] == value) {
        labels[idx - w] = label;
        stack[sp++] = idx - w;
      }
      if (idx < n - w && labels[idx + w] == -1 && q[idx + w] == value) {
        labels[idx + w] = label;
        stack[sp++] = idx + w;
      }
    }
    areas.add(count);
    values.add(value);
  }

  final bestLabel = Int32List(next)..fillRange(0, next, -1);
  final bestArea = Int32List(next);
  for (var idx = 0; idx < n; idx++) {
    final l = labels[idx];
    if (areas[l] >= minArea) continue;
    final x = idx % w;
    if (x > 0) {
      final m = labels[idx - 1];
      if (m != l && areas[m] > bestArea[l]) {
        bestArea[l] = areas[m];
        bestLabel[l] = m;
      }
    }
    if (x < w - 1) {
      final m = labels[idx + 1];
      if (m != l && areas[m] > bestArea[l]) {
        bestArea[l] = areas[m];
        bestLabel[l] = m;
      }
    }
    if (idx >= w) {
      final m = labels[idx - w];
      if (m != l && areas[m] > bestArea[l]) {
        bestArea[l] = areas[m];
        bestLabel[l] = m;
      }
    }
    if (idx < n - w) {
      final m = labels[idx + w];
      if (m != l && areas[m] > bestArea[l]) {
        bestArea[l] = areas[m];
        bestLabel[l] = m;
      }
    }
  }

  var changed = false;
  for (var idx = 0; idx < n; idx++) {
    final l = labels[idx];
    if (areas[l] >= minArea) continue;
    final m = bestLabel[l];
    if (m < 0) continue;
    q[idx] = values[m];
    changed = true;
  }
  return changed;
}

/// Merkezi fark ile eğim şiddeti (|dx| + |dy|).
Uint8List _gradient(Uint8List gray, int w, int h) {
  final out = Uint8List(w * h);
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final dx = (gray[i + 1] - gray[i - 1]).abs();
      final dy = (gray[i + w] - gray[i - w]).abs();
      final g = dx + dy;
      out[i] = g > 255 ? 255 : g;
    }
  }
  return out;
}

/// Yalnız bölge sınırı siyah olur; bölgenin içi hiç boyanmaz.
/// Sınır ancak gerçek kontrast varsa çizilir — yumuşak ton geçişi çizgi değil.
Uint8List _edgeMask(Uint8List q, Uint8List grad, int minEdge, int w, int h) {
  final n = w * h;
  final out = Uint8List(n)..fillRange(0, n, 255);
  for (var y = 0; y < h - 1; y++) {
    for (var x = 0; x < w - 1; x++) {
      final i = y * w + x;
      final c = q[i];
      if (q[i + 1] == c && q[i + w] == c) continue;
      if (grad[i] < minEdge) continue;
      out[i] = 0;
    }
  }
  return out;
}

/// Kopuk kısa çizgi parçalarını sil (toz/gürültü). Göz, ağız gibi küçük ama
/// anlamlı ayrıntılar kalsın diye eşik düşük tutulur.
void _pruneSpecks(Uint8List mask, int w, int h, int minSize) {
  final n = w * h;
  final seen = Uint8List(n);
  final stack = Int32List(n);
  final comp = Int32List(n);
  for (var start = 0; start < n; start++) {
    if (mask[start] != 0 || seen[start] != 0) continue;
    var sp = 0;
    var cp = 0;
    stack[sp++] = start;
    seen[start] = 1;
    while (sp > 0) {
      final idx = stack[--sp];
      comp[cp++] = idx;
      final x = idx % w;
      final y = idx ~/ w;
      for (var dy = -1; dy <= 1; dy++) {
        final ny = y + dy;
        if (ny < 0 || ny >= h) continue;
        for (var dx = -1; dx <= 1; dx++) {
          final nx = x + dx;
          if (nx < 0 || nx >= w) continue;
          final k = ny * w + nx;
          if (seen[k] != 0 || mask[k] != 0) continue;
          seen[k] = 1;
          stack[sp++] = k;
        }
      }
    }
    if (cp < minSize) {
      for (var i = 0; i < cp; i++) {
        mask[comp[i]] = 255;
      }
    }
  }
}

Uint8List _dilate(Uint8List mask, int w, int h) {
  final out = Uint8List.fromList(mask);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (mask[i] != 0) continue;
      if (x > 0) out[i - 1] = 0;
      if (x < w - 1) out[i + 1] = 0;
      if (y > 0) out[i - w] = 0;
      if (y < h - 1) out[i + w] = 0;
    }
  }
  return out;
}

double _blackRatio(Uint8List mask) {
  var black = 0;
  for (var i = 0; i < mask.length; i++) {
    if (mask[i] == 0) black++;
  }
  return mask.isEmpty ? 0 : black / mask.length;
}
