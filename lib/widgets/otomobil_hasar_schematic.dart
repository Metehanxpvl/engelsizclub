import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/otomobil_catalog.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';

const kOtomobilHasarAsset = 'assets/images/otomobil_hasar.png';
const kOtomobilHasarAspect = 634 / 625;

const _kOrijinal = Color(0xFFC4C4C4);
const _kLokal = Color(0xFFF5A524);
const _kBoya = Color(0xFF1D4ED8);
const _kDegisen = Color(0xFFEF5A2C);
const _kZemin = Color(0xFFFFF8E8);

Color otomobilHasarRenk(String? status) {
  return switch (status) {
    kOtomobilHasarLokal => _kLokal,
    kOtomobilHasarBoya => _kBoya,
    kOtomobilHasarDegisen => _kDegisen,
    _ => _kOrijinal,
  };
}

/// Sahibinden görseli üzerinde boyalı / değişen parça işaretleme.
class OtomobilHasarSchematic extends StatelessWidget {
  const OtomobilHasarSchematic({
    super.key,
    required this.hasar,
    this.onChanged,
  });

  final Map<String, String> hasar;
  final ValueChanged<Map<String, String>>? onChanged;

  bool get _editable => onChanged != null;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    for (final p in kOtomobilParcalar) {
      final st = hasar[p.id];
      if (st == null) continue;
      final etiket = kOtomobilHasarEtiket[st];
      if (etiket == null) continue;
      rows.add((p.label, etiket));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const L10nText(
          'Boyalı veya Değişen Parça',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2563EB),
          ),
        ),
        if (_editable) ...[
          const SizedBox(height: 4),
          const L10nText(
            'Parçaya dokunun: Orijinal → Lokal boyalı → Boyalı → Değişen',
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
        ],
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          decoration: BoxDecoration(
            color: _kZemin,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE8D9A8)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _LegendDot(color: _kOrijinal, label: 'Orijinal'),
                  _LegendDot(color: _kLokal, label: 'Lokal Boyalı'),
                  _LegendDot(color: _kBoya, label: 'Boyalı'),
                  _LegendDot(color: _kDegisen, label: 'Değişen'),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 520;
                  final diagram = AspectRatio(
                    aspectRatio: kOtomobilHasarAspect,
                    child: _CarHitBox(hasar: hasar, onChanged: onChanged),
                  );
                  final list = rows.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: EdgeInsets.only(
                            left: wide ? 12 : 4,
                            top: wide ? 0 : 12,
                          ),
                          child: _HasarList(rows: rows),
                        );
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: diagram),
                        Expanded(flex: 2, child: list),
                      ],
                    );
                  }
                  return Column(children: [diagram, list]);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color == _kOrijinal ? const Color(0xFF6B7280) : color,
          ),
        ),
      ],
    );
  }
}

