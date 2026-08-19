import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../meto_theme.dart';

/// 0–2 yaş rehberindeki yeşil video çerçevesi.
class InfoVideoFrame extends StatelessWidget {
  const InfoVideoFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.primary, width: 2),
      ),
      child: child,
    );
  }
}

/// Rehberdeki “Videoyu izle” hapı.
class InfoVideoyuIzleBadge extends StatelessWidget {
  const InfoVideoyuIzleBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MetoColors.primary.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 4),
            Text(
              'Videoyu izle',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoKaynakLine extends StatelessWidget {
  const InfoKaynakLine(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final t = source.trim();
    if (t.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Kaynak: ',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
            ),
            TextSpan(
              text: t,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MetoColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: MetoColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
