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
    this.locationLabel = '',
    this.venueLabel = '',
    this.whenLabel = '',
    this.timeLabel = '',
    this.brandedCover = false,
    this.coverPlaceholderLabel = '',
  });

  final String imageUrl;
  final String title;
  final String description;
  final bool isAdmin;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final String locationLabel;
  /// AVM / mekân adı (kart gövdesinde ikonla).
  final String venueLabel;
  /// Tarih veya dönem (ör. 7 Eylül 2026, Her hafta sonu).
  final String whenLabel;
  /// Saat varsa (ör. 14:00); yoksa gösterilmez.
  final String timeLabel;
  /// Etkinlik kartlarında boş/kırık görsel için markalı kapak.
  final bool brandedCover;
  final String coverPlaceholderLabel;

  bool get _hasCaption => description.trim().isNotEmpty;
  bool get _hasTitle => title.trim().isNotEmpty;
  bool get _hasVenue => venueLabel.trim().isNotEmpty;
  bool get _hasWhen => whenLabel.trim().isNotEmpty;
  bool get _hasTime => timeLabel.trim().isNotEmpty;
  bool get _hasMeta => _hasVenue || _hasWhen || _hasTime;
  bool get _hasPhoto => imageUrl.trim().isNotEmpty;

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

  Widget _coverPlaceholder() {
    if (brandedCover) {
      return _BrandedCoverPlaceholder(label: coverPlaceholderLabel);
    }
    return ColoredBox(
      color: MetoColors.muted,
      child: Icon(
        Icons.image_outlined,
        color: MetoColors.mutedFg.withValues(alpha: 0.7),
        size: 40,
      ),
    );
  }

  Widget _metaLine({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: MetoColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: L10nText(
            text.trim(),
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: MetoColors.mutedFg,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEditDelete =
        isAdmin && (onDelete != null || onEdit != null);
    final showReorder =
        isAdmin && (onMoveUp != null || onMoveDown != null);
    final showLocationChip =
        _hasPhoto && locationLabel.trim().isNotEmpty;

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
                      placeholder: SizedBox.expand(child: _coverPlaceholder()),
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
                  if (showLocationChip)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xCC111827),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: L10nText(
                            locationLabel.trim(),
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
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
                    if (_hasMeta)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          _hasTitle ? 8 : 12,
                          14,
                          _hasCaption ? 0 : 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_hasVenue)
                              _metaLine(
                                icon: Icons.storefront_outlined,
                                text: venueLabel,
                              ),
                            if (_hasVenue && (_hasWhen || _hasTime))
                              const SizedBox(height: 6),
                            if (_hasWhen || _hasTime)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_hasWhen)
                                    Expanded(
                                      child: _metaLine(
                                        icon: Icons.calendar_today_outlined,
                                        text: whenLabel,
                                      ),
                                    ),
                                  if (_hasWhen && _hasTime)
                                    const SizedBox(width: 12),
                                  if (_hasTime)
                                    Expanded(
                                      child: _metaLine(
                                        icon: Icons.schedule_outlined,
                                        text: timeLabel,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    if (_hasCaption)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          (_hasTitle || _hasMeta) ? 6 : 12,
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
                    else if (!_hasTitle && !_hasMeta)
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

/// Boş / kırık görsel: yeşil degrade + baş harf / AVM adı.
class _BrandedCoverPlaceholder extends StatelessWidget {
  const _BrandedCoverPlaceholder({this.label = ''});

  final String label;

  String get _initials {
    final t = label.trim();
    if (t.isEmpty) return '';
    String firstRune(String s) =>
        s.isEmpty ? '' : String.fromCharCode(s.runes.first);
    final parts =
        t.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${firstRune(parts[0])}${firstRune(parts[1])}'.toUpperCase();
    }
    final runes = t.runes.take(2).toList();
    return String.fromCharCodes(runes).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = label.trim();
    final initials = _initials;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A6B4A), Color(0xFF0D2B1F)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            right: -28,
            top: -36,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MetoColors.accentGold.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            left: -20,
            bottom: -28,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: initials.isEmpty
                      ? const Icon(
                          Icons.event_outlined,
                          color: Colors.white,
                          size: 28,
                        )
                      : Text(
                          initials,
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                ),
                if (name.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  L10nText(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: Colors.white,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  L10nText(
                    'Etkinlik',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
