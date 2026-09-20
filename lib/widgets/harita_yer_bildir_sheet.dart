import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  });

  final String email;
  final String city;
  final String ilce;
  final double lat;
  final double lng;

  @override
  State<HaritaYerBildirSheet> createState() => _HaritaYerBildirSheetState();
}

class _HaritaYerBildirSheetState extends State<HaritaYerBildirSheet> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  String _category = kHaritaYerKategoriSecenekleri.first;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _address = TextEditingController();
    _phone = TextEditingController();
    _note = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await submitHaritaYerBildirimi(
        email: widget.email,
        name: _name.text,
        category: _category,
        city: widget.city,
        ilce: widget.ilce,
        address: _address.text,
        phone: _phone.text,
        note: _note.text,
        lat: widget.lat,
        lng: widget.lng,
      );
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
                  'Yer bildir',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                L10nText(
                  'Aile rolünde her 5 yer bildirimi = 1 iyilik puanı.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.nunito(),
                  decoration: _dec('Yer adı (ör. Güneş Özel Eğitim)'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cat in kHaritaYerKategoriSecenekleri)
                      ChoiceChip(
                        label: L10nText(cat),
                        selected: _category == cat,
                        selectedColor: MetoColors.primary.withValues(alpha: 0.18),
                        onSelected: _saving
                            ? null
                            : (_) => setState(() => _category = cat),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                L10nText(
                  widget.ilce.trim().isEmpty || widget.ilce == 'Tümü İlçeler'
                      ? widget.city
                      : '${widget.city} · ${widget.ilce}',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: MetoColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _address,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.nunito(),
                  decoration: _dec('Adres (isteğe bağlı)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.nunito(),
                  decoration: _dec('Telefon (isteğe bağlı)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.nunito(),
                  decoration: _dec('Not (rampa, asansör, otopark…)'),
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
                    _saving ? 'Kaydediliyor…' : 'Bildir',
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
