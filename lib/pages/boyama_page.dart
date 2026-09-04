import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../meto_theme.dart';
import '../services/gemini_service.dart';
import '../widgets/guest_timed_guard.dart';
import 'boyama_line_art.dart';

class _PaletteColor {
  const _PaletteColor(this.color, this.label);
  final Color color;
  final String label;
}

const _kPalette = <_PaletteColor>[
  _PaletteColor(Color(0xFFE31B23), 'Kırmızı'),
  _PaletteColor(Color(0xFFFFD400), 'Sarı'),
  _PaletteColor(Color(0xFF1565C0), 'Mavi'),
  _PaletteColor(Color(0xFFFF7A18), 'Turuncu'),
  _PaletteColor(Color(0xFF2E9B3A), 'Yeşil'),
  _PaletteColor(Color(0xFF8E24AA), 'Mor'),
  _PaletteColor(Color(0xFFF06292), 'Pembe'),
  _PaletteColor(Color(0xFF8D5B3D), 'Kahverengi'),
  _PaletteColor(Color(0xFFE8B89A), 'Ten'),
  _PaletteColor(Color(0xFF9E9E9E), 'Gri'),
  _PaletteColor(Color(0xFF111111), 'Siyah'),
  _PaletteColor(Color(0xFFFFFFFF), 'Silgi'),
];

const _kSizes = <(String, double)>[
  ('S', 8),
  ('M', 18),
  ('L', 32),
];

class _Stroke {
  _Stroke({required this.color, required this.width});
  final Color color;
  final double width;
  final Path path = Path();
  final List<Offset> points = <Offset>[];

  void add(Offset p) {
    if (points.isEmpty) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
    points.add(p);
  }
}

/// Uygulama içi Engelsiz Boyama — Daha Fazlası üst düzey öğesinden açılır.
class BoyamaPage extends StatefulWidget {
  const BoyamaPage({
    super.key,
    this.title = 'engelsiz Boyama',
  });

  final String title;

  static Future<void> open(
    BuildContext context, {
    String title = 'engelsiz Boyama',
    bool isGuest = false,
    VoidCallback? onRequireLogin,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GuestTimedGuard(
          isGuest: isGuest,
          tab: 'daha_fazlasi',
          onRequireLogin: onRequireLogin,
          child: BoyamaPage(title: title),
        ),
      ),
    );
  }

  @override
  State<BoyamaPage> createState() => _BoyamaPageState();
}

class _BoyamaPageState extends State<BoyamaPage> {
  final _picker = ImagePicker();
  final _strokes = <_Stroke>[];
  _Stroke? _current;
  Color _color = _kPalette.first.color;
  double _width = _kSizes.first.$2;
  ui.Image? _lineArt;
  var _busy = false;
  var _busyLabel = 'Çizgi filme çevriliyor…';
  Uint8List? _retryBytes;

  @override
  void dispose() {
    _lineArt?.dispose();
    super.dispose();
  }

  void _start(Offset p) {
    if (_busy) return;
    final stroke = _Stroke(color: _color, width: _width)..add(p);
    setState(() => _current = stroke);
  }

  void _move(Offset p) {
    final stroke = _current;
    if (stroke == null) return;
    stroke.add(p);
    setState(() {});
  }

  void _end() {
    final stroke = _current;
    if (stroke == null) return;
    setState(() {
      _strokes.add(stroke);
      _current = null;
    });
  }

  void _clearStrokes() {
    setState(() {
      _strokes.clear();
      _current = null;
    });
  }

