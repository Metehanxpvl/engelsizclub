import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../models/product_safety.dart';

/// Nutri-Score ve NOVA bilgi kartları (tıbbi teşhis değil).
class NutriNovaCards extends StatelessWidget {
  const NutriNovaCards({super.key, required this.safety});

  final SafetyReport safety;

  static const _unknown = Color(0xFF64748B);
  static const _estimateHint = 'tahmini / etiket bilgisine göre';

  static const _nutriColors = <Color>[
    Color(0xFF038141),
    Color(0xFF85BB2F),
    Color(0xFFFECB02),
    Color(0xFFEE8100),
    Color(0xFFE63E11),
  ];

  static const _novaColors = <Color>[
    Color(0xFF16A34A),
    Color(0xFFEAB308),
    Color(0xFFEA580C),
    Color(0xFFDC2626),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ScoreCard(
          kicker: 'NUTRI-SCORE',
          title: 'Besleyicilik Düzeyi',
          subtitle: safety.nutriScore?.subtitleTr ?? 'Bilgi yok',
          subtitleColor: safety.nutriScore == null
              ? _unknown
              : _nutriColors[safety.nutriScore!.index],
          estimate: safety.nutriIsEstimate,
          scale: _NutriScale(grade: safety.nutriScore),
          onTap: () => showInfoSheet(context),
        ),
        const SizedBox(height: 10),
        _ScoreCard(
          kicker: 'NOVA',
          title: 'İşlenmişlik Düzeyi',
          subtitle: safety.novaGroup?.subtitleTr ?? 'Bilgi yok',
          subtitleColor: safety.novaGroup == null
              ? _unknown
              : _novaColors[safety.novaGroup!.index],
          estimate: safety.novaIsEstimate,
          scale: _NovaScale(group: safety.novaGroup),
          onTap: () => showInfoSheet(context),
        ),
      ],
    );
  }

  static Future<void> showInfoSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MetoColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                L10nText(
                  'Nutri-Score ve NOVA',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                L10nText(
                  'Nutri-Score, paketli gıdalarda besin öğelerine göre A’dan E’ye '
                  'bir göstergedir. A en yüksek besleyicilik göstergesidir; E en düşüktür.',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                L10nText(
                  'NOVA, gıdaların işlenme düzeyini 1’den 4’e sınıflandırır. '
                  '1 az işlenmiş veya işlenmemiş; 4 aşırı işlenmiş ürünleri gösterir.',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 10),
                L10nText(
                  'Bunlar bilgilendirme göstergeleridir; teşhis, tıbbi tavsiye '
                  'veya “çocuklar için güvenli” kararı değildir. Etiket ve doktorunuz esas alınır.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.estimate,
    required this.scale,
    required this.onTap,
  });

  final String kicker;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final bool estimate;
  final Widget scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              L10nText(
                kicker,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  scale,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        L10nText(
                          title,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            height: 1.2,
                            color: MetoColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        L10nText(
                          subtitle,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            height: 1.25,
                            color: subtitleColor,
                          ),
                        ),
                        if (estimate) ...[
                          const SizedBox(height: 2),
                          L10nText(
                            NutriNovaCards._estimateHint,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: MetoColors.mutedFg.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NutriScale extends StatelessWidget {
  const _NutriScale({required this.grade});

  final NutriScoreGrade? grade;

  static const _letters = ['A', 'B', 'C', 'D', 'E'];

  @override
  Widget build(BuildContext context) {
    const w = 22.0;
    const h = 28.0;
    const selected = 34.0;
    return SizedBox(
      height: selected,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < 5; i++)
            _NutriCell(
              letter: _letters[i],
              color: NutriNovaCards._nutriColors[i],
              selected: grade != null && grade!.index == i,
              faded: grade == null,
              width: w,
              height: h,
              selectedSize: selected,
            ),
        ],
      ),
    );
  }
}

class _NutriCell extends StatelessWidget {
  const _NutriCell({
    required this.letter,
    required this.color,
    required this.selected,
    required this.faded,
    required this.width,
    required this.height,
    required this.selectedSize,
  });

  final String letter;
  final Color color;
  final bool selected;
  final bool faded;
  final double width;
  final double height;
  final double selectedSize;

  @override
  Widget build(BuildContext context) {
    final fill = faded ? color.withValues(alpha: 0.35) : color;
    if (selected) {
      return Container(
        width: selectedSize,
        height: selectedSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          letter,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Colors.white,
            height: 1,
          ),
        ),
      );
    }
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        letter,
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: Colors.white.withValues(alpha: faded ? 0.85 : 1),
          height: 1,
        ),
      ),
    );
  }
}

class _NovaScale extends StatelessWidget {
  const _NovaScale({required this.group});

  final NovaGroup? group;

  @override
  Widget build(BuildContext context) {
    const size = 26.0;
    return SizedBox(
      height: size + 4,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _NovaCell(
              number: '${i + 1}',
              color: NutriNovaCards._novaColors[i],
              selected: group != null && group!.index == i,
              faded: group == null,
              size: size,
            ),
          ],
        ],
      ),
    );
  }
}

class _NovaCell extends StatelessWidget {
  const _NovaCell({
    required this.number,
    required this.color,
    required this.selected,
    required this.faded,
    required this.size,
  });

  final String number;
  final Color color;
  final bool selected;
  final bool faded;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = faded ? color.withValues(alpha: 0.35) : color;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(6),
        border: selected
            ? Border.all(color: MetoColors.foreground, width: 2.5)
            : null,
      ),
      child: Text(
        number,
        style: GoogleFonts.nunito(
          fontWeight: FontWeight.w900,
          fontSize: selected ? 14 : 12,
          color: Colors.white.withValues(alpha: faded ? 0.85 : 1),
          height: 1,
        ),
      ),
    );
  }
}
