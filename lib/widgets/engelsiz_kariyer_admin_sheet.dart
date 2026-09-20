import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../engelsiz_kariyer_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';

class EngelsizKariyerAdminSheet extends StatefulWidget {
  const EngelsizKariyerAdminSheet({
    super.key,
    required this.adminEmail,
    this.edit,
  });

  final String adminEmail;
  final KariyerJob? edit;

  @override
  State<EngelsizKariyerAdminSheet> createState() =>
      _EngelsizKariyerAdminSheetState();
}

class _EngelsizKariyerAdminSheetState extends State<EngelsizKariyerAdminSheet> {
  late final TextEditingController _title;
  late final TextEditingController _city;
  late final TextEditingController _date;
  late final TextEditingController _url;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _city = TextEditingController(text: e?.city ?? '');
    _date = TextEditingController(text: e?.date ?? '');
    _url = TextEditingController(text: e?.applyUrl ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _city.dispose();
    _date.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Başlık girin.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final edit = widget.edit;
      final id = edit?.id ?? 'custom-${DateTime.now().millisecondsSinceEpoch}';
      await upsertKariyerOverride(
        adminEmail: widget.adminEmail,
        jobId: id,
        hidden: edit?.hidden ?? false,
        title: title,
        city: _city.text,
        date: _date.text,
        applyUrl: _url.text.trim().isEmpty ? kKariyerSourceUrl : _url.text,
        custom: edit?.custom ?? true,
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
                _isEdit ? 'İlanı düzenle' : 'İlan ekle',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 6),
              L10nText(
                'Değişiklik yalnızca override tablosuna yazılır. '
                'İŞKUR katalog JSON’u veritabanına kopyalanmaz.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                enabled: !_saving,
                style: GoogleFonts.nunito(),
                decoration: _dec('Başlık'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _city,
                enabled: !_saving,
                style: GoogleFonts.nunito(),
                decoration: _dec('İl / ilçe'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _date,
                enabled: !_saving,
                style: GoogleFonts.nunito(),
                decoration: _dec('Son başvuru (ör. 08.10.2026)'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _url,
                enabled: !_saving,
                style: GoogleFonts.nunito(),
                decoration: _dec('Başvuru URL'),
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
