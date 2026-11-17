import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../admin_config.dart';
import '../app_sections_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../pages/uzman_kosesi_page.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import 'catalog_media.dart';

/// Ana sayfa: Kariyer/Gezi kutucuklarıyla aynı kapak stili — Uzman Köşesi.
/// Mevcut Gezi/Dernek bileşenlerine dokunmaz; aynı görsel kalıbı yeniden kullanır.
class UzmanKosesHomeSection extends StatefulWidget {
  const UzmanKosesHomeSection({
    super.key,
    required this.userEmail,
    this.isGuest = false,
    this.onRequireLogin,
    this.onOpen,
  });

  final String userEmail;
  final bool isGuest;
  final VoidCallback? onRequireLogin;
  /// Verilmezse kendi Uzman Köşesi sayfası açılır (Forum değil).
  final VoidCallback? onOpen;

  @override
  State<UzmanKosesHomeSection> createState() => _UzmanKosesHomeSectionState();
}

class _UzmanKosesHomeSectionState extends State<UzmanKosesHomeSection> {
  AppSection _section = kDefaultUzmanKosesSection;

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  @override
  void initState() {
    super.initState();
    final cached = cachedUzmanKoses;
    if (cached != null) _section = cached;
    _load(force: !hasFreshUzmanKosesCache);
  }

  Future<void> _load({bool force = false}) async {
    final row = await loadUzmanKosesSection(forceRefresh: force);
    if (!mounted) return;
    setState(() => _section = row);
  }

  Future<void> _edit() async {
    if (!_isAdmin) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UzmanKosesEditSheet(
        adminEmail: widget.userEmail,
        section: _section,
      ),
    );
    if (saved == true && mounted) {
      await _load(force: true);
    }
  }

  void _openPage() {
    if (widget.onOpen != null) {
      widget.onOpen!();
      return;
    }
    UzmanKosesPage.open(
      context,
      userEmail: widget.userEmail,
      isGuest: widget.isGuest,
      onRequireLogin: widget.onRequireLogin,
    );
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildBody(context);
    } catch (e, st) {
      debugPrint('UzmanKosesHomeSection: $e\n$st');
      return _fallbackBody();
    }
  }

  Widget _buildBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: L10nText(
              _section.title,
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
                const tileH = 180.0;
                final w = constraints.hasBoundedWidth &&
                        constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 360.0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: w,
                      height: tileH,
                      child: _UzmanKosesBox(
                        coverUrl: _section.coverImageUrl,
                        isAdmin: _isAdmin,
                        onTap: _openPage,
                        onEdit: _edit,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: w,
                      child: L10nText(
                        _section.title,
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
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          L10nText(
            kDefaultUzmanKosesTitle,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: _UzmanKosesBox(
              coverUrl: '',
              isAdmin: _isAdmin,
              onTap: _openPage,
              onEdit: _edit,
            ),
          ),
        ],
      ),
    );
  }
}

class _UzmanKosesBox extends StatelessWidget {
  const _UzmanKosesBox({
    required this.coverUrl,
    required this.isAdmin,
    required this.onTap,
    required this.onEdit,
  });

  final String coverUrl;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback onEdit;

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
                    errorBuilder: (_, __, ___) => const _DefaultCover(),
                  ),
                )
              else
                const _DefaultCover(),
              if (isAdmin)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      tooltip: S.auto('Düzenle'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onEdit,
                      icon: const Icon(
                        Icons.edit_outlined,
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

class _DefaultCover extends StatelessWidget {
  const _DefaultCover();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MetoColors.primary.withValues(alpha: 0.08),
      ),
      child: const Center(
        child: Icon(
          Icons.menu_book_outlined,
          size: 36,
          color: MetoColors.primary,
        ),
      ),
    );
  }
}

class _UzmanKosesEditSheet extends StatefulWidget {
  const _UzmanKosesEditSheet({
    required this.adminEmail,
    required this.section,
  });

  final String adminEmail;
  final AppSection section;

  @override
  State<_UzmanKosesEditSheet> createState() => _UzmanKosesEditSheetState();
}

class _UzmanKosesEditSheetState extends State<_UzmanKosesEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _imageUrl;
  Uint8List? _pickedBytes;
  bool _saving = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.section.title);
    _imageUrl = TextEditingController(text: widget.section.coverImageUrl);
  }

  @override
  void dispose() {
    _title.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MetoColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: L10nText(
                  'Kapak görseli',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: MetoColors.primary,
                ),
                title: const L10nText('Galeriden seç'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: MetoColors.primary,
                ),
                title: const L10nText('Kamerayla çek'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const L10nText('Vazgeç'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    final file = await ImagePicker().pickImage(
      source: source,
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
            'tile_uzman_kosesi_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: optimized.contentType,
      );
    }
    return _imageUrl.text.trim();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final image = await _resolveImage();
      await upsertUzmanKosesSection(
        title: _title.text,
        coverImageUrl: image,
        adminEmail: widget.adminEmail,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final raw = e.toString();
      final hint = raw.contains('app_sections') ||
              raw.contains('PGRST') ||
              raw.contains('schema')
          ? 'Tablo yok. Supabase SQL Editor’de app_sections.sql çalıştırın.'
          : 'Kaydedilemedi: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
    }
  }

  Future<void> _clearCover() async {
    setState(() => _clearing = true);
    try {
      await upsertUzmanKosesSection(
        title: _title.text.trim().isEmpty
            ? kDefaultUzmanKosesTitle
            : _title.text,
        coverImageUrl: '',
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
    final currentUrl = widget.section.coverImageUrl;
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
                'Kartı düzenle',
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
                    : currentUrl.trim().isNotEmpty
                        ? CatalogImage(
                            source: currentUrl,
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
                label: const L10nText('Galeriden / kameradan görsel seç'),
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
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _title,
                enabled: !busy,
                style: GoogleFonts.nunito(),
                decoration: _dec('Kart adı (kutunun altında)'),
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
              if (currentUrl.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy ? null : _clearCover,
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
