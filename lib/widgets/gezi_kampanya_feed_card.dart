import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import 'photo_gallery_lightbox.dart';

/// Story benzeri kart: görsel + başlık + açıklama.
/// Görsele veya karta dokununca eklenen görsel tam ekran açılır.
class GeziKampanyaFeedCard extends StatelessWidget {
  const GeziKampanyaFeedCard({
    super.key,
    required this.imageUrl,
    this.title = '',
    this.description = '',
    this.isAdmin = false,
    this.onDelete,
    this.onEdit,
    this.onMoveUp,
    this.onMoveDown,
  });

  final String imageUrl;
  final String title;
  final String description;
  final bool isAdmin;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  bool get _hasCaption => description.trim().isNotEmpty;
  bool get _hasTitle => title.trim().isNotEmpty;

  void _openLightbox(BuildContext context) {
    final src = imageUrl.trim();
    if (src.isEmpty) return;
    openFillPhotoOverlay(context, source: src);
  }

  Widget _adminChip({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: S.auto(tooltip),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEditDelete =
        isAdmin && (onDelete != null || onEdit != null);
    final showReorder =
        isAdmin && (onMoveUp != null || onMoveDown != null);

    // Frame is a later Stack sibling so web HtmlElementView photos cannot
    // cover it (Kampanyalar cards are often image-only; clip+border was eaten).
    return Container(
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: FillPhoto(
                      source: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: ColoredBox(
                        color: MetoColors.muted,
                        child: Icon(
                          Icons.image_outlined,
                          color: MetoColors.mutedFg.withValues(alpha: 0.7),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  // Html img yutmasın diye dokunma katmanı görselin ÜSTÜNDE (kardeş).
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openLightbox(context),
                      ),
                    ),
                  ),
                  if (showEditDelete)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onEdit != null) ...[
                            _adminChip(
                              tooltip: 'Düzenle',
                              icon: Icons.edit_outlined,
                              onPressed: onEdit!,
                              color: const Color(0xCC2563EB),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (onDelete != null)
                            _adminChip(
                              tooltip: 'Sil',
                              icon: Icons.delete_outline,
                              onPressed: onDelete!,
                              color: const Color(0xCCDC2626),
                            ),
                        ],
                      ),
                    ),
                  if (showReorder)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (onMoveUp != null)
                            _adminChip(
                              tooltip: 'Yukarı',
                              icon: Icons.keyboard_arrow_up,
                              onPressed: onMoveUp!,
                              color: const Color(0xCC111827),
                            ),
                          if (onMoveUp != null && onMoveDown != null)
                            const SizedBox(width: 6),
                          if (onMoveDown != null)
                            _adminChip(
                              tooltip: 'Aşağı',
                              icon: Icons.keyboard_arrow_down,
                              onPressed: onMoveDown!,
                              color: const Color(0xCC111827),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _openLightbox(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_hasTitle)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        child: L10nText(
                          title.trim(),
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                      ),
                    if (_hasCaption)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          _hasTitle ? 6 : 12,
                          14,
                          14,
                        ),
                        child: L10nText(
                          description.trim(),
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                            color: MetoColors.foreground,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MetoColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
