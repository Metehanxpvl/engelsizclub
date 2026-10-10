import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../iyilik_market_store.dart';
import '../meto_theme.dart';
import '../l10n/l10n_text.dart';

/// Kısa konfeti + tebrik; iyilik market puanı artınca.
class IyilikMarketKonfeti extends StatefulWidget {
  const IyilikMarketKonfeti({
    super.key,
    required this.playId,
    this.onFinished,
  });

  final int playId;
  final VoidCallback? onFinished;

  @override
  State<IyilikMarketKonfeti> createState() => _IyilikMarketKonfetiState();
}

class _IyilikMarketKonfetiState extends State<IyilikMarketKonfeti>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 2200);
  late final AnimationController _ctrl;
  late final List<_Piece> _pieces;
  bool _show = true;

  @override
  void initState() {
    super.initState();
    _pieces = _Piece.burst(48);
    _ctrl = AnimationController(vsync: this, duration: _duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _hide();
      })
      ..forward();
  }

  void _hide() {
    if (!mounted || !_show) return;
    setState(() => _show = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onFinished?.call();
    });
  }

  @override
  void didUpdateWidget(covariant IyilikMarketKonfeti oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playId != widget.playId) {
      _pieces
        ..clear()
        ..addAll(_Piece.burst(48));
      _show = true;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_show) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_ctrl.value);
          final fade = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _KonfetiPainter(pieces: _pieces, t: _ctrl.value),
              ),
              Center(
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 0.86 + 0.14 * Curves.elasticOut.transform(
                      math.min(1, _ctrl.value * 1.8),
                    ),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: MetoColors.primary.withValues(alpha: 0.22),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🎉', style: TextStyle(fontSize: 36)),
                          SizedBox(height: 8),
                          L10nText(
                            kIyilikMarketTebrik,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.x,
    required this.drift,
    required this.speed,
    required this.size,
    required this.color,
    required this.spin,
    required this.rect,
  });

  final double x;
  final double drift;
  final double speed;
  final double size;
  final Color color;
  final double spin;
  final bool rect;

  static List<_Piece> burst(int n) {
    final rnd = math.Random();
    const colors = <Color>[
      MetoColors.primary,
      MetoColors.accentGold,
      Color(0xFF0F766E),
      Color(0xFF22C55E),
      Color(0xFFFB7185),
      Color(0xFF38BDF8),
    ];
    return List<_Piece>.generate(n, (_) {
      return _Piece(
        x: rnd.nextDouble(),
        drift: (rnd.nextDouble() - 0.5) * 0.35,
        speed: 0.55 + rnd.nextDouble() * 0.7,
        size: 5 + rnd.nextDouble() * 8,
        color: colors[rnd.nextInt(colors.length)],
        spin: (rnd.nextDouble() - 0.5) * 8,
        rect: rnd.nextBool(),
      );
    });
  }
}

class _KonfetiPainter extends CustomPainter {
  _KonfetiPainter({required this.pieces, required this.t});

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in pieces) {
      final y = -20 + (size.height + 40) * math.min(1, t * p.speed);
      final x = p.x * size.width + p.drift * size.width * t;
      paint.color = p.color.withValues(alpha: (1 - t).clamp(0.0, 1));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      if (p.rect) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
            const Radius.circular(1.5),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, p.size * 0.42, paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _KonfetiPainter old) => old.t != t;
}
