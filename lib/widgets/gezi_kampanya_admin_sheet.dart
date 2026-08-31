import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../data/turkish_cities_data.dart';
import '../gezi_kampanya_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import 'photo_gallery_lightbox.dart';

enum GeziKampanyaKind { gezi, kampanya }

/// Admin: görsel (galeri / URL) + başlık / açıklama; gezi için il seçimi.
class GeziKampanyaAdminSheet extends StatefulWidget {
  const GeziKampanyaAdminSheet({
    super.key,
    required this.adminEmail,
    required this.kind,
    this.presetCity,
    this.editGezi,
  });

  final String adminEmail;
  final GeziKampanyaKind kind;
  final String? presetCity;
  final GeziItem? editGezi;

  @override
  State<GeziKampanyaAdminSheet> createState() => _GeziKampanyaAdminSheetState();
}

class _GeziKampanyaAdminSheetState extends State<GeziKampanyaAdminSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _imageUrl;
  late final TextEditingController _citySearch;
  Uint8List? _pickedBytes;
  String? _city;
  bool _saving = false;

  bool get _isGezi => widget.kind == GeziKampanyaKind.gezi;
  bool get _isEdit => widget.editGezi != null;
  bool get _lockCity {
    if (_isEdit) return true;
    final preset = widget.presetCity?.trim() ?? '';
    return preset.isNotEmpty && _city != null;
  }

  @override
  void initState() {
    super.initState();
    final edit = widget.editGezi;
    _title = TextEditingController(text: edit?.title ?? '');
    _body = TextEditingController(text: edit?.description ?? '');
    _imageUrl = TextEditingController();
    _citySearch = TextEditingController();
    final preset = (edit?.cityName ?? widget.presetCity)?.trim();
    if (preset != null &&
        preset.isNotEmpty &&
        kCityNames.any((c) => foldTurkish(c) == foldTurkish(preset))) {
      _city = kCityNames.firstWhere(
        (c) => foldTurkish(c) == foldTurkish(preset),
      );
      _citySearch.text = _city!;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _imageUrl.dispose();
    _citySearch.dispose();
    super.dispose();
  }

  List<String> get _cityOptions {
    final q = foldTurkish(_citySearch.text);
    final list = q.isEmpty
        ? List<String>.from(kCityNames)
        : kCityNames.where((c) => foldTurkish(c).contains(q)).toList();
    list.sort((a, b) => foldTurkish(a).compareTo(foldTurkish(b)));
    return list;
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
      final optimized = await ImageOptimizeService.forCatalogCard(_pickedBytes!);
      final prefix = _isGezi ? 'gezi' : 'kampanya';
      return R2StorageService.uploadBytes(
        bytes: optimized.bytes,
        fileName: '${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: optimized.contentType,
      );
    }
    return _imageUrl.text.trim();
  }

  Future<void> _save() async {
    if (_isGezi && (_city == null || _city!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('İl seçin (ör. Ankara).')),
      );
      return;
    }
    if (_isGezi && _title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Başlık girin (ör. Anıtkabir).')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final image = await _resolveImage();
      final keepExisting = _isEdit && image.isEmpty;
      if (image.isEmpty && !keepExisting) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: L10nText('Görsel yükleyin veya URL girin.')),
        );
        return;
      }
      if (_isGezi) {
        final edit = widget.editGezi;
        if (edit != null) {
          await updateGeziItem(
            id: edit.id,
            title: _title.text,
            description: _body.text,
            imageUrl: image.isEmpty ? null : image,
            adminEmail: widget.adminEmail,
          );
        } else {
          await addGeziItem(
            cityName: _city!,
            title: _title.text,
            imageUrl: image,
            description: _body.text,
            adminEmail: widget.adminEmail,
          );
        }
      } else {
        await addKampanyaItem(
          title: _title.text,
          imageUrl: image,
          description: _body.text,
          adminEmail: widget.adminEmail,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final raw = e.toString();
      final hint = raw.contains('gezi_rehberi_title.sql')
          ? 'Başlık kolonu yok. Supabase’de gezi_rehberi_title.sql çalıştırın.'
          : raw.contains('gezi_rehberi') ||
                  raw.contains('kampanyalar') ||
                  raw.contains('PGRST') ||
                  raw.contains('schema')
              ? 'Tablo yok. Supabase’de gezi_kampanya.sql çalıştırın.'
              : 'Kaydedilemedi: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hint)));
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

  Widget _fieldLabel(String text) {
    return L10nText(
      text,
      style: GoogleFonts.nunito(
        fontWeight: FontWeight.w700,
        color: MetoColors.mutedFg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
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
                _isGezi
                    ? (_isEdit ? 'Yeri düzenle' : 'Yer ekle')
                    : 'Kampanya ekle',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 14),
              if (_isGezi) ...[
                _fieldLabel('İl'),
                const SizedBox(height: 6),
                if (_lockCity)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: L10nText(
                      _city ?? widget.editGezi?.cityName ?? '',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        color: MetoColors.primary,
                      ),
                    ),
                  )
                else ...[
                  TextField(
                    controller: _citySearch,
                    onChanged: (v) => setState(() {
                      if (_city != null &&
                          foldTurkish(v) != foldTurkish(_city!)) {
                        _city = null;
                      }
                    }),
                    style: GoogleFonts.nunito(),
                    decoration: _dec('İl ara (Ankara, İzmir…)'),
                  ),
                  if (_city == null) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          for (final city in _cityOptions.take(81))
                            ListTile(
                              dense: true,
                              selected: _city == city,
                              selectedTileColor:
                                  MetoColors.primary.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              title: Text(
                                city,
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              onTap: () => setState(() {
                                _city = city;
                                _citySearch.text = city;
                              }),
                            ),
                        ],
                      ),
                    ),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: L10nText(
                        'Seçili: $_city',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          color: MetoColors.primary,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 6),
              ] else ...[
                TextField(
                  controller: _title,
                  style: GoogleFonts.nunito(),
                  decoration: _dec('Başlık (isteğe bağlı)'),
                ),
                const SizedBox(height: 12),
              ],
              if (_pickedBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pickedBytes!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (_isEdit &&
                  (widget.editGezi?.imageUrl.trim().isNotEmpty ?? false) &&
                  _imageUrl.text.trim().isEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: FillPhoto(
                      source: widget.editGezi!.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
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
                style: GoogleFonts.nunito(),
                decoration: _dec('veya görsel URL (https://…)'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (_isGezi) ...[
                _fieldLabel('Başlık'),
                const SizedBox(height: 6),
                TextField(
                  controller: _title,
                  style: GoogleFonts.nunito(),
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  decoration: _dec('ör. Anıtkabir'),
                ),
                const SizedBox(height: 12),
                _fieldLabel('Açıklama'),
                const SizedBox(height: 6),
              ],
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 6,
                style: GoogleFonts.nunito(),
                decoration: _dec(
                  _isGezi
                      ? 'İsteğe bağlı'
                      : 'Açıklama (isteğe bağlı)',
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
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
            ],
          ),
        ),
      ),
    );
  }
}