  Future<void> _pickAndConvert() async {
    if (_busy) return;
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Boş görsel seçildi.');
      }
      await _convertBytes(bytes);
    } catch (e, st) {
      debugPrint('Boyama pick failed: $e\n$st');
      if (!mounted) return;
      _showSnack(
        'Resim eklenemedi. Galeri iznini kontrol et veya JPEG/PNG dene.',
      );
    }
  }

  Future<void> _convertBytes(Uint8List bytes) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyLabel = 'Çizgi filme çevriliyor…';
      _retryBytes = bytes;
    });
    String? fallbackNote;
    try {
      Uint8List? cartoonPng;
      try {
        final prep = preparePhotoForCartoon(bytes);
        final cartoon = await GeminiService.generateImageFromPhoto(
          prompt: kBoyamaCartoonPrompt,
          imageBytes: prep.jpeg,
          mimeType: 'image/jpeg',
          aspectRatio: prep.aspectRatio,
        );
        final cartoonBytes = cartoon.$1;
        if (cartoonBytes != null && cartoonBytes.isNotEmpty) {
          if (!mounted) return;
          setState(() => _busyLabel = 'Boyama sayfası hazırlanıyor…');
          cartoonPng = await compute(cartoonBytesToColoringPng, cartoonBytes);
        } else {
          debugPrint('Boyama cartoon failed: ${cartoon.$2}');
          fallbackNote =
              'Çizgi film servisi kullanılamadı; basit kalıp hazırlandı.';
        }
      } catch (e, st) {
        debugPrint('Boyama cartoon path failed: $e\n$st');
        fallbackNote =
            'Çizgi film servisi kullanılamadı; basit kalıp hazırlandı.';
      }

      final Uint8List png;
      if (cartoonPng != null) {
        png = cartoonPng;
      } else {
        if (!mounted) return;
        setState(() => _busyLabel = 'Basit boyama kalıbı hazırlanıyor…');
        png = await compute(photoBytesToLocalColoringPng, bytes);
        fallbackNote ??=
            'Çizim oluşturulamadı, basit kalıp kullanıldı.';
      }

      final codec = await ui.instantiateImageCodec(png);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _lineArt?.dispose();
        _lineArt = frame.image;
        _strokes.clear();
        _current = null;
        _busy = false;
      });
      if (fallbackNote != null) _showSnack(fallbackNote);
    } catch (e, st) {
      debugPrint('Boyama convert failed: $e\n$st');
      if (!mounted) return;
      setState(() => _busy = false);
      _showSnack(
        'Resim eklenemedi. JPEG veya PNG dene.',
        retry: true,
      );
    }
  }

  void _showSnack(String message, {bool retry = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: !retry || _retryBytes == null
            ? null
            : SnackBarAction(
                label: 'Tekrar dene',
                onPressed: () {
                  final again = _retryBytes;
                  if (again == null) return;
                  _convertBytes(again);
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          TextButton.icon(
            onPressed: _busy ? null : _pickAndConvert,
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text(
              'Fotoğraf',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _clearStrokes,
            child: const Text(
              'Temizle',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: MetoColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Galeriden fotoğraf seç; boyama kalıbı hazırlanır. Sonra boya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: MetoColors.mutedFg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final swatch in _kPalette)
                  _SwatchButton(
                    color: swatch.color,
                    label: swatch.label,
                    selected: _color == swatch.color,
                    onTap: () => setState(() => _color = swatch.color),
                  ),
                for (final size in _kSizes)
                  _SizeButton(
                    label: size.$1,
                    selected: _width == size.$2,
                    onTap: () => setState(() => _width = size.$2),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (e) => _start(e.localPosition),
                        onPointerMove: (e) => _move(e.localPosition),
                        onPointerUp: (_) => _end(),
                        onPointerCancel: (_) => _end(),
                        child: CustomPaint(
                          painter: _BoyamaPainter(
                            strokes: _strokes,
                            current: _current,
                            lineArt: _lineArt,
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                      if (_busy)
                        ColoredBox(
                          color: const Color(0x88FFFFFF),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: MetoColors.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _busyLabel,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwatchButton extends StatelessWidget {
  const _SwatchButton({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isWhite = color.computeLuminance() > 0.9;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? MetoColors.foreground
                  : (isWhite ? const Color(0xFFCCCCCC) : Colors.transparent),
              width: selected ? 2.5 : 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Fırça $label',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? MetoColors.primary : MetoColors.border,
              width: 2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? MetoColors.primary : MetoColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoyamaPainter extends CustomPainter {
  _BoyamaPainter({
    required this.strokes,
    required this.current,
    required this.lineArt,
  });

  final List<_Stroke> strokes;
  final _Stroke? current;
  final ui.Image? lineArt;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }
    final live = current;
    if (live != null) _drawStroke(canvas, live);

    final art = lineArt;
    if (art != null && art.width > 0 && art.height > 0) {
      final src = Rect.fromLTWH(0, 0, art.width.toDouble(), art.height.toDouble());
      final fitted = applyBoxFit(BoxFit.contain, src.size, size);
      final dest = Alignment.center.inscribe(fitted.destination, Offset.zero & size);
      canvas.drawImageRect(
        art,
        src,
        dest,
        Paint()..blendMode = BlendMode.multiply,
      );
    }
  }

  void _drawStroke(Canvas canvas, _Stroke stroke) {
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (stroke.points.length == 1) {
      canvas.drawCircle(
        stroke.points.first,
        stroke.width / 2,
        paint..style = PaintingStyle.fill,
      );
      return;
    }
    canvas.drawPath(stroke.path, paint);
  }

  @override
  bool shouldRepaint(covariant _BoyamaPainter oldDelegate) => true;
}
