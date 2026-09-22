import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../gezi_kampanya_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';

IconData kampanyaCategoryIcon(String raw) {
  switch (normalizeKampanyaCategory(raw)) {
    case 'saglik':
      return Icons.health_and_safety_outlined;
    case 'restoran':
      return Icons.restaurant_outlined;
    case 'giyim':
      return Icons.checkroom_outlined;
    case 'egitim':
      return Icons.school_outlined;
    case 'marka':
      return Icons.handshake_outlined;
    case 'medikal':
      return Icons.medical_services_outlined;
    case '':
      return Icons.apps_outlined;
    default:
      return Icons.local_offer_outlined;
  }
}

Color kampanyaCategoryTint(String raw) {
  switch (normalizeKampanyaCategory(raw)) {
    case 'saglik':
      return const Color(0xFF0E8A6A);
    case 'restoran':
      return const Color(0xFFC45C26);
    case 'giyim':
      return const Color(0xFF5B4DB1);
    case 'egitim':
      return const Color(0xFF1B6FA8);
    case 'marka':
      return const Color(0xFFB45309);
    default:
      return MetoColors.primary;
  }
}

/// Kategori kutucuğu: ikon kutu + altında isim.
class KampanyaCategoryTile extends StatelessWidget {
  const KampanyaCategoryTile({
    super.key,
    required this.categoryKey,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
  });

  final String categoryKey;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tint = kampanyaCategoryTint(categoryKey);
    final fg = selected ? Colors.white : tint;
    return SizedBox(
      width: 78,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: selected ? tint : tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 64,
                height: 64,
                child: Icon(
                  icon ?? kampanyaCategoryIcon(categoryKey),
                  size: 28,
                  color: fg,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          L10nText(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: selected ? tint : MetoColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}
