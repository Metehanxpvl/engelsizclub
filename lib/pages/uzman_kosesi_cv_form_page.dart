import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../admin_config.dart';
import '../data/location_models.dart';
import '../kullanici_profil_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import '../uzman_kosesi/expert_cv_models.dart';
import '../uzman_kosesi/expert_cv_store.dart';
import '../profil_foto_store.dart';
import '../widgets/catalog_media.dart';
import '../widgets/location_picker.dart';

class UzmanKosesCvFormPage extends StatefulWidget {
  const UzmanKosesCvFormPage({
    super.key,
    required this.userEmail,
  });

  final String userEmail;

  static Future<bool> open(
    BuildContext context, {
    required String userEmail,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UzmanKosesCvFormPage(userEmail: userEmail),
      ),
    );
    return saved == true;
  }

  @override
  State<UzmanKosesCvFormPage> createState() => _UzmanKosesCvFormPageState();
}

class _UzmanKosesCvFormPageState extends State<UzmanKosesCvFormPage> {
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  List<MeslekGrubu> _gruplar = const [];
  List<MeslekAlanSablon> _sablonlar = const [];
  final _ad = TextEditingController();
  final _tanitim = TextEditingController();
  final _engelliAciklama = TextEditingController();
  final _referans = TextEditingController();
  final _deneyim = TextEditingController();
  final _universite = TextEditingController();
  final _mezuniyetYili = TextEditingController();
  final _belgeler = TextEditingController();
  final _makaleAciklama = TextEditingController();
  final _uzmanlikIlgi = TextEditingController();
  final _telefon = TextEditingController();
  final _isYeriAdres = TextEditingController();
  final _mezunBolum = TextEditingController();
  LocationData _loc = const LocationData(countryCode: 'TR');
  int? _grupId;
  List<String> _calisma = [];
  List<String> _musait = [];
  List<String> _diller = [];
  bool _isaretDili = false;
  bool? _makaleVar;
  bool? _engelliDeneyim;
  bool _iletisimMesaj = true;
  bool _iletisimTelefon = false;
  bool _iletisimEposta = false;
  bool _kvkk = false;
  int _kartSpan = 1;
  String _photoUrl = '';
  Map<String, dynamic> _detay = {};
  Map<String, String> _files = {};
  final Map<String, TextEditingController> _textCtrls = {};
  ExpertCvProfile? _existing;

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  bool get _bakimFormu {
    for (final g in _gruplar) {
      if (g.id == _grupId) return g.isBakim;
    }
    return false;
  }

  bool get _bakiciFormu {
    for (final g in _gruplar) {
      if (g.id == _grupId) return g.key == 'bakici';
    }
    return false;
  }

