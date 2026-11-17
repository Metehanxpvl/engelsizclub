import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/location_models.dart';
import '../kullanici_profil_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../uzman_kosesi_profiles_store.dart';
import '../widgets/location_picker.dart';

class UzmanKosesProfilFormPage extends StatefulWidget {
  const UzmanKosesProfilFormPage({
    super.key,
    this.existing,
    required this.userEmail,
  });

  final UzmanKosesProfil? existing;
  final String userEmail;

  static Future<bool> open(
    BuildContext context, {
    UzmanKosesProfil? existing,
    required String userEmail,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UzmanKosesProfilFormPage(
          existing: existing,
          userEmail: userEmail,
        ),
      ),
    );
    return saved == true;
  }

  @override
  State<UzmanKosesProfilFormPage> createState() =>
      _UzmanKosesProfilFormPageState();
}

class _UzmanKosesProfilFormPageState extends State<UzmanKosesProfilFormPage> {
  late final TextEditingController _ad;
  String? _meslek;
  LocationData _loc = const LocationData(countryCode: 'TR');
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _ad = TextEditingController(text: ex?.fullName ?? '');
    _meslek = (ex?.meslek.trim().isNotEmpty == true) ? ex!.meslek : null;
    if (ex != null) {
      _loc = LocationData.fromLegacy(
        city: ex.il,
        district: ex.ilce,
        countryCode: ex.countryCode.isEmpty ? 'TR' : ex.countryCode,
      );
    }
    _prefill();
  }

  Future<void> _prefill() async {
    if (widget.existing != null) return;
    String name = _ad.text.trim();
    try {
      final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
      final fromAuth = (meta?['name'] ?? meta?['full_name'])?.toString().trim();
      if (name.isEmpty && fromAuth != null && fromAuth.isNotEmpty) {
        name = fromAuth;
      }
    } catch (_) {}
    try {
      final p = await loadKullaniciProfil(widget.userEmail);
      if (!mounted) return;
      setState(() {
        if (_ad.text.trim().isEmpty && p.adSoyad.trim().isNotEmpty) {
          _ad.text = p.adSoyad.trim();
        } else if (_ad.text.trim().isEmpty && name.isNotEmpty) {
          _ad.text = name;
        }
        if ((_meslek == null || _meslek!.isEmpty) && p.meslek.trim().isNotEmpty) {
          _meslek = p.meslek.trim();
        }
        if (_loc.state.isEmpty && (p.sehir.isNotEmpty || p.ilce.isNotEmpty)) {
          _loc = p.location;
        }
      });
    } catch (_) {
      if (!mounted) return;
      if (_ad.text.trim().isEmpty && name.isNotEmpty) {
        setState(() => _ad.text = name);
      }
    }
  }

  @override
  void dispose() {
    _ad.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ad.text.trim();
    final job = (_meslek ?? '').trim();
    if (name.isEmpty) {
      _snack('Ad soyad yazın.');
      return;
    }
    if (job.isEmpty) {
      _snack('Meslek seçin.');
      return;
    }
    if (_loc.state.trim().isEmpty) {
      _snack('İl seçin.');
      return;
    }
    if (_loc.city.trim().isEmpty) {
      _snack('İlçe seçin.');
      return;
    }
    setState(() => _saving = true);
    try {
      await upsertUzmanKosesProfil(
        fullName: name,
        meslek: job,
        il: _loc.state,
        ilce: _loc.city,
        countryCode: _loc.countryCode.isEmpty ? 'TR' : _loc.countryCode,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString().replaceFirst('Bad state: ', '').replaceFirst('StateError: ', ''));
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final meslekler = uzmanKosesMeslekSecenekleri(extra: _meslek ?? '');
    final meslekValue =
        (_meslek != null && meslekler.contains(_meslek)) ? _meslek : null;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: L10nText(
          widget.existing == null ? 'Profilini oluştur' : 'Profilimi düzenle',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const L10nText(
            'Kartında meslek, adın ve il / ilçe görünür.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 18),
          const L10nText(
            'AD SOYAD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ad,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'Ad Soyad',
              filled: true,
              fillColor: MetoColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const L10nText(
            'MESLEK',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey('meslek|$meslekValue'),
            initialValue: meslekValue,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: 'Meslek seçin',
              filled: true,
              fillColor: MetoColors.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              for (final m in meslekler)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: _saving
                ? null
                : (v) {
                    if (v != null) setState(() => _meslek = v);
                  },
          ),
          const SizedBox(height: 16),
          const L10nText(
            'İL / İLÇE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          const SizedBox(height: 8),
          LocationCascadePicker(
            value: _loc,
            onChanged: (v) => setState(() => _loc = v),
            requireFullSelection: true,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              backgroundColor: MetoColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
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
                    widget.existing == null ? 'Profili oluştur' : 'Kaydet',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}