class _HasarList extends StatelessWidget {
  const _HasarList({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<String>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.$2, () => []).add(row.$1);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in grouped.entries) ...[
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                color: e.key == 'Lokal Boyalı'
                    ? _kLokal
                    : e.key == 'Boyalı'
                        ? _kBoya
                        : _kDegisen,
              ),
              const SizedBox(width: 6),
              Text(
                '${e.key} Parçalar',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final name in e.value)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 2),
              child: Text(
                '· $name',
                style: const TextStyle(fontSize: 12, height: 1.35),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CarHitBox extends StatefulWidget {
  const _CarHitBox({required this.hasar, this.onChanged});
  final Map<String, String> hasar;
  final ValueChanged<Map<String, String>>? onChanged;

  @override
  State<_CarHitBox> createState() => _CarHitBoxState();
}

class _CarHitBoxState extends State<_CarHitBox> {
  ui.Image? _car;

  @override
  void initState() {
    super.initState();
    _loadCar();
  }

  @override
  void dispose() {
    _car?.dispose();
    super.dispose();
  }

  Future<void> _loadCar() async {
    final data = await rootBundle.load(kOtomobilHasarAsset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (!mounted) return;
    setState(() => _car = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onChanged == null
              ? null
              : (d) {
                  final id = hitOtomobilParca(d.localPosition, size);
                  if (id == null) return;
                  widget.onChanged!(otomobilHasarToggle(widget.hasar, id));
                },
          child: Stack(
            fit: StackFit.expand,
            children: [
              const Image(
                image: AssetImage(kOtomobilHasarAsset),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                gaplessPlayback: true,
              ),
              CustomPaint(
                size: size,
                painter: _OverlayPainter(hasar: widget.hasar, car: _car),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Yatay dilimlerden panel silueti (krem boşluğa taşmaz).
Path _band(Size s, List<(double y, double l, double r)> rows) {
  final path = Path()
    ..moveTo(rows.first.$3 * s.width, rows.first.$1 * s.height);
  for (final row in rows) {
    path.lineTo(row.$3 * s.width, row.$1 * s.height);
  }
  for (var i = rows.length - 1; i >= 0; i--) {
    path.lineTo(rows[i].$2 * s.width, rows[i].$1 * s.height);
  }
  path.close();
  return path;
}

List<(double, double, double)> _mirror(
  List<(double y, double l, double r)> rows,
) {
  // Görsel 0.475 civarında ortalı: sağ = 0.951 − sol.
  return [for (final r in rows) (r.$1, 0.951 - r.$3, 0.951 - r.$2)];
}

Path _bumper(Size s, {required bool front}) {
  final p = _band(
    s,
    front
        ? const [
            (0.048, 0.350, 0.606),
            (0.114, 0.350, 0.606),
          ]
        : const [
            (0.859, 0.350, 0.606),
            (0.922, 0.350, 0.606),
          ],
  );
  if (front) {
    p.addRect(
      Rect.fromLTRB(
        0.374 * s.width,
        0.024 * s.height,
        0.426 * s.width,
        0.050 * s.height,
      ),
    );
    p.addRect(
      Rect.fromLTRB(
        0.532 * s.width,
        0.024 * s.height,
        0.585 * s.width,
        0.050 * s.height,
      ),
    );
  } else {
    p.addRect(
      Rect.fromLTRB(
        0.374 * s.width,
        0.926 * s.height,
        0.426 * s.width,
        0.950 * s.height,
      ),
    );
    p.addRect(
      Rect.fromLTRB(
        0.532 * s.width,
        0.926 * s.height,
        0.585 * s.width,
        0.950 * s.height,
      ),
    );
  }
  return p;
}

/// Görseldeki paneller (ön üstte). Koordinatlar 634×625 PNG piksel ölçümü.
Map<String, Path> otomobilParcaPaths(Size s) {
  const solOnCamurluk = <(double, double, double)>[
    (0.132, 0.161, 0.199),
    (0.150, 0.148, 0.235),
    (0.176, 0.148, 0.244),
    (0.214, 0.147, 0.252),
    (0.253, 0.109, 0.263),
    (0.291, 0.117, 0.275),
    (0.326, 0.148, 0.305),
  ];
  const solOnKapi = <(double, double, double)>[
    (0.328, 0.148, 0.318),
    (0.368, 0.148, 0.330),
    (0.406, 0.148, 0.330),
    (0.445, 0.148, 0.330),
    (0.496, 0.148, 0.330),
    (0.526, 0.148, 0.330),
  ];
  const solArkaKapi = <(double, double, double)>[
    (0.528, 0.148, 0.330),
    (0.560, 0.148, 0.330),
    (0.598, 0.148, 0.330),
    (0.637, 0.148, 0.330),
    (0.662, 0.123, 0.328),
  ];
  const solArkaCamurluk = <(double, double, double)>[
    (0.664, 0.123, 0.325),
    (0.698, 0.109, 0.318),
    (0.726, 0.117, 0.310),
    (0.765, 0.148, 0.297),
    (0.803, 0.148, 0.281),
    (0.838, 0.162, 0.210),
  ];

  return {
    'on_tampon': _bumper(s, front: true),
    'kaput': _band(s, const [
      (0.130, 0.379, 0.574),
      (0.154, 0.355, 0.599),
      (0.192, 0.345, 0.609),
      (0.256, 0.342, 0.612),
      (0.314, 0.339, 0.614),
    ]),
    'sol_on_camurluk': _band(s, solOnCamurluk),
    'sag_on_camurluk': _band(s, _mirror(solOnCamurluk)),
    'sol_on_kapi': _band(s, solOnKapi),
    'sag_on_kapi': _band(s, _mirror(solOnKapi)),
    'tavan': _band(s, const [
      (0.514, 0.338, 0.615),
      (0.652, 0.338, 0.615),
    ]),
    'sol_arka_kapi': _band(s, solArkaKapi),
    'sag_arka_kapi': _band(s, _mirror(solArkaKapi)),
    'sol_arka_camurluk': _band(s, solArkaCamurluk),
    'sag_arka_camurluk': _band(s, _mirror(solArkaCamurluk)),
    'bagaj': _band(s, const [
      (0.775, 0.349, 0.604),
      (0.806, 0.342, 0.610),
      (0.832, 0.385, 0.568),
      (0.840, 0.426, 0.527),
    ]),
    'arka_tampon': _bumper(s, front: false),
  };
}

String? hitOtomobilParca(Offset p, Size s) {
  final paths = otomobilParcaPaths(s);
  for (final part in kOtomobilParcalar.reversed) {
    final path = paths[part.id];
    if (path != null && path.contains(p)) return part.id;
  }
  return null;
}

class _OverlayPainter extends CustomPainter {
  _OverlayPainter({required this.hasar, required this.car});
  final Map<String, String> hasar;
  final ui.Image? car;

  @override
  void paint(Canvas canvas, Size size) {
    final paths = otomobilParcaPaths(size);
    final dst = Offset.zero & size;
    canvas.saveLayer(dst, Paint());
    final fill = Paint()..style = PaintingStyle.fill;
    for (final part in kOtomobilParcalar) {
      final st = hasar[part.id];
      if (st == null) continue;
      final path = paths[part.id];
      if (path == null) continue;
      fill.color = otomobilHasarRenk(st).withValues(alpha: 0.90);
      canvas.drawPath(path, fill);
    }
    final img = car;
    if (img != null) {
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        Paint()..blendMode = BlendMode.dstIn,
      );
    }
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (final part in kOtomobilParcalar) {
      final st = hasar[part.id];
      if (st == null) continue;
      final path = paths[part.id];
      if (path == null) continue;
      final short = kOtomobilHasarKisa[st];
      if (short == null) continue;
      final b = path.getBounds();
      tp.text = TextSpan(
        text: short,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(b.center.dx - tp.width / 2, b.center.dy - tp.height / 2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OverlayPainter oldDelegate) =>
      oldDelegate.hasar != hasar || oldDelegate.car != car;
}