  List<String> get _stepTitles =>
      uzmanCvFormAdimBasliklari(bakim: _bakimFormu);

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final gruplar = await loadMeslekGruplari();
    final mine = await loadMyExpertProfile();
    Map<String, String> files = {};
    List<MeslekAlanSablon> sablon = const [];
    if (mine != null) {
      if (mine.meslekGrubuId != null) {
        sablon = await loadMeslekAlanSablonlari(meslekGrubuId: mine.meslekGrubuId);
      }
      files = await loadExpertFiles(mine.id);
    }
    if (mine != null) {
      final g = gruplar.where((e) => e.id == mine.meslekGrubuId).toList();
      if (g.isNotEmpty) {
        sablon = uzmanMeslekSablonlariVeyaBakimVarsayilan(
          sablonlar: sablon,
          bakim: g.first.isBakim,
          grupKey: g.first.key,
          meslekGrubuId: g.first.id,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _gruplar = gruplar;
      _existing = mine;
      if (mine != null) {
        _ad.text = mine.fullName;
        _tanitim.text = mine.kisaTanitim;
        _engelliAciklama.text = mine.engelliDeneyimAciklama;
        _referans.text = mine.referanslar;
        _deneyim.text = mine.deneyimYili?.toString() ?? '';
        _grupId = mine.meslekGrubuId;
        _loc = LocationData.fromLegacy(
          city: mine.il,
          district: mine.ilce,
          countryCode: mine.countryCode,
        );
        _calisma = List.of(mine.calismaSekli);
        _musait = List.of(mine.musaitlik);
        _diller = List.of(mine.diller);
        _isaretDili = mine.isaretDili;
        _engelliDeneyim = mine.engelliDeneyimi;
        _iletisimMesaj = mine.iletisimMesaj;
        _iletisimTelefon = mine.iletisimTelefon;
        _iletisimEposta = mine.iletisimEposta;
        if (!_iletisimMesaj && !_iletisimTelefon && !_iletisimEposta) {
          _iletisimMesaj = true;
        }
        _kvkk = mine.kvkkOnay;
        _kartSpan = mine.kartSpan >= 2 ? 2 : 1;
        _photoUrl = mine.photoUrl;
        _detay = Map<String, dynamic>.from(mine.meslekDetaylari);
        _universite.text = _detay['universite']?.toString() ?? '';
        _mezuniyetYili.text = _detay['mezuniyet_yili']?.toString() ?? '';
        _belgeler.text = _detay['belgeler']?.toString() ?? '';
        _makaleAciklama.text = _detay['makale_aciklama']?.toString() ?? '';
        _uzmanlikIlgi.text = _detay['uzmanlik_ilgi']?.toString() ?? '';
        _telefon.text = _detay['cep_telefonu']?.toString() ?? '';
        _isYeriAdres.text = _detay[kUzmanIsYeriAdresKey]?.toString() ??
            _detay['isyeri_adresi']?.toString() ??
            '';
        _mezunBolum.text = _detay[kUzmanMezunBolumKey]?.toString() ??
            _detay['mezun_oldugu_bolum']?.toString() ??
            '';
        final mv = _detay['makale_var'];
        _makaleVar = mv is bool ? mv : null;
      }
      _sablonlar = sablon;
      _files = files;
      _bindTextCtrls(sablon);
      _loading = false;
    });
    if (mine == null) await _prefill();
  }

