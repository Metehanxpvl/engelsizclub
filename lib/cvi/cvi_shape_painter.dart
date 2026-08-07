import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'cvi_models.dart';

/// Saf vektör yüksek-kontrast şekiller (siyah zemin üzerinde).
class CviShapePainter extends CustomPainter {
  CviShapePainter({
    required this.options,
    required this.layout,
  });

  final List<CviOption> options;
  final List<Offset> layout;

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.min(options.length, layout.length);
    for (var i = 0; i < n; i++) {
      final opt = options[i];
      final center = layout[i];
      final radius = math.min(size.shortestSide * 0.11, 48.0);
      final paint = Paint()
        ..color = opt.color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      switch (opt.shape) {
        case CviShapeKind.circle:
          canvas.drawCircle(center, radius, paint);
          break;
        case CviShapeKind.square:
          final rect = Rect.fromCenter(
            center: center,
            width: radius * 1.8,
            height: radius * 1.8,
          );
          canvas.drawRect(rect, paint);
          break;
        case CviShapeKind.triangle:
          final path = Path()
            ..moveTo(center.dx, center.dy - radius)
            ..lineTo(center.dx + radius * 0.95, center.dy + radius * 0.85)
            ..lineTo(center.dx - radius * 0.95, center.dy + radius * 0.85)
            ..close();
          canvas.drawPath(path, paint);
          break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CviShapePainter oldDelegate) {
    return oldDelegate.options != options || oldDelegate.layout != layout;
  }
}

/// Sabit, tekrarlanabilir yerleşim (oturum içi karıştırma UI katmanında).
List<Offset> cviLayoutForCount(Size size, int count) {
  if (count <= 0) return const [];
  final cx = size.width / 2;
  final cy = size.height / 2;
  if (count == 1) return [Offset(cx, cy)];

  final ring = math.min(size.width, size.height) * 0.28;
  return List.generate(count, (i) {
    final a = (2 * math.pi * i / count) - math.pi / 2;
    return Offset(cx + ring * math.cos(a), cy + ring * math.sin(a));
  });
}

/// Dokunulan noktaya en yakın seçenek indeksi (şekil yarıçapı içinde).
int? cviHitTest({
  required Offset local,
  required Size size,
  required List<Offset> layout,
}) {
  final hitR = math.min(size.shortestSide * 0.14, 56.0);
  var best = -1;
  var bestD = double.infinity;
  for (var i = 0; i < layout.length; i++) {
    final d = (layout[i] - local).distance;
    if (d <= hitR && d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best >= 0 ? best : null;
}
