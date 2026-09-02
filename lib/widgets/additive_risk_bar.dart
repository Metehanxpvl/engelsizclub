import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../models/product_safety.dart';

/// Katkı risk düzeyi — kırmızı→yeşil bar (tıbbi teşhis değil).
/// Başarılı üründe her zaman gösterilir. İçindekiler yoksa yeşil **Yok**
/// uydurulmaz; gri **Bilinmiyor**. Kart gizlenmez.
class AdditiveRiskCard extends StatelessWidget {
  const AdditiveRiskCard({
    super.key,
    AdditiveRiskLevel? level,
  }) : level = level ?? AdditiveRiskLevel.bilinmiyor;

  final AdditiveRiskLevel level;

  static const _labels = ['Aşırı', 'Çok', 'Az', 'Çok Az', 'Yok'];

  static const _markerColors = [
    Color(0xFFDC2626),
    Color(0xFFEA580C),
    Color(0xFFEAB308),
    Color(0xFF84CC16),
    Color(0xFF16A34A),
  ];

  static const _unknownColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final unknown = level.isUnknown;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          L10nText(
            'Katkı Risk Düzeyi',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          L10nText(
            level.infoSentence,
            style: GoogleFonts.nunito(
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 16),
          if (unknown)
            _UnknownRiskBar()
          else
            AdditiveRiskBar(level: level),
          const SizedBox(height: 10),
          if (unknown)
            Center(
              child: L10nText(
                'Bilinmiyor',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _unknownColor,
                ),
              ),
            )
          else
            Row(
              children: [
                for (var i = 0; i < _labels.length; i++)
                  Expanded(
                    child: L10nText(
                      _labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: i == level.index
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: i == level.index
                            ? MetoColors.foreground
                            : MetoColors.mutedFg,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static Color markerColor(AdditiveRiskLevel level) {
    if (level.isUnknown) return _unknownColor;
    return _markerColors[level.index.clamp(0, _markerColors.length - 1)];
  }
}

class _UnknownRiskBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Center(
        child: Container(
          width: double.infinity,
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFFE2E8F0),
          ),
        ),
      ),
    );
  }
}

class AdditiveRiskBar extends StatelessWidget {
  const AdditiveRiskBar({super.key, required this.level});

  final AdditiveRiskLevel level;

  @override
  Widget build(BuildContext context) {
    if (level.isUnknown) {
      return const SizedBox(
        height: 28,
        child: Center(
          child: ColoredBox(
            color: Color(0xFFE2E8F0),
            child: SizedBox(height: 10, width: double.infinity),
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        const n = 5;
        final t = (level.index + 0.5) / n;
        const marker = 22.0;
        final left = (t * w - marker / 2).clamp(0.0, w - marker);
        return SizedBox(
          height: 28,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 9,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFDC2626),
                        Color(0xFFEA580C),
                        Color(0xFFEAB308),
                        Color(0xFF84CC16),
                        Color(0xFF16A34A),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: 3,
                child: Container(
                  width: marker,
                  height: marker,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AdditiveRiskCard.markerColor(level),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Şeker / tuz miktarı kartı. Sayı yoksa “etikette belirtilmemiş”.
class NutrientAmountCard extends StatefulWidget {
  const NutrientAmountCard({
    super.key,
    required this.title,
    required this.gramsPer100g,
    required this.missingLabel,
    required this.detailTemplate,
    required this.band,
  });

  final String title;
  final double? gramsPer100g;
  final String missingLabel;
  final String detailTemplate;
  final NutrientBand? band;

  @override
  State<NutrientAmountCard> createState() => _NutrientAmountCardState();
}

class _NutrientAmountCardState extends State<NutrientAmountCard> {
  bool _open = false;

  Color get _dot {
    switch (widget.band) {
      case NutrientBand.az:
        return const Color(0xFF16A34A);
      case NutrientBand.orta:
        return const Color(0xFFEA580C);
      case NutrientBand.yuksek:
        return const Color(0xFFEA580C);
      case NutrientBand.cokYuksek:
        return const Color(0xFFDC2626);
      case null:
        return MetoColors.mutedFg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final band = widget.band;
    final grams = widget.gramsPer100g;
    final status = band?.labelTr ?? widget.missingLabel;
    final hasNumber = grams != null;

    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasNumber ? () => setState(() => _open = !_open) : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: L10nText(
                      widget.title,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: MetoColors.foreground,
                      ),
                    ),
                  ),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _dot,
                    ),
                  ),
                  const SizedBox(width: 8),
                  L10nText(
                    status,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: _dot,
                    ),
                  ),
                  if (hasNumber) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      size: 22,
                      color: MetoColors.mutedFg,
                    ),
                  ],
                ],
              ),
              if (_open && hasNumber) ...[
                const SizedBox(height: 8),
                L10nText(
                  widget.detailTemplate.replaceAll(
                    '{g}',
                    grams.toStringAsFixed(grams >= 10 ? 0 : 1),
                  ),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    height: 1.4,
                    color: MetoColors.mutedFg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
