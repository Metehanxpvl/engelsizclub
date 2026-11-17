import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../gezi_kampanya_store.dart';
import '../section_editors.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../pages/engelsiz_kariyer_page.dart';
import '../pages/etkinlikler_page.dart';
import '../pages/gezi_rehberi_page.dart';
import '../pages/kampanyalar_page.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import 'catalog_media.dart';

/// Ana sayfa: Bilgi Kütüphanesi üstü — üstte Kariyer | Gezi, altta Kampanya | Etkinlik.
/// Kariyer kutusu [kShowEngelsizKariyerTile] ile açılıp kapanır.
class GeziKampanyaHomeSection extends StatefulWidget {
  const GeziKampanyaHomeSection({
    super.key,
    required this.userEmail,
    this.isGuest = false,
    this.onRequireLogin,
  });

  final String userEmail;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<GeziKampanyaHomeSection> createState() =>
      _GeziKampanyaHomeSectionState();
}

class _GeziKampanyaHomeSectionState extends State<GeziKampanyaHomeSection> {
  Map<String, String> _covers = const {
    kKariyerTileKey: '',
    kGeziTileKey: '',
    kKampanyaTileKey: '',
    kEtkinlikTileKey: '',
  };

  bool _canEditTile(String tileKey) {
    final key = sectionKeyForTile(tileKey);
    if (key == null) return false;
    return canEditSection(widget.userEmail, key);
  }

  @override
  void initState() {
    super.initState();
    final cached = cachedTileCovers;
    if (cached != null) {
      _covers = Map<String, String>.from(cached);
    }
    _loadCovers(force: !hasFreshTileCoverCache);
  }

  Future<void> _loadCovers({bool force = false}) async {
    await ensureSectionEditorsLoaded(widget.userEmail);
    final map = await loadTileCovers(forceRefresh: force);
    if (!mounted) return;
    setState(() => _covers = map);
  }

  Future<void> _editCover(String tileKey, String title) async {
    if (!_canEditTile(tileKey)) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TileCoverSheet(
        adminEmail: widget.userEmail,
        tileKey: tileKey,
        title: title,
        currentUrl: _covers[tileKey] ?? '',
      ),
    );
    if (saved == true && mounted) {
      await _loadCovers(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: L10nText(
              kShowEngelsizKariyerTile
                  ? 'Engelsiz Kariyer & Gezi Rehberi & Kampanyalar & Etkinlikler'
                  : 'Gezi Rehberi & Kampanyalar & Etkinlikler',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                const tileH = 120.0;
                final w = constraints.maxWidth;
                final twoColW = ((w - gap) / 2).floorToDouble();
                Widget tile({
                  required String title,
                  required String tileKey,
                  required VoidCallback onTap,
                  IconData? emptyIcon,
                  required double cardW,
                }) {
                  return SizedBox(
                    width: cardW,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: cardW,
                          height: tileH,
                          child: _Box(
                            coverUrl: _covers[tileKey] ?? '',
                            isAdmin: _canEditTile(tileKey),
                            emptyIcon: emptyIcon,
                            onTap: onTap,
                            onEditCover: () => _editCover(tileKey, title),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: cardW,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: cardW),
                              child: L10nText(
                                title,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  color: MetoColors.foreground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final kariyer = tile(
                  title: 'Engelsiz Kariyer',
                  tileKey: kKariyerTileKey,
                  emptyIcon: Icons.work_outline,
                  cardW: twoColW,
                  onTap: () => EngelsizKariyerPage.open(
                    context,
                    userEmail: widget.userEmail,
                  ),
                );
                final gezi = tile(
                  title: 'Gezi Rehberi',
                  tileKey: kGeziTileKey,
                  cardW: twoColW,
                  onTap: () => GeziRehberiPage.open(
                    context,
                    userEmail: widget.userEmail,
                  ),
                );
                final kampanya = tile(
                  title: 'Kampanyalar',
                  tileKey: kKampanyaTileKey,
                  cardW: twoColW,
                  onTap: () => KampanyalarPage.open(
                    context,
                    userEmail: widget.userEmail,
                    isGuest: widget.isGuest,
                    onRequireLogin: widget.onRequireLogin,
                  ),
                );
                final etkinlik = tile(
                  title: 'Etkinlikler',
                  tileKey: kEtkinlikTileKey,
                  cardW: twoColW,
                  onTap: () => EtkinliklerPage.open(
                    context,
                    userEmail: widget.userEmail,
                    isGuest: widget.isGuest,
                    onRequireLogin: widget.onRequireLogin,
                  ),
                );

                Widget pair(Widget left, Widget right) {
                  return Row(
                    children: [
                      left,
                      const SizedBox(width: gap),
                      right,
                    ],
                  );
                }

                if (kShowEngelsizKariyerTile) {
                  return Column(
                    children: [
                      pair(kariyer, gezi),
                      const SizedBox(height: 12),
                      pair(kampanya, etkinlik),
                    ],
                  );
                }

                const minCard = 88.0;
                final threeW = (w - 2 * gap) / 3;
                final useEven = threeW >= minCard;
                final cardW = useEven
                    ? threeW.floorToDouble()
                    : ((w - 2 * gap) / 3.15)
                        .floorToDouble()
                        .clamp(minCard, 160.0);
                final row = Row(
                  children: [
                    tile(
                      title: 'Gezi Rehberi',
                      tileKey: kGeziTileKey,
                      cardW: cardW,
                      onTap: () => GeziRehberiPage.open(
                        context,
                        userEmail: widget.userEmail,
                      ),
                    ),
                    SizedBox(width: gap),
                    tile(
                      title: 'Kampanyalar',
                      tileKey: kKampanyaTileKey,
                      cardW: cardW,
                      onTap: () => KampanyalarPage.open(
                        context,
                        userEmail: widget.userEmail,
                        isGuest: widget.isGuest,
                        onRequireLogin: widget.onRequireLogin,
                      ),
                    ),
                    SizedBox(width: gap),
                    tile(
                      title: 'Etkinlikler',
                      tileKey: kEtkinlikTileKey,
                      cardW: cardW,
                      onTap: () => EtkinliklerPage.open(
                        context,
                        userEmail: widget.userEmail,
                        isGuest: widget.isGuest,
                        onRequireLogin: widget.onRequireLogin,
                      ),
                    ),
                  ],
                );
                if (useEven) return row;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: row,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({
    required this.coverUrl,
    required this.isAdmin,
    required this.onTap,
    required this.onEditCover,
    this.emptyIcon,
  });

  final String coverUrl;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEditCover;
  final IconData? emptyIcon;

  bool get _hasCover => coverUrl.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.primary, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_hasCover)
                Positioned.fill(
                  child: CatalogImage(
                    source: coverUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: MetoColors.card,
                    ),
                  ),
                )
              else if (emptyIcon != null)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: MetoColors.primary.withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: Icon(
                      emptyIcon,
                      size: 36,
                      color: MetoColors.primary,
                    ),
                  ),
                ),
              if (isAdmin)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: S.auto('Kapak görseli'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onEditCover,
                      icon: Icon(
                        Icons.photo_camera_outlined,
                        size: 18,
                        color: MetoColors.primary,
                      ),
                    ),
                  ),
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
        ),
      ),
    );
  }
}

