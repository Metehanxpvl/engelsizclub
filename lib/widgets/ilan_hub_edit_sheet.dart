import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../catalog_category_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../services/catalog_adapters.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import 'catalog_media.dart';

Future<bool> showIlanHubEditSheet({
  required BuildContext context,
  required String hubId,
  required String fallbackTitle,
  Map<String, dynamic>? meta,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MetoColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _IlanHubEditSheet(
      hubId: hubId,
      fallbackTitle: fallbackTitle,
      meta: meta,
    ),
  );
  return saved == true;
}

class _IlanHubEditSheet extends StatefulWidget {
  const _IlanHubEditSheet({
    required this.hubId,
    required this.fallbackTitle,
    this.meta,
  });

  final String hubId;
  final String fallbackTitle;
  final Map<String, dynamic>? meta;

  @override
  State<_IlanHubEditSheet> createState() => _IlanHubEditSheetState();
}

class _IlanHubEditSheetState extends State<_IlanHubEditSheet> {
  late final TextEditingController _name;
  late String _imageUrl;
  Uint8List? _pickedBytes;
  bool _cleared = false;
  bool _saving = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    final style = CatalogAdapters.ilanHubStyle(
      widget.hubId,
      widget.fallbackTitle,
    );
    _name = TextEditingController(text: style.title);
    _imageUrl = style.imageUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_picking || _saving) return;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      final raw = await file.readAsBytes();
      final opt = await ImageOptimizeService.forListing(raw);
      if (!mounted) return;
      setState(() {
        _pickedBytes = opt.bytes;
        _cleared = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _hide() async {
    if (_saving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Kutucuğu kaldır'),
        content: L10nText(
          '"${_name.text.trim().isEmpty ? widget.fallbackTitle : _name.text.trim()}" '
          'ilanlar ana sayfasından kaldırılsın mı?\n\n'
          'Mevcut ilanlar silinmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const L10nText('Kaldır'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      final result = await hideIlanHubCard(
        id: widget.hubId,
        fallbackTitle: widget.fallbackTitle,
        meta: widget.meta,
      );
      if (!mounted) return;
      showCatalogUpsertSnackBar(
        context,
        result,
        successText: 'Kutucuk kaldırıldı',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _name.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Kart adı gerekli.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var icon = _cleared ? '' : _imageUrl;
      if (_pickedBytes != null && !_cleared) {
        final opt = await ImageOptimizeService.forListing(_pickedBytes!);
        icon = await R2StorageService.uploadBytes(
          bytes: opt.bytes,
          fileName: 'hub-${widget.hubId}-${opt.fileName}',
          contentType: opt.contentType,
        );
      }
      final result = await upsertCatalogHubCard(
        id: widget.hubId,
        label: title,
        icon: icon,
        meta: ilanHubWriteMeta(widget.hubId, widget.meta),
      );
      if (!mounted) return;
      showCatalogUpsertSnackBar(
        context,
        result,
        successText: 'Kart güncellendi',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('r2-upload') ||
                    e.toString().contains('function')
                ? 'Görsel yüklenemedi. Daha sonra tekrar deneyin.'
                : e.toString().replaceFirst('Bad state: ', ''),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final previewBytes = _cleared ? null : _pickedBytes;
    final previewUrl = _cleared || _pickedBytes != null ? '' : _imageUrl;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: L10nText(
                  'Kartı düzenle',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: double.infinity,
              height: 180,
              child: ColoredBox(
                color: MetoColors.selectedBg,
                child: previewBytes != null
                    ? Image.memory(
                        previewBytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : previewUrl.isNotEmpty
                        ? CatalogImage(
                            source: previewUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 40,
                              color: MetoColors.mutedFg,
                            ),
                          ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving || _picking ? null : _pickImage,
                  icon: _picking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_library_outlined, size: 18),
                  label: const L10nText('Görsel seç'),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _cleared = true;
                          _pickedBytes = null;
                        }),
                child: const L10nText('Kaldır'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const L10nText(
            'Kart adı',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            maxLength: 48,
            textCapitalization: TextCapitalization.sentences,
            enabled: !_saving,
            decoration: InputDecoration(
              hintText: widget.fallbackTitle,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: MetoColors.background,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _saving ? null : _hide,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const L10nText('Kutucuğu kaldır'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const L10nText(
                      'Kaydet',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
