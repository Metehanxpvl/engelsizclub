import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../data/location_models.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import '../uzman_kosesi/kurum_is_ilan_models.dart';
import '../uzman_kosesi/kurum_is_ilan_store.dart';
import '../uzman_kosesi_profiles_store.dart';
import '../widgets/catalog_media.dart';
import '../widgets/location_picker.dart';

class UzmanKosesKurumIlanFormPage extends StatefulWidget {
  const UzmanKosesKurumIlanFormPage({
    super.key,
    required this.userEmail,
    this.existing,
  });

  final String userEmail;
  final KurumIsIlani? existing;

  static Future<bool> open(
    BuildContext context, {
    required String userEmail,
    KurumIsIlani? existing,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UzmanKosesKurumIlanFormPage(
          userEmail: userEmail,
          existing: existing,
        ),
      ),
    );
    return saved == true;
  }

  @override
  State<UzmanKosesKurumIlanFormPage> createState() =>
      _UzmanKosesKurumIlanFormPageState();
}

class _UzmanKosesKurumIlanFormPageState
    extends State<UzmanKosesKurumIlanFormPage> {
  final _kurum = TextEditingController();
  final _aciklama = TextEditingController();
  final _telefon = TextEditingController();
  final _adres = TextEditingController();
  LocationData _loc = const LocationData(countryCode: 'TR');
  String _meslek = '';
  String _photoUrl = '';
  List<String> _calisma = [];
  bool _kvkk = false;
  bool _saving = false;
  bool _picking = false;

  List<String> get _meslekler => uzmanKosesMeslekSecenekleri(extra: _meslek);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e == null) return;
    _kurum.text = e.kurumAdi;
    _aciklama.text = e.aciklama;
    _telefon.text = e.telefon;
    _adres.text = e.adres;
    _photoUrl = e.photoUrl;
    _meslek = e.arananMeslek;
    _calisma = List<String>.from(e.calismaSekli);
    _loc = LocationData(
      countryCode: 'TR',
      state: e.il,
      city: e.ilce,
    );
    _kvkk = true;
  }

  @override
  void dispose() {
    _kurum.dispose();
    _aciklama.dispose();
    _telefon.dispose();
    _adres.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_saving || _picking) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: MetoColors.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: L10nText(
                'Kurum görseli',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const L10nText('Fotoğraf çek'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const L10nText('Galeriden seç'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 86,
      );
      if (file == null) return;
      final raw = await file.readAsBytes();
      final opt = await ImageOptimizeService.forCatalogCard(raw);
      final url = await R2StorageService.uploadBytes(
        bytes: opt.bytes,
        fileName: 'kurum_ilan_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: opt.contentType,
      );
      if (!mounted) return;
      setState(() => _photoUrl = url);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Bad state: ', '').replaceFirst(
            'StateError: ',
            '',
          );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: MetoColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await saveKurumIsIlani(
        id: widget.existing?.id,
        kurumAdi: _kurum.text,
        arananMeslek: _meslek,
        il: _loc.state,
        ilce: _loc.city,
        aciklama: _aciklama.text,
        adres: _adres.text,
        photoUrl: _photoUrl,
        calismaSekli: _calisma,
        telefon: _telefon.text,
        kvkk: _kvkk,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is StateError ? e.message : 'İlan kaydedilemedi.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: L10nText(
          widget.existing == null ? 'Kurum iş ilanı' : 'İlanı düzenle',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const L10nText(
            'Klinik, merkez veya kurumunuzun aradığı uzmanı buradan yayınlayın.',
            style: TextStyle(color: MetoColors.mutedFg, height: 1.35),
          ),
          const SizedBox(height: 16),
          L10nText(
            'Kurum adı',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _kurum,
            textCapitalization: TextCapitalization.words,
            decoration: _dec('Örn. Yeşilova Fizik Tedavi Kliniği'),
          ),
          const SizedBox(height: 14),
          L10nText(
            'Aranan meslek',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _meslekler.contains(_meslek) ? _meslek : null,
            decoration: _dec('Meslek seçin'),
            items: [
              for (final m in _meslekler)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (v) => setState(() => _meslek = v ?? ''),
          ),
          const SizedBox(height: 14),
          L10nText(
            'İl / ilçe',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          LocationCascadePicker(
            value: _loc,
            onChanged: (v) => setState(() => _loc = v),
            requireFullSelection: false,
          ),
          const SizedBox(height: 14),
          L10nText(
            'Kurum adresi',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _adres,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: _dec('Cadde, no, mahalle…'),
          ),
          const SizedBox(height: 14),
          L10nText(
            'Kurum görseli',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (_photoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CatalogImage(
                  source: _photoUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _saving || _picking ? null : _pickPhoto,
            icon: _picking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined),
            label: L10nText(
              _photoUrl.isEmpty ? 'Kurum görseli ekle' : 'Görseli değiştir',
            ),
          ),
          const SizedBox(height: 14),
          L10nText(
            'Çalışma şekli (opsiyonel)',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in kKurumIsCalismaSekliSecenekleri)
                FilterChip(
                  label: Text(o),
                  selected: _calisma.contains(o),
                  onSelected: (on) {
                    setState(() {
                      if (on) {
                        _calisma = [..._calisma, o];
                      } else {
                        _calisma = [for (final e in _calisma) if (e != o) e];
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 14),
          L10nText(
            'İlan açıklaması',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _aciklama,
            minLines: 4,
            maxLines: 8,
            decoration: _dec(
              'Aranan nitelikler, çalışma saatleri, iletişim notu…',
            ),
          ),
          const SizedBox(height: 14),
          L10nText(
            'Telefon (opsiyonel)',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _telefon,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
            ],
            decoration: _dec('Örn. 05xx xxx xx xx'),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _kvkk,
            onChanged: (v) => setState(() => _kvkk = v ?? false),
            contentPadding: EdgeInsets.zero,
            title: const L10nText(
              kKurumIsKvkkOnayMetni,
              style: TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const L10nText('İlanı yayınla'),
          ),
        ],
      ),
    );
  }
}
