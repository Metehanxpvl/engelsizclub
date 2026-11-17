import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../gezi_kampanya_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import 'kampanya_category_tile.dart';
import 'photo_gallery_lightbox.dart';

Future<void> showKampanyaDetailSheet(
  BuildContext context, {
  required KampanyaItem item,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MetoColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => KampanyaDetailSheet(item: item),
  );
}

class KampanyaDetailSheet extends StatelessWidget {
  const KampanyaDetailSheet({super.key, required this.item});

  final KampanyaItem item;

  Future<void> _openCompany(BuildContext context) async {
    final raw = item.companyUrl.trim();
    if (raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Link açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim();
    final desc = item.description.trim();
    final loc = item.locationLabel.trim();
    final cat = item.categoryLabel.trim();
    final img = item.imageUrl.trim();
    final maxH = MediaQuery.sizeOf(context).height * 0.92;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MetoColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (img.isNotEmpty)
                      GestureDetector(
                        onTap: () =>
                            openFillPhotoOverlay(context, source: img),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: FillPhoto(
                              source: img,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    if (cat.isNotEmpty || loc.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (cat.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: kampanyaCategoryTint(item.category)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    kampanyaCategoryIcon(item.category),
                                    size: 16,
                                    color: kampanyaCategoryTint(item.category),
                                  ),
                                  const SizedBox(width: 6),
                                  L10nText(
                                    cat,
                                    style: GoogleFonts.nunito(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: kampanyaCategoryTint(item.category),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (loc.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: MetoColors.muted,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: L10nText(
                                loc,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        title,
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SelectableText(
                        desc,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: MetoColors.foreground,
                        ),
                      ),
                    ],
                    if (item.hasCompanyUrl) ...[
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _openCompany(context),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: L10nText(
                          'Firma sitesine git',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: MetoColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
