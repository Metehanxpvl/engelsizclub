import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../harita_foto_store.dart';
import '../harita_yer_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';

/// Üye: Engelsiz Haritalar’a yer bildirir.
class HaritaYerBildirSheet extends StatefulWidget {
  const HaritaYerBildirSheet({
    super.key,
    required this.email,
    required this.city,
    this.ilce = '',
    this.lat = 0,
    this.lng = 0,
    this.initialName = '',
    this.initialAddress = '',
    this.initialPhone = '',
    this.initialCategory,
    this.existing,
  });

  final String email;
  final String city;
  final String ilce;
  final double lat;
  final double lng;
  final String initialName;
  final String initialAddress;
  final String initialPhone;
  final String? initialCategory;
  final HaritaYerBildirim? existing;

  @override
  State<HaritaYerBildirSheet> createState() => _HaritaYerBildirSheetState();
}

class _HaritaYerBildirSheetState extends State<HaritaYerBildirSheet> {
  late final TextEditingController _note;
  final Set<String> _erisim = <String>{};
  final List<Uint8List> _photos = [];
  bool _saving = false;
  bool _picking = false;

  String get _placeLabel {
    final name = (widget.existing?.name ?? widget.initialName).trim();
    if (name.isNotEmpty && name != '—') return name;
    return 'Haritada işaretlenen yer';
  }

  String get _submitName {
    final name = (widget.existing?.name ?? widget.initialName).trim();
    if (name.length >= 3) return name;
    return '${widget.city} — haritada işaretlenen yer';
  }

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _erisim.addAll(haritaParseErisimTags(existing.note));
      _note = TextEditingController(text: haritaErisimNoteBody(existing.note));
    } else {
      _note = TextEditingController();
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: MetoColors.background,
        hintStyle: GoogleFonts.nunito(color: MetoColors.mutedFg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.border),
        ),
      );

  Future<void> _pickPhoto() async {
    if (_saving || _picking) return;
    if (_photos.length >= kHaritaFotoMaxPerPlace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En fazla 8 fotoğraf ekleyebilirsiniz.')),
      );
      return;
    }
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => _photos.add(bytes));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final staged = <HaritaStagedPhoto>[];
      for (final bytes in _photos) {
        staged.add(await stageHaritaPlacePhoto(bytes));
      }
      final keepFotos = widget.existing == null
          ? const <String>[]
          : haritaParseFotoUrls(widget.existing!.note);
      final note = haritaEncodeErisimNote(
        _erisim,
        _note.text,
        photoUrls: [...keepFotos, for (final s in staged) s.publicUrl],
      );
      final existing = widget.existing;
      final HaritaYerBildirResult result;
      if (existing != null) {
        result = await updateHaritaYerBildirimi(
          existing: existing,
          note: note,
        );
      } else {
        result = await submitHaritaYerBildirimi(
          email: widget.email,
          name: _submitName,
          category: kHaritaErisimKategori,
          city: widget.city,
          ilce: widget.ilce,
          address: widget.initialAddress,
          phone: widget.initialPhone.trim() == '—'
              ? ''
              : widget.initialPhone.trim(),
          note: note,
          lat: widget.lat,
          lng: widget.lng,
        );
      }
      final center = result.item.toCenter();
      for (final s in staged) {
        try {
          await confirmHaritaPlacePhoto(center: center, staged: s);
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        color: MetoColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MetoColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                L10nText(
                  _isEdit ? 'Yer bildirimini düzenle' : 'Yer bildir',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                L10nText(
                  'Bu mekân engelli bireyler için nasıl? Rampa, WC ve girişi işaretleyin.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 16),
                L10nText(
                  _placeLabel,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                L10nText(
                  'Erişilebilirlik',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final opt in kHaritaErisimSecenekleri)
                      FilterChip(
                        label: L10nText(opt),
                        selected: _erisim.contains(opt),
                        selectedColor: MetoColors.primary.withValues(alpha: 0.18),
                        checkmarkColor: MetoColors.primary,
                        onSelected: _saving
                            ? null
                            : (on) => setState(() {
                                  if (on) {
                                    _erisim.add(opt);
                                  } else {
                                    _erisim.remove(opt);
                                  }
                                }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                L10nText(
                  widget.city,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: MetoColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: (_saving || _picking) ? null : _pickPhoto,
                  icon: _picking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: L10nText(
                    _picking ? 'Seçiliyor…' : 'Fotoğraf ekle',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MetoColors.primary,
                    side: const BorderSide(color: MetoColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _photos[i],
                                width: 96,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: InkWell(
                                onTap: _saving
                                    ? null
                                    : () => setState(() => _photos.removeAt(i)),
                                child: const CircleAvatar(
                                  radius: 10,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.nunito(),
                  decoration: _dec('Not (isteğe bağlı)'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: MetoColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: L10nText(
                    _saving
                        ? 'Kaydediliyor…'
                        : (_isEdit ? 'Kaydet' : 'Bildir'),
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
