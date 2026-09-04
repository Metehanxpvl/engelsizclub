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
    this.avmCoverUrl = '',
    this.coverVariantSeed = 0,
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
  /// AVM sayfasından og/hero foto (etkinlik görseli yoksa / yüklenemezse).
  final String avmCoverUrl;
  /// Son çare illüstrasyon varyantı (etkinlik id).
  final int coverVariantSeed;

  bool get _hasCaption => description.trim().isNotEmpty;
  bool get _hasTitle => title.trim().isNotEmpty;
  bool get _hasVenue => venueLabel.trim().isNotEmpty;
  bool get _hasWhen => whenLabel.trim().isNotEmpty;
  bool get _hasTime => timeLabel.trim().isNotEmpty;
  bool get _hasMeta => _hasVenue || _hasWhen || _hasTime;

  String get _lightboxSrc {
    final eventSrc = imageUrl.trim();
    if (eventSrc.isNotEmpty) return eventSrc;
    return avmCoverUrl.trim();
  }

  void _openLightbox(BuildContext context) {
    final src = _lightboxSrc;
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

  Widget _lastResortCover() {
    if (brandedCover) {
      return _BrandedCoverPlaceholder(
        label: coverPlaceholderLabel,
        variant: coverVariantSeed.abs() % 3,
      );
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

  Widget _coverImage() {
    final last = SizedBox.expand(child: _lastResortCover());
    final eventSrc = imageUrl.trim();
    final mallSrc = avmCoverUrl.trim();
    if (eventSrc.isEmpty && mallSrc.isEmpty) return last;
    if (eventSrc.isEmpty) {
      return FillPhoto(
        source: mallSrc,
        fit: BoxFit.cover,
        placeholder: last,
      );
    }
    final mallFallback = (mallSrc.isNotEmpty && mallSrc != eventSrc)
        ? FillPhoto(source: mallSrc, fit: BoxFit.cover, placeholder: last)
        : last;
    return FillPhoto(
      source: eventSrc,
      fit: BoxFit.cover,
      placeholder: mallFallback,
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
    final showLocationChip = locationLabel.trim().isNotEmpty;

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
                    child: _coverImage(),
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

/// Son çare: AVM sayfasında foto yoksa çocuk etkinliği illüstrasyonu.
class _BrandedCoverPlaceholder extends StatelessWidget {
  const _BrandedCoverPlaceholder({this.label = '', this.variant = 0});

  final String label;
  final int variant;

  @override
  Widget build(BuildContext context) {
    final name = label.trim();
    return Semantics(
      label: name.isEmpty ? 'Etkinlik' : name,
      child: CustomPaint(
        painter: _KidsEventCoverPainter(variant: variant),
      ),
    );
  }
}

class _KidsEventCoverPainter extends CustomPainter {
  _KidsEventCoverPainter({required this.variant});

  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A6B4A), Color(0xFF0D2B1F)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final gold = Paint()..color = const Color(0xFFF4A832);
    final cream = Paint()..color = const Color(0xFFFFF6E0);
    final coral = Paint()..color = const Color(0xFFE07A5F);
    final mint = Paint()..color = const Color(0xFF7BC49A);
    final whiteSoft = Paint()..color = Colors.white.withValues(alpha: 0.18);

    canvas.drawCircle(Offset(size.width * 0.88, size.height * -0.08), 70, whiteSoft);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 1.05), 54, whiteSoft);

    switch (variant % 3) {
      case 0:
        _balloon(canvas, Offset(size.width * 0.22, size.height * 0.42), 16, coral);
        _balloon(canvas, Offset(size.width * 0.38, size.height * 0.32), 14, gold);
        _balloon(canvas, Offset(size.width * 0.72, size.height * 0.38), 17, mint);
        _block(canvas, Offset(size.width * 0.52, size.height * 0.62), 28, 22, cream);
        _block(canvas, Offset(size.width * 0.58, size.height * 0.72), 22, 16, gold);
        break;
      case 1:
        _block(canvas, Offset(size.width * 0.28, size.height * 0.55), 32, 24, gold);
        _block(canvas, Offset(size.width * 0.34, size.height * 0.68), 26, 18, coral);
        _block(canvas, Offset(size.width * 0.18, size.height * 0.68), 20, 18, mint);
        canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.42), 22, cream);
        canvas.drawCircle(Offset(size.width * 0.72, size.height * 0.42), 8, coral);
        break;
      default:
        _balloon(canvas, Offset(size.width * 0.68, size.height * 0.34), 15, gold);
        _balloon(canvas, Offset(size.width * 0.80, size.height * 0.44), 13, coral);
        _kite(canvas, Offset(size.width * 0.30, size.height * 0.40), cream, mint);
        canvas.drawCircle(Offset(size.width * 0.52, size.height * 0.70), 18, gold);
        break;
    }
  }

  void _balloon(Canvas canvas, Offset c, double r, Paint paint) {
    canvas.drawOval(Rect.fromCenter(center: c, width: r * 1.5, height: r * 2), paint);
    final string = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(c.translate(0, r), c.translate(4, r + 22), string);
  }

  void _block(Canvas canvas, Offset origin, double w, double h, Paint paint) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx, origin.dy, w, h),
        const Radius.circular(4),
      ),
      paint,
    );
  }

  void _kite(Canvas canvas, Offset c, Paint fill, Paint accent) {
    final path = Path()
      ..moveTo(c.dx, c.dy - 22)
      ..lineTo(c.dx + 16, c.dy)
      ..lineTo(c.dx, c.dy + 22)
      ..lineTo(c.dx - 16, c.dy)
      ..close();
    canvas.drawPath(path, fill);
    final line = Paint()
      ..color = accent.color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(c.translate(-16, 0), c.translate(16, 0), line);
  }

  @override
  bool shouldRepaint(covariant _KidsEventCoverPainter oldDelegate) =>
      oldDelegate.variant != variant;
}
