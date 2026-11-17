import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../admin_config.dart';
import '../dernekler_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../pages/in_app_web_page.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import 'catalog_media.dart';

/// Ana sayfa: Bilgi Kütüphanesi üstü — Dernekler (2 sütun, Kariyer/Gezi kutusu).
class DerneklerHomeSection extends StatefulWidget {
  const DerneklerHomeSection({
    super.key,
    required this.userEmail,
    this.isGuest = false,
    this.onRequireLogin,
  });

  final String userEmail;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<DerneklerHomeSection> createState() => _DerneklerHomeSectionState();
}

class _DerneklerHomeSectionState extends State<DerneklerHomeSection> {
  List<DernekItem> _items = List<DernekItem>.from(kDefaultDernekler);
  bool _loading = true;

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  @override
  void initState() {
    super.initState();
    final cached = cachedDernekler;
    if (cached != null) {
      _items = visibleDernekler(cached, admin: _isAdmin);
      _loading = false;
    }
    _load(force: !hasFreshDerneklerCache);
  }

  Future<void> _load({bool force = false}) async {
    try {
      final list = await loadDernekler(
        forceRefresh: force,
        viewerEmail: widget.userEmail,
      );
      if (!mounted) return;
      setState(() {
        _items = list.isEmpty
            ? visibleDernekler(kDefaultDernekler, admin: _isAdmin)
            : list;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('Dernekler load: $e\n$st');
      if (!mounted) return;
      setState(() {
        if (_items.isEmpty) {
          _items = visibleDernekler(kDefaultDernekler, admin: _isAdmin);
        }
        _loading = false;
      });
    }
  }

  TextStyle _headingStyle() => _nunito(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: MetoColors.foreground,
      );

  TextStyle _titleStyle() => _nunito(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: MetoColors.foreground,
      );

  Future<void> _openLink(DernekItem item) async {
    if (!item.hasLink) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: L10nText(
            _isAdmin
                ? 'Önce bu kutucuğa bir link ekleyin.'
                : 'Link henüz eklenmedi.',
          ),
        ),
      );
      return;
    }
    await InAppWebPage.open(
      context,
      title: item.title,
      url: item.websiteUrl,
      isGuest: widget.isGuest,
      onRequireLogin: widget.onRequireLogin,
    );
  }

  Future<void> _edit({DernekItem? item}) async {
    if (!_isAdmin) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DernekEditSheet(
        adminEmail: widget.userEmail,
        edit: item,
      ),
    );
    if (saved == true && mounted) {
      await _load(force: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return _buildBody(context);
    } catch (e, st) {
      debugPrint('DerneklerHomeSection: $e\n$st');
      return _fallbackBody(context);
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
            child: Row(
              children: [
                Expanded(
                  child: L10nText(
                    'Dernekler',
                    style: _headingStyle(),
                  ),
                ),
                if (_isAdmin)
                  IconButton(
                    tooltip: S.auto('Yeni dernek kutucuğu'),
                    onPressed: () => _edit(),
                    style: IconButton.styleFrom(
                      backgroundColor: MetoColors.primary.withValues(alpha: 0.1),
                      foregroundColor: MetoColors.primary,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                try {
                  return _buildGrid(constraints);
                } catch (e, st) {
                  debugPrint('Dernekler grid: $e\n$st');
                  return _simpleGrid(context);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackBody(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dernekler',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          _simpleGrid(context),
        ],
      ),
    );
  }

  Widget _simpleGrid(BuildContext context) {
    final items = (_items.isEmpty ? kDefaultDernekler : _items).take(2).toList();
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  height: 120,
                  child: _DernekBox(
                    coverUrl: items[i].imageUrl,
                    isAdmin: false,
                    onTap: () => _openLink(items[i]),
                    onEdit: () {},
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  items[i].title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: MetoColors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildGrid(BoxConstraints constraints) {
    const gap = 12.0;
    const tileH = 120.0;
    final w = constraints.hasBoundedWidth && constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : 360.0;
    final cardW = ((w - gap) / 2).floorToDouble().clamp(80.0, w);
    final tiles = <Widget>[
      for (final item in _items)
        SizedBox(
          width: cardW,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: cardW,
                height: tileH,
                child: _DernekBox(
                  coverUrl: item.imageUrl,
                  isAdmin: _isAdmin,
                  onTap: () => _openLink(item),
                  onEdit: () => _edit(item: item),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: cardW,
                child: L10nText(
                  item.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _titleStyle(),
                ),
              ),
            ],
          ),
        ),
    ];
    if (tiles.isEmpty && !_loading) {
      return L10nText(
        'Henüz dernek kutucuğu yok.',
        style: _nunito(color: MetoColors.mutedFg),
      );
    }
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 12));
      final left = tiles[i];
      final right = i + 1 < tiles.length ? tiles[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            left,
            const SizedBox(width: gap),
            if (right != null) right else SizedBox(width: cardW),
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

TextStyle _nunito({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? height,
}) {
  try {
    return GoogleFonts.nunito(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  } catch (_) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }
}

class _DernekBox extends StatelessWidget {
  const _DernekBox({
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
    try {
      return _buildBox(context);
    } catch (e, st) {
      debugPrint('DernekBox: $e\n$st');
      return Material(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: const Center(
            child: Icon(Icons.groups_outlined, color: MetoColors.primary),
          ),
        ),
      );
    }
  }

  Widget _buildBox(BuildContext context) {
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
              else
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: MetoColors.primary.withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.groups_outlined,
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
                      tooltip: S.auto('Düzenle'),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onEdit,
                      icon: Icon(
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

class _DernekEditSheet extends StatefulWidget {
  const _DernekEditSheet({
    required this.adminEmail,
    this.edit,
  });

  final String adminEmail;
  final DernekItem? edit;

  @override
  State<_DernekEditSheet> createState() => _DernekEditSheetState();
}

class _DernekEditSheetState extends State<_DernekEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _imageUrl;
  late final TextEditingController _websiteUrl;
  Uint8List? _pickedBytes;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.edit?.title ?? '');
    _imageUrl = TextEditingController(text: widget.edit?.imageUrl ?? '');
    _websiteUrl = TextEditingController(text: widget.edit?.websiteUrl ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _imageUrl.dispose();
    _websiteUrl.dispose();
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
            'dernek_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: optimized.contentType,
      );
    }
    return _imageUrl.text.trim();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final image = await _resolveImage();
      await upsertDernek(
        id: widget.edit?.id,
        title: _title.text,
        imageUrl: image,
        websiteUrl: _websiteUrl.text,
        adminEmail: widget.adminEmail,
        sortOrder: widget.edit?.sortOrder,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final raw = e.toString();
      final hint = raw.contains('dernekler') ||
              raw.contains('PGRST') ||
              raw.contains('schema')
          ? 'Tablo yok. Supabase SQL Editor’de dernekler.sql çalıştırın.'
          : 'Kaydedilemedi: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
    }
  }

  Future<void> _delete() async {
    final id = widget.edit?.id ?? 0;
    setState(() => _deleting = true);
    try {
      await deleteDernek(id: id, adminEmail: widget.adminEmail);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e')),
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
    final busy = _saving || _deleting;
    final currentUrl = widget.edit?.imageUrl ?? '';
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
                _isEdit ? 'Dernek kutucuğunu düzenle' : 'Yeni dernek kutucuğu',
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
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _title,
                enabled: !busy,
                style: GoogleFonts.nunito(),
                decoration: _dec('Kutucuk adı (kutunun altında)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _websiteUrl,
                enabled: !busy,
                keyboardType: TextInputType.url,
                style: GoogleFonts.nunito(),
                decoration: _dec('Tıklanınca açılacak link (https://…)'),
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
              if (_isEdit) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy ? null : _delete,
                  child: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : L10nText(
                          'Kutucuğu sil',
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
