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

/// Üye etkinlik önerisi — pending; admin onayına kadar listede yok.
class EtkinlikOneriSheet extends StatefulWidget {
  const EtkinlikOneriSheet({
    super.key,
    this.presetCity,
  });

  final String? presetCity;

  @override
  State<EtkinlikOneriSheet> createState() => _EtkinlikOneriSheetState();
}

class _EtkinlikOneriSheetState extends State<EtkinlikOneriSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _venue;
  late final TextEditingController _citySearch;
  Uint8List? _pickedBytes;
  String? _city;
  DateTime? _date;
  TimeOfDay? _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _body = TextEditingController();
    _venue = TextEditingController();
    _citySearch = TextEditingController();
    final preset = widget.presetCity?.trim() ?? '';
    if (preset.isNotEmpty &&
        !isKampanyaNationwide(preset) &&
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
    _venue.dispose();
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

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 86,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _pickedBytes = bytes);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    setState(() => _time = picked);
  }

  String get _whenLabel {
    final d = _date;
    if (d == null) return '';
    return formatEtkinlikWhen(
      d,
      hour: _time?.hour,
      minute: _time?.minute,
    );
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Başlık girin.')),
      );
      return;
    }
    if (_city == null || _city!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('İl seçin.')),
      );
      return;
    }
    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Tarih seçin.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      var image = '';
      if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
        final optimized =
            await ImageOptimizeService.forCatalogCard(_pickedBytes!);
        image = await R2StorageService.uploadBytes(
          bytes: optimized.bytes,
          fileName: 'etkinlik_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: optimized.contentType,
        );
      }
      await proposeEtkinlik(
        title: _title.text,
        description: _body.text,
        city: _city!,
        eventDate: _whenLabel,
        avmName: _venue.text,
        imageUrl: image,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
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
                'Etkinlik öner',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 6),
              L10nText(
                'Öneriniz admin onayından sonra yayınlanır.',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 14),
              _fieldLabel('Başlık'),
              const SizedBox(height: 6),
              TextField(
                controller: _title,
                style: GoogleFonts.nunito(),
                textCapitalization: TextCapitalization.sentences,
                decoration: _dec('ör. Parkta aile pikniği'),
              ),
              const SizedBox(height: 12),
              _fieldLabel('Açıklama'),
              const SizedBox(height: 6),
              TextField(
                controller: _body,
                minLines: 3,
                maxLines: 6,
                style: GoogleFonts.nunito(),
                decoration: _dec('Kısa açıklama'),
              ),
              const SizedBox(height: 12),
              _fieldLabel('İl'),
              const SizedBox(height: 6),
              TextField(
                controller: _citySearch,
                onChanged: (v) => setState(() {
                  if (_city != null && foldTurkish(v) != foldTurkish(_city!)) {
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: L10nText(
                        _date == null
                            ? 'Tarih'
                            : '${_date!.day}.${_date!.month}.${_date!.year}',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MetoColors.primary,
                        side: const BorderSide(color: MetoColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickTime,
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: L10nText(
                        _time == null ? 'Saat (isteğe bağlı)' : _time!.format(context),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: MetoColors.primary,
                        side: const BorderSide(color: MetoColors.border),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _fieldLabel('AVM / mekân (isteğe bağlı)'),
              const SizedBox(height: 6),
              TextField(
                controller: _venue,
                style: GoogleFonts.nunito(),
                decoration: _dec('ör. Cepa AVM'),
              ),
              const SizedBox(height: 12),
              if (_pickedBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _pickedBytes!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const L10nText('Fotoğraf (isteğe bağlı)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MetoColors.primary,
                  side: const BorderSide(color: MetoColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                        'Onaya gönder',
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