class _TileCoverSheet extends StatefulWidget {
  const _TileCoverSheet({
    required this.adminEmail,
    required this.tileKey,
    required this.title,
    required this.currentUrl,
  });

  final String adminEmail;
  final String tileKey;
  final String title;
  final String currentUrl;

  @override
  State<_TileCoverSheet> createState() => _TileCoverSheetState();
}

class _TileCoverSheetState extends State<_TileCoverSheet> {
  late final TextEditingController _imageUrl;
  Uint8List? _pickedBytes;
  bool _saving = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = TextEditingController(text: widget.currentUrl);
  }

  @override
  void dispose() {
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 86,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _imageUrl.clear();
    });
  }

  Future<String> _resolveImage() async {
    if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
      final optimized =
          await ImageOptimizeService.forCatalogCard(_pickedBytes!);
      return R2StorageService.uploadBytes(
        bytes: optimized.bytes,
        fileName:
            'tile_${widget.tileKey}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: optimized.contentType,
      );
    }
    return _imageUrl.text.trim();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final image = await _resolveImage();
      if (image.isEmpty) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: L10nText('Görsel yükleyin veya URL girin.')),
        );
        return;
      }
      await upsertTileCover(
        tileKey: widget.tileKey,
        imageUrl: image,
        adminEmail: widget.adminEmail,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final raw = e.toString();
      final hint = raw.contains('gezi_kampanya_tiles') ||
              raw.contains('tile_key') ||
              raw.contains('PGRST') ||
              raw.contains('schema')
          ? 'Tablo yok. Supabase’de gezi_kampanya_tiles.sql, ardından etkinlikler.sql çalıştırın.'
          : 'Kaydedilemedi: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
    }
  }

  Future<void> _clear() async {
    setState(() => _clearing = true);
    try {
      await upsertTileCover(
        tileKey: widget.tileKey,
        imageUrl: '',
        adminEmail: widget.adminEmail,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _clearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaldırılamadı: $e')),
      );
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: MetoColors.background,
        hintStyle: GoogleFonts.nunito(color: MetoColors.mutedFg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.primary),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final busy = _saving || _clearing;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetoColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              L10nText(
                '${widget.title} kapak görseli',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _pickedBytes != null
                    ? Image.memory(
                        _pickedBytes!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : widget.currentUrl.trim().isNotEmpty
                        ? CatalogImage(
                            source: widget.currentUrl,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholderPreview(),
                          )
                        : _placeholderPreview(),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: busy ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const L10nText('Galeriden görsel seç'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MetoColors.primary,
                  side: const BorderSide(color: MetoColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _imageUrl,
                enabled: !busy,
                style: GoogleFonts.nunito(),
                decoration: _dec('veya görsel URL (https://…)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : L10nText(
                        'Kaydet',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
              ),
              if (widget.currentUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy ? null : _clear,
                  child: _clearing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : L10nText(
                          'Kapağı kaldır',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderPreview() {
    return Container(
      height: 140,
      width: double.infinity,
      color: MetoColors.background,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        size: 36,
        color: MetoColors.mutedFg,
      ),
    );
  }
}
