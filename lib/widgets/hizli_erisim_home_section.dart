import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_text.dart';
import '../meto_theme.dart';

/// Ana: arama ile duyurular arası — Tarama / Destek / Hak / Engelsiz Haritalar.
class HizliErisimHomeSection extends StatelessWidget {
  const HizliErisimHomeSection({
    super.key,
    this.onOpenTarama,
    this.onOpenDestek,
    this.onOpenHaklar,
    this.onOpenHarita,
  });

  final VoidCallback? onOpenTarama;
  final VoidCallback? onOpenDestek;
  final VoidCallback? onOpenHaklar;
  final VoidCallback? onOpenHarita;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          L10nText(
            'Hızlı Erişim',
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HizliTile(
                  label: 'Tarama',
                  icon: Icons.qr_code_scanner,
                  onTap: onOpenTarama,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HizliTile(
                  label: 'Destek Sorgulama',
                  icon: Icons.favorite,
                  onTap: onOpenDestek,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HizliTile(
                  label: 'Hak Sorgulama',
                  icon: Icons.verified_user,
                  onTap: onOpenHaklar,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HizliTile(
                  label: 'Engelsiz Haritalar',
                  icon: Icons.place,
                  onTap: onOpenHarita,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HizliTile extends StatelessWidget {
  const _HizliTile({
    required this.label,
    required this.icon,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MetoColors.primary,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: MetoColors.muted,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: MetoColors.primary),
              ),
              const SizedBox(height: 8),
              L10nText(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