  Future<void> _prefill() async {
    try {
      final p = await loadKullaniciProfil(widget.userEmail);
      if (!mounted) return;
      setState(() {
        if (_ad.text.isEmpty && p.adSoyad.trim().isNotEmpty) {
          _ad.text = p.adSoyad.trim();
        }
        if (_loc.state.isEmpty && p.sehir.isNotEmpty) _loc = p.location;
        if (_deneyim.text.isEmpty && p.deneyimYili.isNotEmpty) {
          _deneyim.text = p.deneyimYili;
        }
        if (_universite.text.isEmpty && p.egitim.trim().isNotEmpty) {
          _universite.text = p.egitim.trim();
        }
        if (_uzmanlikIlgi.text.isEmpty && p.uzmanliklar.trim().isNotEmpty) {
          _uzmanlikIlgi.text = p.uzmanliklar.trim();
        }
        if (_telefon.text.isEmpty && p.telefon.trim().isNotEmpty) {
          _telefon.text = p.telefon.trim();
        }
      });
      if (_photoUrl.isEmpty) {
        final existingFoto = await loadProfilFoto(widget.userEmail);
        final url = sanitizeProfilFotoUrl(existingFoto);
        if (url != null && mounted) setState(() => _photoUrl = url);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _ad.dispose();
    _tanitim.dispose();
    _engelliAciklama.dispose();
    _referans.dispose();
    _deneyim.dispose();
    _universite.dispose();
    _mezuniyetYili.dispose();
    _belgeler.dispose();
    _makaleAciklama.dispose();
    _uzmanlikIlgi.dispose();
    _telefon.dispose();
    _isYeriAdres.dispose();
    _mezunBolum.dispose();
    for (final c in _textCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  ExpertCvProfile _draft() {
    for (final e in _textCtrls.entries) {
      _detay[e.key] = e.value.text;
    }
    _detay['belgeler'] = _belgeler.text.trim();
    _detay['cep_telefonu'] = _telefon.text.trim();
    _detay[kUzmanIsYeriAdresKey] = _isYeriAdres.text.trim();
    if (_bakiciFormu) {
      _detay[kUzmanMezunBolumKey] = _mezunBolum.text.trim();
    }
    if (_bakimFormu) {
      _detay = uzmanDetayMeslekTemizle(_detay, bakim: true);
    } else {
      _detay['universite'] = _universite.text.trim();
      _detay['mezuniyet_yili'] = _mezuniyetYili.text.trim();
      _detay['makale_var'] = _makaleVar;
      _detay['makale_aciklama'] = _makaleAciklama.text.trim();
      _detay['uzmanlik_ilgi'] = _uzmanlikIlgi.text.trim();
      _detay = uzmanDetayMeslekTemizle(_detay, bakim: false);
    }
    return ExpertCvProfile(
        id: _existing?.id ?? 0,
        fullName: _ad.text,
        photoUrl: _photoUrl,
        meslekGrubuId: _grupId,
        il: _loc.state,
        ilce: _loc.city,
        countryCode: _loc.countryCode,
        deneyimYili: int.tryParse(_deneyim.text.trim()),
        kisaTanitim: _tanitim.text,
        calismaSekli: _calisma,
        musaitlik: _musait,
        diller: _diller,
        isaretDili: _isaretDili,
        engelliDeneyimi: _engelliDeneyim,
        engelliDeneyimAciklama: _engelliAciklama.text,
        referanslar: _referans.text,
        iletisimTercihi: _iletisimMesaj
            ? 'app_message'
            : (_iletisimTelefon ? 'phone' : 'email'),
        telefonIzin: _iletisimTelefon,
        epostaIzin: _iletisimEposta,
        meslekDetaylari: _detay,
        kvkkOnay: _kvkk,
        status: _existing?.status ?? 'draft',
        kartSpan: _kartSpan,
        ucretBitis: _existing?.ucretBitis,
        ilkAyKullanildi: _existing?.ilkAyKullanildi ?? false,
        odenenPuan: _existing?.odenenPuan ?? 0,
        publishedAt: _existing?.publishedAt,
        createdAt: _existing?.createdAt,
      );
  }

  Future<void> _onGrup(int id) async {
    final g = _gruplar.where((e) => e.id == id).toList();
    final bakim = g.isNotEmpty && g.first.isBakim;
    final calismaOpts = uzmanCalismaSekliSecenekleri(bakim: bakim);
    setState(() {
      _grupId = id;
      _sablonlar = const [];
      _calisma = [
        for (final s in _calisma)
          if (calismaOpts.contains(s)) s,
      ];
    });
    var s = await loadMeslekAlanSablonlari(meslekGrubuId: id);
    s = uzmanMeslekSablonlariVeyaBakimVarsayilan(
      sablonlar: s,
      bakim: bakim,
      grupKey: g.isEmpty ? '' : g.first.key,
      meslekGrubuId: id,
    );
    if (!mounted) return;
    setState(() {
      _sablonlar = s;
      _bindTextCtrls(s);
    });
  }

  void _bindTextCtrls(List<MeslekAlanSablon> sablon) {
    for (final s in sablon) {
      if (s.tip != 'text' && s.tip != 'textarea' && s.tip != 'number') continue;
      final initial = _detay[s.alanKey]?.toString() ?? '';
      final existing = _textCtrls[s.alanKey];
      if (existing == null) {
        _textCtrls[s.alanKey] = TextEditingController(text: initial);
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 86,
      );
      if (file == null) return;
      final raw = await file.readAsBytes();
      final opt = await ImageOptimizeService.forListing(raw);
      final url = await R2StorageService.uploadBytes(
        bytes: opt.bytes,
        fileName: 'expert_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: opt.contentType,
      );
      if (!mounted) return;
      setState(() => _photoUrl = url);
    } catch (e) {
      if (!mounted) return;
      _snack(
        e.toString().replaceFirst('Bad state: ', '').replaceFirst('StateError: ', ''),
      );
    }
  }

  Widget _photoPicker() {
    return Column(
      children: [
        InkWell(
          onTap: _saving ? null : _pickPhoto,
          borderRadius: BorderRadius.circular(64),
          child: CircleAvatar(
            radius: 52,
            backgroundColor: MetoColors.primary.withValues(alpha: 0.12),
            child: _photoUrl.isEmpty
                ? const Icon(Icons.add_a_photo_outlined, size: 36, color: MetoColors.primary)
                : ClipOval(
                    child: CatalogImage(
                      source: _photoUrl,
                      width: 104,
                      height: 104,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving ? null : _pickPhoto,
          child: L10nText(
            _photoUrl.isEmpty ? 'Profil fotoğrafı ekle' : 'Fotoğrafı değiştir',
          ),
        ),
      ],
    );
  }

  Future<ImageSource?> _chooseBelgeKaynagi() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: MetoColors.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: L10nText(
                _bakimFormu
                    ? 'Belgenin net bir fotoğrafı yeterlidir'
                    : 'Diplomanın net bir fotoğrafı yeterlidir',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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
  }

  Future<void> _pickFile(String alanKey) async {
    try {
      final source = await _chooseBelgeKaynagi();
      if (source == null || !mounted) return;
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 88,
      );
      if (file == null) return;
      final raw = await file.readAsBytes();
      final opt = await ImageOptimizeService.forListing(raw);
      final url = await R2StorageService.uploadBytes(
        bytes: opt.bytes,
        fileName: 'expert_${alanKey}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: opt.contentType,
      );
      if (!mounted) return;
      setState(() {
        _files = {..._files, alanKey: url};
        _detay = {..._detay, alanKey: 'yuklendi'};
      });
    } catch (e) {
      if (!mounted) return;
      _snack(
        e.toString().replaceFirst('Bad state: ', '').replaceFirst('StateError: ', ''),
      );
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _deleteMine() async {
    if (_existing == null || _saving) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText(kUzmanIlanSil),
        content: const L10nText(kUzmanIlanSilOnay),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            child: const L10nText(kUzmanIlanSil),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await deleteMyExpertProfile();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(
        e.toString().replaceFirst('Bad state: ', '').replaceFirst('StateError: ', ''),
      );
    }
  }

  Future<void> _save({required bool publish}) async {
    final d = _draft();
    final errs = validateExpertCv(
      draft: d,
      sablonlar: _sablonlar,
      fileUrls: _files,
      forPublish: publish,
    );
    if (errs.isNotEmpty) {
      _snack('Eksik: ${errs.join(', ')}');
      return;
    }
    if (publish) {
      final ucretsiz =
          uzmanKartYayinUcreti(existing: _existing, span: _kartSpan) == 0;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const L10nText('Yayın ücreti'),
          content: L10nText(
            uzmanKartUcretAciklamasi(span: _kartSpan, ucretsiz: ucretsiz),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const L10nText('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const L10nText('Yayınla'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _saving = true);
    try {
      await saveExpertProfile(draft: d, fileUrls: _files, publish: publish);
      if (!mounted) return;
      if (publish) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const L10nText('Bilgilendirme'),
            content: const L10nText(kUzmanYayinOnayBilgi),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const L10nText('Tamam'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString().replaceFirst('Bad state: ', '').replaceFirst('StateError: ', ''));
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
          _stepTitles[_step],
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_existing != null)
            TextButton(
              onPressed: _saving ? null : _deleteMine,
              child: const L10nText(
                kUzmanIlanSil,
                style: TextStyle(color: Color(0xFFB42318)),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                LinearProgressIndicator(
                  value: (_step + 1) / _stepTitles.length,
                  minHeight: 3,
                  color: MetoColors.primary,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _ucretUstBilgi(),
                      const SizedBox(height: 12),
                      if (_step == 0) _stepMeslek(),
                      if (_step == 1) _stepOrtak(),
                      if (_step == 2) _stepMeslekOzel(),
                      if (_step == 3) _stepDosya(),
                      if (_step == 4) _stepOzet(),
                    ],
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _step--),
                            child: const L10nText('Geri'),
                          ),
                        const Spacer(),
                        if (_step < 4)
                          FilledButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    if (_step == 0 && _grupId == null) {
                                      _snack('Meslek grubu seçin.');
                                      return;
                                    }
                                    setState(() => _step++);
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: MetoColors.primary,
                            ),
                            child: const L10nText('İleri'),
                          )
                        else ...[
                          OutlinedButton(
                            onPressed: _saving
                                ? null
                                : () => _save(publish: false),
                            child: const L10nText('Taslak kaydet'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: _saving ? null : () => _save(publish: true),
                            style: FilledButton.styleFrom(
                              backgroundColor: MetoColors.primary,
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
                                : const L10nText('Yayınla'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _stepMeslek() {
    final saglik = _gruplar.where((g) => g.ustGrup == 'Sağlık Uzmanları');
    final bakim = _gruplar.where(
      (g) => g.ustGrup == 'Bakım ve Ev Desteği' && g.key != 'ev_yardimi',
    );
    final ev = _gruplar.where((g) => g.key == 'ev_yardimi');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_gruplar.isEmpty)
          const L10nText(
            'Meslek listesi yüklenemedi. supabase/expert_cv.sql ve expert_cv_seed.sql dosyalarını çalıştırın.',
          ),
        _groupHeader('Sağlık Uzmanları'),
        for (final g in saglik) _grupTile(g),
        if (_isAdmin)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _saving ? null : _addSaglikMeslekGrubu,
              icon: const Icon(Icons.add_circle_outline),
              label: const L10nText('Meslek grubu ekle'),
            ),
          ),
        const SizedBox(height: 12),
        _groupHeader('Bakım Desteği'),
        for (final g in bakim) _grupTile(g),
        const SizedBox(height: 12),
        _groupHeader('Ev Desteği'),
        for (final g in ev) _grupTile(g),
      ],
    );
  }

  Future<void> _addSaglikMeslekGrubu() async {
    if (!_isAdmin) return;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Meslek grubu ekle'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Meslek adı',
            hintText: 'Örn. Diyetisyen',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const L10nText('Ekle'),
          ),
        ],
      ),
    );
    final name = c.text.trim();
    c.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      final created = await insertMeslekGrubu(
        etiket: name,
        ustGrup: kMeslekUstSaglik,
        sira: nextMeslekGrubuSira(_gruplar, kMeslekUstSaglik),
      );
      if (!mounted) return;
      setState(() {
        _gruplar = [..._gruplar, created]
          ..sort((a, b) => a.sira.compareTo(b.sira));
      });
      await _onGrup(created.id);
      if (!mounted) return;
      _snack('$name eklendi. Bu meslek seçildi.');
    } catch (e) {
      if (!mounted) return;
      _snack(
        e.toString().replaceFirst('Bad state: ', '').replaceFirst('StateError: ', ''),
      );
    }
  }

  Widget _groupHeader(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: L10nText(
          t,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: MetoColors.mutedFg,
          ),
        ),
      );

  Widget _grupTile(MeslekGrubu g) {
    final on = _grupId == g.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: on ? MetoColors.selectedBg : MetoColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _onGrup(g.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: on ? MetoColors.primary : MetoColors.border,
                width: on ? 2 : 1,
              ),
            ),
            child: Text(
              g.etiket,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepOrtak() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _photoPicker()),
        const SizedBox(height: 16),
        _label('Ad soyad'),
        TextField(controller: _ad, textCapitalization: TextCapitalization.words, decoration: _dec('Ad Soyad')),
        const SizedBox(height: 14),
        _label('Cep telefonu (opsiyonel)'),
        TextField(
          controller: _telefon,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
          ],
          decoration: _dec('Örn. 05xx xxx xx xx'),
        ),
        const SizedBox(height: 14),
        _label('Hizmet verilen il / ilçe'),
        LocationCascadePicker(
          value: _loc,
          onChanged: (v) => setState(() => _loc = v),
          requireFullSelection: false,
        ),
        const SizedBox(height: 14),
        _label(_bakimFormu
            ? 'Hizmet adresi (opsiyonel)'
            : 'İş yeri adresi (opsiyonel)'),
        TextField(
          controller: _isYeriAdres,
          minLines: 2,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: _dec(_bakimFormu
              ? 'Mahalle / semt veya açık adres'
              : 'Klinik / ofis / iş yeri açık adresi'),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: L10nText(
            kUzmanIsYeriAdresUyeNotu,
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.35),
          ),
        ),
        const SizedBox(height: 14),
        _label('Deneyim yılı (opsiyonel)'),
        TextField(
          controller: _deneyim,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _dec('Örn. 8'),
        ),
        const SizedBox(height: 14),
        _label('Kısa tanıtım (en az 10 karakter)  ${_tanitim.text.trim().length}'),
        TextField(
          controller: _tanitim,
          maxLines: 6,
          onChanged: (_) => setState(() {}),
          decoration: _dec(_bakimFormu
              ? 'Hangi ailelere / bireylere baktığınızı ve deneyiminizi yazın'
              : 'Kendinizi ve hizmetinizi tanıtın'),
        ),
        const SizedBox(height: 14),
        _label('Çalışma şekli (opsiyonel)'),
        _chips(
          uzmanCalismaSekliSecenekleri(bakim: _bakimFormu),
          _calisma,
          (v) => setState(() => _calisma = v),
        ),
        const SizedBox(height: 14),
        _label('Müsaitlik (opsiyonel)'),
        _chips(kMusaitlikSecenekleri, _musait, (v) => setState(() => _musait = v)),
        if (_bakiciFormu) ...[
          const SizedBox(height: 14),
          _label('Mezun olunan bölüm (opsiyonel)'),
          TextField(
            controller: _mezunBolum,
            textCapitalization: TextCapitalization.words,
            decoration: _dec('Örn. Hasta ve Yaşlı Hizmetleri'),
          ),
        ],
        if (!_bakimFormu) ...[
          const SizedBox(height: 14),
          _label('Mezun olduğu üniversite / okul'),
          TextField(
            controller: _universite,
            textCapitalization: TextCapitalization.words,
            decoration: _dec('Örn. Hacettepe Üniversitesi'),
          ),
          const SizedBox(height: 14),
          _label('Mezuniyet yılı'),
          TextField(
            controller: _mezuniyetYili,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: _dec('Örn. 2016'),
          ),
        ],
        const SizedBox(height: 14),
        _label('Sahip olduğu belgeler / sertifikalar'),
        TextField(
          controller: _belgeler,
          maxLines: 3,
          decoration: _dec(_bakimFormu
              ? 'Kurs, sertifika veya belge adlarını yazın'
              : 'Diploma, kurs, sertifika adlarını yazın'),
        ),
        if (!_bakimFormu) ...[
          const SizedBox(height: 14),
          _label('Yayımlanmış makalesi / araştırması var mı'),
          Row(
            children: [
              ChoiceChip(
                label: const Text('Evet'),
                selected: _makaleVar == true,
                onSelected: (_) => setState(() => _makaleVar = true),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Hayır'),
                selected: _makaleVar == false,
                onSelected: (_) => setState(() => _makaleVar = false),
              ),
            ],
          ),
          if (_makaleVar == true) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _makaleAciklama,
              maxLines: 3,
              decoration: _dec('Makale / yayın adı veya kısa açıklama'),
            ),
          ],
          const SizedBox(height: 14),
          _label('Özel uzmanlık ve ilgi alanları'),
          TextField(
            controller: _uzmanlikIlgi,
            maxLines: 3,
            decoration: _dec('Örn. pediatrik rehabilitasyon, duyu bütünleme'),
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const L10nText('İşaret dili biliyorum'),
          value: _isaretDili,
          onChanged: (v) => setState(() => _isaretDili = v),
        ),
        _label('Engelli bireylerle çalışma deneyimi'),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Evet'),
              selected: _engelliDeneyim == true,
              onSelected: (_) => setState(() => _engelliDeneyim = true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Hayır'),
              selected: _engelliDeneyim == false,
              onSelected: (_) => setState(() => _engelliDeneyim = false),
            ),
          ],
        ),
        if (_engelliDeneyim == true) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _engelliAciklama,
            maxLines: 3,
            decoration: _dec('Kısa açıklama'),
          ),
        ],
        const SizedBox(height: 14),
        _label('Referanslar (opsiyonel)'),
        TextField(controller: _referans, maxLines: 3, decoration: _dec('Önceki aile / işveren')),
        const SizedBox(height: 14),
        _label('İletişim tercihi (birini veya birkaçını seçin)'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: const Text('Uygulama içi mesaj'),
              selected: _iletisimMesaj,
              onSelected: (on) {
                if (!on && !_iletisimTelefon && !_iletisimEposta) return;
                setState(() => _iletisimMesaj = on);
              },
            ),
            FilterChip(
              label: const Text('Telefon'),
              selected: _iletisimTelefon,
              onSelected: (on) {
                if (!on && !_iletisimMesaj && !_iletisimEposta) return;
                setState(() => _iletisimTelefon = on);
              },
            ),
            FilterChip(
              label: const Text('E-posta'),
              selected: _iletisimEposta,
              onSelected: (on) {
                if (!on && !_iletisimMesaj && !_iletisimTelefon) return;
                setState(() => _iletisimEposta = on);
              },
            ),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: L10nText(
            'İstediğiniz kadarını işaretleyin: yalnızca mesaj, yalnızca telefon veya ikisi birden.',
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _stepMeslekOzel() {
    if (_sablonlar.isEmpty) {
      return const L10nText(
        'Bu meslek için ek alan yok. İleri ile devam edin.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in _sablonlar.where(
          (e) => e.tip != 'file' && !kOrtakCvDetayKeys.contains(e.alanKey),
        )) ...[
          _label('${s.etiket}${s.zorunlu ? ' *' : ''}'),
          if (s.alanKey.contains('referans'))
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: L10nText(
                'Önemli: önceki aile / işveren referanslarınızı yazın.',
                style: TextStyle(fontSize: 12, color: MetoColors.primary),
              ),
            ),
          _dynamicField(s),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  Widget _stepDosya() {
    final files = uzmanCvDosyaAlanlari(_sablonlar);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _photoPicker()),
        const SizedBox(height: 8),
        const L10nText(
          'Profil fotoğrafı kartta görünür. Diploma fotoğrafı kartta görünmez.',
          style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 16),
        if (files.isNotEmpty) ...[
          const L10nText(
            kBelgeFotoAciklama,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final s in files) ...[
          _label(
            '${s.etiket}${s.zorunlu && !isOpsiyonelBelgeAlani(s.alanKey) ? ' *' : ''}',
          ),
          if ((_files[s.alanKey] ?? '').isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CatalogImage(
                  source: _files[s.alanKey]!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => _pickFile(s.alanKey),
            icon: const Icon(Icons.add_a_photo_outlined),
            label: L10nText(
              belgeYukleButonMetni(
                s.alanKey,
                yuklendi: (_files[s.alanKey] ?? '').isNotEmpty,
              ),
            ),
          ),
          if (isOpsiyonelBelgeAlani(s.alanKey))
            const Padding(
              padding: EdgeInsets.only(top: 4, bottom: 8),
              child: L10nText(
                kBelgeFotoOpsiyonelNot,
                style: TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.35),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
        L10nText(
          _bakimFormu
              ? 'TC kimlik no, ev adresi ve doğum tarihi istenmez. Hizmet adresi isteğe bağlıdır.'
              : 'TC kimlik no, ev adresi ve doğum tarihi istenmez. İş yeri adresi isteğe bağlıdır.',
          style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.35),
        ),
      ],
    );
  }

  Widget _stepOzet() {
    final grup = _gruplar.where((g) => g.id == _grupId).toList();
    final etiket = grup.isEmpty ? '' : grup.first.etiket;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        L10nText(_ad.text, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800)),
        Text('$etiket · ${_loc.state} / ${_loc.city}',
            style: const TextStyle(color: MetoColors.mutedFg)),
        if (_telefon.text.trim().isNotEmpty)
          Text(_telefon.text.trim(),
              style: const TextStyle(color: MetoColors.mutedFg)),
        if (_isYeriAdres.text.trim().isNotEmpty)
          Text(
            _isYeriAdres.text.trim(),
            style: const TextStyle(color: MetoColors.mutedFg),
          ),
        const SizedBox(height: 12),
        Text(_tanitim.text, style: const TextStyle(height: 1.4)),
        const SizedBox(height: 16),
        _label('Kart boyutu'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _kartBoyutSecenegi(
                span: 1,
                title: '1 kutu',
                sub: uzmanKartBoyutOzeti(1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _kartBoyutSecenegi(
                span: 2,
                title: 'Tam satır',
                sub: uzmanKartBoyutOzeti(2),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ucretTarifeKarti(),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: _kvkk,
          onChanged: (v) => setState(() => _kvkk = v ?? false),
          contentPadding: EdgeInsets.zero,
          title: const L10nText(
            kKvkkOnayMetni,
            style: TextStyle(fontSize: 13, height: 1.35),
          ),
        ),
        const SizedBox(height: 8),
        const L10nText(
          kUzmanSorumlulukReddi,
          style: TextStyle(fontSize: 12, color: MetoColors.mutedFg, height: 1.35),
        ),
        const SizedBox(height: 12),
        const L10nText(
          'Yayınla: admin onayına düşer. Taslak: istediğiniz zaman devam edebilirsiniz.',
          style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
        ),
      ],
    );
  }

  Widget _dynamicField(MeslekAlanSablon s) {
    final v = _detay[s.alanKey];
    switch (s.tip) {
      case 'textarea':
        return TextField(
          minLines: 3,
          maxLines: 6,
          controller: _textCtrls[s.alanKey],
          onChanged: (t) => _detay[s.alanKey] = t,
          decoration: _dec(s.etiket),
        );
      case 'number':
        return TextField(
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          controller: _textCtrls[s.alanKey],
          onChanged: (t) => _detay[s.alanKey] = t,
          decoration: _dec(s.etiket),
        );
      case 'select':
        final cur = v?.toString();
        return DropdownButtonFormField<String>(
          key: ValueKey('${s.alanKey}|$cur'),
          initialValue: s.secenekler.contains(cur) ? cur : null,
          decoration: _dec('Seçin'),
          items: [
            for (final o in s.secenekler)
              DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (x) => setState(() => _detay[s.alanKey] = x),
        );
      case 'multi_select':
        final selected = v is List
            ? [for (final e in v) e.toString()]
            : <String>[];
        return _chips(s.secenekler, selected, (n) {
          setState(() => _detay[s.alanKey] = n);
        });
      case 'boolean':
        return Row(
          children: [
            ChoiceChip(
              label: const Text('Evet'),
              selected: v == true,
              onSelected: (_) => setState(() => _detay[s.alanKey] = true),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('Hayır'),
              selected: v == false,
              onSelected: (_) => setState(() => _detay[s.alanKey] = false),
            ),
          ],
        );
      default:
        return TextField(
          controller: _textCtrls[s.alanKey],
          onChanged: (t) => _detay[s.alanKey] = t,
          decoration: _dec(s.etiket),
        );
    }
  }

  Widget _chips(
    List<String> all,
    List<String> selected,
    ValueChanged<List<String>> onChanged,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in all)
          FilterChip(
            label: Text(o),
            selected: selected.contains(o),
            onSelected: (on) {
              final n = List<String>.from(selected);
              if (on) {
                n.add(o);
              } else {
                n.remove(o);
              }
              onChanged(n);
            },
          ),
      ],
    );
  }

  Widget _ucretUstBilgi() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: MetoColors.selectedBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MetoColors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: MetoColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: L10nText(
              kUzmanKartUstBilgi,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: MetoColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ucretTarifeKarti() {
    final ucretsiz =
        uzmanKartYayinUcreti(existing: _existing, span: _kartSpan) == 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          L10nText(
            'Yayın tarifesi',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          const L10nText(
            kUzmanKartUyeTarifeMetni,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          L10nText(
            uzmanKartUcretAciklamasi(span: _kartSpan, ucretsiz: ucretsiz),
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: MetoColors.mutedFg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kartBoyutSecenegi({
    required int span,
    required String title,
    required String sub,
  }) {
    final on = _kartSpan == span;
    return Material(
      color: on ? MetoColors.primary.withValues(alpha: 0.12) : MetoColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() => _kartSpan = span),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: on ? MetoColors.primary : MetoColors.border,
              width: on ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.3,
                  color: MetoColors.mutedFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: L10nText(
          t.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MetoColors.mutedFg,
          ),
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: MetoColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );
}
