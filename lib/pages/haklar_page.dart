import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../admin_config.dart';
import '../data/rights_data.dart';
import '../hak/hak_dosyasi.dart';
import '../hak/hak_kural.dart';
import '../hak/hak_takip_store.dart';
import '../meto_theme.dart';
import '../rights_catalog_store.dart';
import '../services/app_catalog_service.dart';
import '../services/catalog_adapters.dart';
import '../l10n/l10n_text.dart';
import '../widgets/admin_right_edit_sheet.dart';
import '../widgets/admin_rights_manage_sheet.dart';
import 'hak_dosyasi_page.dart';

String _hakFmtDate(DateTime? d) {
  if (d == null) return '';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

String? _raporUyariMetni(DateTime? raporBitis) {
  if (raporBitis == null) return null;
  final today = DateTime.now();
  final bitis = DateTime(raporBitis.year, raporBitis.month, raporBitis.day);
  final now = DateTime(today.year, today.month, today.day);
  final diff = bitis.difference(now).inDays;
  if (diff < 0 || diff > 30) return null;
  return 'Raporunuzun süresi ${_hakFmtDate(bitis)} tarihinde doluyor. '
      'Haklarınızın kesilmemesi için yenileme başvurusunu şimdiden yapın.';
}

String _takipDurumKisa(String? durum) {
  switch (durum) {
    case 'basvurdum':
      return 'Başvurdum';
    case 'bekliyor':
      return 'Sonuç bekleniyor';
    case 'onaylandi':
      return 'Onaylandı';
    case 'reddedildi':
      return 'Reddedildi';
    case 'basvurmadim':
    default:
      return 'Başvurmadım';
  }
}

/// Figma Make `HaklarTab` + `RightsSihirbazi` — Flutter portu.
class HaklarPage extends StatefulWidget {
  const HaklarPage({super.key, this.adminEmail});

  final String? adminEmail;

  @override
  State<HaklarPage> createState() => _HaklarPageState();
}

class _HaklarPageState extends State<HaklarPage> {
  bool _showWizard = false;
  String _activeCategory = 'tümü';
  String? _expandedId;
  String? _raporUyari;

  bool get _isAdmin => isAppAdmin(widget.adminEmail);

  @override
  void initState() {
    super.initState();
    _loadRaporUyari();
  }

  Future<void> _loadRaporUyari() async {
    final p = await hakProfilYukle();
    if (!mounted) return;
    setState(() => _raporUyari = _raporUyariMetni(p.raporBitis));
  }

  List<RightItem> get _allRights => CatalogAdapters.rightsItems();

  List<RightItem> get _filtered => _activeCategory == 'tümü'
      ? _allRights
      : _allRights.where((r) => r.category == _activeCategory).toList();

  List<RightsCategory> get _categories => CatalogAdapters.rightsCategories();

  Future<void> _openManage() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminRightsManageSheet(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _editRight(RightItem? item, {bool isNew = false}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminRightEditSheet(
        item: item ?? emptyRightItem(
          category: _activeCategory == 'tümü' ? 'maddi' : _activeCategory,
        ),
        isNew: isNew || item == null,
      ),
    );
    if (ok == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppCatalogService.instance,
      builder: (context, _) => Stack(
      children: [
        ColoredBox(
          color: MetoColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          L10nText(
                            'Devlet Destekleri',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                            ),
                          ),
                          SizedBox(height: 2),
                          L10nText(
                            'Yasal haklar, maaşlar ve başvuru rehberleri',
                            style: TextStyle(
                              fontSize: 12,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isAdmin) ...[
                      IconButton(
                        tooltip: 'Yönet',
                        onPressed: _openManage,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                      IconButton(
                        tooltip: 'Yeni hak',
                        onPressed: () => _editRight(null, isNew: true),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ],
                ),
              ),
              if (_raporUyari != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _RaporUyariBanner(text: _raporUyari!),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WizardBanner(
                    onStart: () => setState(() => _showWizard = true)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = _categories[i];
                    final active = cat.id == _activeCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _activeCategory = cat.id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: active ? MetoColors.primary : MetoColors.muted,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: MetoColors.primary
                                        .withValues(alpha: 0.27),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: L10nText(
                          '${cat.icon} ${cat.label}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: active ? Colors.white : MetoColors.mutedFg,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: _filtered.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == _filtered.length) return const _DisclaimerCard();
                    final r = _filtered[i];
                    return _RightCard(
                      item: r,
                      expanded: _expandedId == r.id,
                      onTap: () => setState(() {
                        _expandedId = _expandedId == r.id ? null : r.id;
                      }),
                      onEdit: _isAdmin ? () => _editRight(r) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (_showWizard)
          RightsSihirbazi(
            onClose: () {
              setState(() => _showWizard = false);
              _loadRaporUyari();
            },
          ),
      ],
    ),
    );
  }
}

class _RaporUyariBanner extends StatelessWidget {
  const _RaporUyariBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFC2410C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WizardBanner extends StatelessWidget {
  const _WizardBanner({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MetoColors.primary,
              Color.alphaBlend(const Color(0x40000000), MetoColors.primary),
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.auto_fix_high,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        L10nText(
                          'Hak Sorgulama Sihirbazı',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        L10nText(
                          '3 soruya yanıt verin — size özel haklar listelensin',
                          style: TextStyle(
                            color: Color(0xB3FFFFFF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: Colors.white.withValues(alpha: 0.15),
              child: InkWell(
                onTap: onStart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.20)),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      L10nText(
                        'Sihirbazı Başlat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightCard extends StatelessWidget {
  const _RightCard({
    required this.item,
    required this.expanded,
    required this.onTap,
    this.onEdit,
  });

  final RightItem item;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child:
                        Text(item.icon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        L10nText(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.amount,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: item.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: 'Düzenle',
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: MetoColors.mutedFg,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: MetoColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ...item.desc.split('\n\n').map(
                        (para) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: L10nText(
                            para,
                            style: TextStyle(
                              fontSize: 12,
                              color: MetoColors.mutedFg,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                  const SizedBox(height: 6),
                  L10nText(
                    'Başvuru Adımları:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(item.steps.length, (i) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.check_circle,
                              size: 16,
                              color: item.color,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: L10nText(
                              item.steps[i],
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: MetoColors.foreground
                                    .withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: item.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined,
                            size: 12, color: item.color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.where,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: item.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => HakDosyasiPage.open(context, item),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Hak dosyasını aç →',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: item.color,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
          SizedBox(width: 8),
          Expanded(
            child: L10nText(
              'Belirtilen tutarlar yaklaşık değerlerdir. Güncel miktarlar için resmi kurum web sitelerine başvurun.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFFB45309),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _WizardStep { kayitli, yas, cozger, rate, age, income, detay, results }

class _ScoredRight {
  const _ScoredRight({
    required this.item,
    required this.uygunluk,
    this.dosya,
  });

  final RightItem item;
  final HakUygunluk uygunluk;
  final HakDosyasi? dosya;
}

/// Hak sorgulama sihirbazı — tam akış (18 altı ÇÖZGER + 18 üstü oran/gelir).
class RightsSihirbazi extends StatefulWidget {
  const RightsSihirbazi({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<RightsSihirbazi> createState() => _RightsSihirbaziState();
}

class _RightsSihirbaziState extends State<RightsSihirbazi> {
  _WizardStep _step = _WizardStep.yas;
  bool _booting = true;
  HakProfil? _savedProfil;
  Map<String, HakTakip> _takip = {};

  String _yasGrubu = '';
  String _cozgerGrup = '';
  String _rate = '';
  String _age = '';
  String _income = '';

  // Detay: 0 unset, 1 evet, 2 hayır, 3 bilmiyorum (bilmiyorum → kaydetme)
  int _agirAns = 0;
  int _raporSureliAns = 0;
  DateTime? _raporBitis;
  int _kurumdaAns = 0;
  int _ayniEvdeAns = 0;
  final TextEditingController _haneKisiCtrl = TextEditingController();
  final TextEditingController _haneGelirCtrl = TextEditingController();
  String? _sgk;
  int _evSahibiAns = 0;
  int _aracAns = 0;
  int _okulAns = 0;

  bool _uygunCollapsed = true;

  int get _stepCount => 4;

  int get _stepIndex {
    switch (_step) {
      case _WizardStep.kayitli:
        return 0;
      case _WizardStep.yas:
        return 0;
      case _WizardStep.cozger:
        return 1;
      case _WizardStep.age:
        return 2;
      case _WizardStep.rate:
        return 1;
      case _WizardStep.income:
        return 2;
      case _WizardStep.detay:
        return 3;
      case _WizardStep.results:
        return _stepCount - 1;
    }
  }

  bool? _triBool(int ans) {
    if (ans == 1) return true;
    if (ans == 2) return false;
    return null; // unset veya bilmiyorum → kaydetme
  }

  int _triFromBool(dynamic v) {
    if (v == true) return 1;
    if (v == false) return 2;
    return 0;
  }

  List<RightItem> get _matchedRights => filterRights(
        yasGrubu: _yasGrubu,
        cozgerGrup: _cozgerGrup,
        rate: _rate,
        age: _age,
        income: _income,
        source: CatalogAdapters.rightsItems(),
      );

  Map<String, dynamic> get _cevaplar {
    final m = <String, dynamic>{};
    if (_yasGrubu.isNotEmpty) m['yas_grubu'] = _yasGrubu;
    if (_age.isNotEmpty) m['cocuk_yas'] = _age;
    if (_cozgerGrup.isNotEmpty) m['cozger'] = _cozgerGrup;
    if (_rate == '40-69') {
      m['oran'] = 40;
    } else if (_rate == '70-89') {
      m['oran'] = 70;
    } else if (_rate == '90+') {
      m['oran'] = 90;
    }
    if (_yasGrubu == '18alti') {
      m['rapor_turu'] = 'cozger';
    } else if (_yasGrubu == '18ustu') {
      m['rapor_turu'] = 'eskr';
    }
    final agir = _triBool(_agirAns);
    if (agir != null) m['agir'] = agir;
    final raporSureli = _triBool(_raporSureliAns);
    if (raporSureli != null) m['rapor_sureli'] = raporSureli;
    final kurumda = _triBool(_kurumdaAns);
    if (kurumda != null) m['kurumda'] = kurumda;
    final ayniEvde = _triBool(_ayniEvdeAns);
    if (ayniEvde != null) m['ayni_evde'] = ayniEvde;
    final kisi = int.tryParse(_haneKisiCtrl.text.trim());
    if (kisi != null) m['hane_kisi'] = kisi;
    final gelir = num.tryParse(
      _haneGelirCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    if (gelir != null) m['hane_gelir'] = gelir;
    if (_sgk != null && _sgk!.isNotEmpty) m['sgk'] = _sgk;
    final evSahibi = _triBool(_evSahibiAns);
    if (evSahibi != null) m['ev_sahibi'] = evSahibi;
    final arac = _triBool(_aracAns);
    if (arac != null) m['arac'] = arac;
    if (_yasGrubu == '18alti') {
      final okul = _triBool(_okulAns);
      if (okul != null) m['okul'] = okul;
    }
    return m;
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _haneKisiCtrl.dispose();
    _haneGelirCtrl.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    final profil = await hakProfilYukle();
    final takip = await hakTakipYukle();
    if (!mounted) return;
    setState(() {
      _savedProfil = profil;
      _takip = takip;
      _booting = false;
      if (profil.cevaplar.isNotEmpty) {
        _step = _WizardStep.kayitli;
      }
    });
  }

  void _applyProfil(HakProfil p, {required bool goResults}) {
    final c = p.cevaplar;
    _yasGrubu = c['yas_grubu']?.toString() ?? '';
    _cozgerGrup = c['cozger']?.toString() ?? '';
    _age = c['cocuk_yas']?.toString() ?? '';
    final oran = c['oran'];
    if (oran == 40 || oran == '40') {
      _rate = '40-69';
    } else if (oran == 70 || oran == '70') {
      _rate = '70-89';
    } else if (oran == 90 || oran == '90') {
      _rate = '90+';
    } else {
      _rate = '';
    }
    _agirAns = c.containsKey('agir') ? _triFromBool(c['agir']) : 0;
    _raporSureliAns =
        c.containsKey('rapor_sureli') ? _triFromBool(c['rapor_sureli']) : 0;
    _raporBitis = p.raporBitis;
    _kurumdaAns = c.containsKey('kurumda') ? _triFromBool(c['kurumda']) : 0;
    _ayniEvdeAns =
        c.containsKey('ayni_evde') ? _triFromBool(c['ayni_evde']) : 0;
    if (c['hane_kisi'] != null) {
      _haneKisiCtrl.text = c['hane_kisi'].toString();
    }
    if (c['hane_gelir'] != null) {
      _haneGelirCtrl.text = c['hane_gelir'].toString();
    }
    _sgk = c['sgk']?.toString();
    _evSahibiAns =
        c.containsKey('ev_sahibi') ? _triFromBool(c['ev_sahibi']) : 0;
    _aracAns = c.containsKey('arac') ? _triFromBool(c['arac']) : 0;
    _okulAns = c.containsKey('okul') ? _triFromBool(c['okul']) : 0;
    _step = goResults ? _WizardStep.results : _WizardStep.yas;
  }

  void _reset() {
    setState(() {
      _step = _WizardStep.yas;
      _yasGrubu = '';
      _cozgerGrup = '';
      _rate = '';
      _age = '';
      _income = '';
      _agirAns = 0;
      _raporSureliAns = 0;
      _raporBitis = null;
      _kurumdaAns = 0;
      _ayniEvdeAns = 0;
      _haneKisiCtrl.clear();
      _haneGelirCtrl.clear();
      _sgk = null;
      _evSahibiAns = 0;
      _aracAns = 0;
      _okulAns = 0;
      _uygunCollapsed = true;
    });
  }

  Future<void> _saveAndShowResults() async {
    final cevaplar = _cevaplar;
    final raporBitis = _raporSureliAns == 1 ? _raporBitis : null;
    await hakProfilKaydet(cevaplar, raporBitis: raporBitis);
    final takip = await hakTakipYukle();
    if (!mounted) return;
    setState(() {
      _takip = takip;
      _savedProfil = HakProfil(cevaplar: cevaplar, raporBitis: raporBitis);
      _step = _WizardStep.results;
    });
  }

  List<_ScoredRight> _classify() {
    final all = CatalogAdapters.rightsItems();
    final matchedIds = _matchedRights.map((r) => r.id).toSet();
    final cevaplar = cevaplarWithDerived(_cevaplar);
    final gelirUnknown =
        !cevaplar.containsKey('hane_gelir') && _income.isEmpty;
    final out = <_ScoredRight>[];
    for (final r in all) {
      final dosya = hakDosyasiOf(r.id);
      HakUygunluk? u;
      if (dosya != null) {
        u = uygunlukKural(dosya, cevaplar);
      }
      if (u != null) {
        out.add(_ScoredRight(item: r, uygunluk: u, dosya: dosya));
      } else if (matchedIds.contains(r.id)) {
        final u2 = (r.incomeLimit && gelirUnknown)
            ? HakUygunluk.sartlaraBagli
            : HakUygunluk.buyukIhtimalle;
        out.add(_ScoredRight(item: r, uygunluk: u2, dosya: dosya));
      }
    }
    return out;
  }

  String _kisiBasiText() {
    final kisi = int.tryParse(_haneKisiCtrl.text.trim());
    final gelir = num.tryParse(
      _haneGelirCtrl.text.trim().replaceAll('.', '').replaceAll(',', '.'),
    );
    if (kisi == null || kisi <= 0 || gelir == null) return 'Kişi başı: —';
    final v = (gelir / kisi).round();
    return 'Kişi başı: $v TL';
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) {
      return Material(
        color: MetoColors.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Material(
      color: MetoColors.background,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _step == _WizardStep.results
                  ? _buildResults()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                      child: _buildStepContent(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final title = _step == _WizardStep.results
        ? 'Başvurabileceğiniz Haklar'
        : _step == _WizardStep.kayitli
            ? 'Kayıtlı cevaplar'
            : 'Hak Sorgulama Sihirbazı';
    final showBar =
        _step != _WizardStep.results && _step != _WizardStep.kayitli;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: MetoColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onClose,
            style: IconButton.styleFrom(
              backgroundColor: MetoColors.muted,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.close, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                if (showBar) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(_stepCount, (i) {
                      return Expanded(
                        child: Container(
                          height: 6,
                          margin: EdgeInsets.only(
                              right: i < _stepCount - 1 ? 6 : 0),
                          decoration: BoxDecoration(
                            color: i <= _stepIndex
                                ? MetoColors.primary
                                : MetoColors.muted,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _WizardStep.kayitli:
        return _buildKayitliStep();
      case _WizardStep.yas:
        return _buildYasStep();
      case _WizardStep.cozger:
        return _buildCozgerStep();
      case _WizardStep.rate:
        return _buildRateStep();
      case _WizardStep.age:
        return _buildAgeStep();
      case _WizardStep.income:
        return _buildIncomeStep();
      case _WizardStep.detay:
        return _buildDetayStep();
      case _WizardStep.results:
        return const SizedBox.shrink();
    }
  }

  Widget _buildKayitliStep() {
    return Column(
      children: [
        L10nText(
          'Daha önce kaydettiğiniz cevaplar var',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        L10nText(
          'Kayıtlı cevaplarla devam edebilir veya güncelleyebilirsiniz',
          style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        _ContinueButton(
          enabled: true,
          label: 'Kayıtlı cevaplarımla sonuçları göster',
          onPressed: () {
            final p = _savedProfil;
            if (p == null) return;
            setState(() => _applyProfil(p, goResults: true));
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            final p = _savedProfil;
            if (p == null) return;
            setState(() => _applyProfil(p, goResults: false));
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text(
            'Cevaplarımı güncelle',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    final scored = _classify();
    final buyuk = scored
        .where((s) => s.uygunluk == HakUygunluk.buyukIhtimalle)
        .toList();
    final sart = scored
        .where((s) => s.uygunluk == HakUygunluk.sartlaraBagli)
        .toList();
    final uygunDegil = scored
        .where((s) => s.uygunluk == HakUygunluk.uygunDegil)
        .toList();
    final basvuran = scored.where((s) {
      final d = _takip[s.item.id]?.durum;
      return d != null && d != 'basvurmadim';
    }).length;
    final raporUyari = _raporUyariMetni(_raporBitis);
    final cozger = findCozgerGrup(_cozgerGrup);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (raporUyari != null) ...[
          _RaporUyariBanner(text: raporUyari),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MetoColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, size: 16, color: MetoColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: L10nText(
                  '${scored.length} hak bulundu · $basvuran tanesine başvurdunuz',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _copySonuc(buyuk, sart, uygunDegil),
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Sonucu kopyala'),
          ),
        ),
        if (_yasGrubu == '18alti' && cozger != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5EEFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFD4B3F0)),
            ),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B21A8),
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: '🧒 18 Yaş Altı — ÇÖZGER Sistemi\n',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text:
                        'Seçilen grup: $_cozgerGrup — ${cozger.label}${cozger.agir ? ' · Ağır engelli kapsamında değerlendirilir.' : ''}',
                  ),
                ],
              ),
            ),
          ),
        ],
        if (buyuk.isNotEmpty) ...[
          const SizedBox(height: 12),
          _groupHeader(
            'Büyük ihtimalle hakkınız var',
            const Color(0xFF15803D),
            const Color(0xFFDCFCE7),
          ),
          ...buyuk.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 8),
                child: _WizardResultCard(
                  scored: s,
                  cevaplar: _cevaplar,
                  takip: _takip[s.item.id],
                ),
              )),
        ],
        if (sart.isNotEmpty) ...[
          const SizedBox(height: 8),
          _groupHeader(
            'Şartlara bağlı, kontrol edin',
            const Color(0xFFA16207),
            const Color(0xFFFEF9C3),
          ),
          ...sart.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 8),
                child: _WizardResultCard(
                  scored: s,
                  cevaplar: _cevaplar,
                  takip: _takip[s.item.id],
                ),
              )),
        ],
        if (uygunDegil.isNotEmpty) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _uygunCollapsed = !_uygunCollapsed),
            child: _groupHeader(
              'Uygun görünmüyor (${uygunDegil.length})',
              const Color(0xFF6B7280),
              const Color(0xFFF3F4F6),
              trailing: Icon(
                _uygunCollapsed ? Icons.expand_more : Icons.expand_less,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          if (!_uygunCollapsed)
            ...uygunDegil.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10, top: 8),
                  child: _WizardResultCard(
                    scored: s,
                    cevaplar: _cevaplar,
                    takip: _takip[s.item.id],
                  ),
                )),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _reset,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: BorderSide(color: MetoColors.border),
          ),
          icon: const Icon(Icons.refresh, size: 14),
          label: const L10nText(
            'Yeniden Sorgula',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _groupHeader(
    String title,
    Color fg,
    Color bg, {
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Future<void> _copySonuc(
    List<_ScoredRight> buyuk,
    List<_ScoredRight> sart,
    List<_ScoredRight> uygunDegil,
  ) async {
    final buf = StringBuffer();
    void dump(String title, List<_ScoredRight> list) {
      if (list.isEmpty) return;
      buf.writeln(title);
      for (final s in list) {
        buf.writeln('- ${s.item.title} · ${s.item.amount}');
      }
      buf.writeln();
    }

    dump('Büyük ihtimalle hakkınız var', buyuk);
    dump('Şartlara bağlı, kontrol edin', sart);
    dump('Uygun görünmüyor', uygunDegil);
    await Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sonuç panoya kopyalandı')),
    );
  }

  Widget _buildYasStep() {
    return Column(
      children: [
        const L10nText('🎂', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        L10nText(
          'Kaç yaşında?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        L10nText(
          'Hak sistemi yaşa göre farklılaşır',
          style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 32),
        _OptionTile(
          title: '18 Yaş Altı',
          subtitle: 'ÇÖZGER sistemi geçerli — özel gereksinim raporu',
          selected: _yasGrubu == '18alti',
          onTap: () => setState(() => _yasGrubu = '18alti'),
        ),
        const SizedBox(height: 12),
        _OptionTile(
          title: '18 Yaş ve Üzeri',
          subtitle: 'Engel oranına göre sağlık kurulu raporu',
          selected: _yasGrubu == '18ustu',
          onTap: () => setState(() => _yasGrubu = '18ustu'),
        ),
        const SizedBox(height: 32),
        _ContinueButton(
          enabled: _yasGrubu.isNotEmpty,
          label: 'Devam',
          onPressed: () => setState(() {
            _step =
                _yasGrubu == '18alti' ? _WizardStep.cozger : _WizardStep.rate;
          }),
        ),
      ],
    );
  }

  Widget _buildCozgerStep() {
    return Column(
      children: [
        const L10nText('📋', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        L10nText(
          'ÇÖZGER Rapor Grubu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        L10nText(
          'Raporunuzdaki gereksinim düzeyi',
          style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF5FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE9D5FF)),
          ),
          child: const L10nText(
            '18 yaş altında geleneksel engellilik oranı kaldırılmıştır. Yerine ÇÖZGER (Çocuklar İçin Özel Gereksinim Raporu) sistemi kullanılmaktadır.',
            style:
                TextStyle(fontSize: 12, color: Color(0xFF6B21A8), height: 1.5),
          ),
        ),
        const SizedBox(height: 20),
        ...cozgerGruplari.map((g) {
          final selected = _cozgerGrup == g.range;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected ? g.bg : MetoColors.card,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: () => setState(() {
                  _cozgerGrup = g.range;
                  if (g.agir) _agirAns = 1;
                }),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected ? g.color : MetoColors.muted,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  g.range,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: selected
                                        ? g.color
                                        : MetoColors.foreground,
                                  ),
                                ),
                                if (g.agir) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const L10nText(
                                      'Ağır Engelli',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            L10nText(
                              '${g.label} (${g.kisa})',
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _RadioDot(selected: selected, color: g.color),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 24),
        _ContinueButton(
          enabled: _cozgerGrup.isNotEmpty,
          label: 'Devam',
          onPressed: () => setState(() => _step = _WizardStep.age),
        ),
      ],
    );
  }

  Widget _buildRateStep() {
    const options = [
      ('40-69', '%40 – %69', 'Orta düzey'),
      ('70-89', '%70 – %89', 'Ağır'),
      ('90+', '%90 ve üzeri', 'Tam bağımlı'),
    ];

    return Column(
      children: [
        const L10nText('📊', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        L10nText(
          'Engel oranı nedir?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        L10nText(
          'Sağlık Kurulu Raporu\'ndaki yüzde',
          style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 32),
        ...options.map((opt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionTile(
              title: opt.$2,
              subtitle: opt.$3,
              selected: _rate == opt.$1,
              onTap: () => setState(() => _rate = opt.$1),
            ),
          );
        }),
        const SizedBox(height: 20),
        _ContinueButton(
          enabled: _rate.isNotEmpty,
          label: 'Devam',
          onPressed: () => setState(() => _step = _WizardStep.income),
        ),
      ],
    );
  }

  Widget _buildAgeStep() {
    const options = [
      ('0-6', '0 – 6 yaş', 'Erken çocukluk'),
      ('7-17', '7 – 17 yaş', 'Okul çağı'),
    ];

    return Column(
      children: [
        const L10nText('🎈', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        L10nText(
          'Çocuğun yaşı?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        L10nText(
          'Destekler yaşa göre farklılaşıyor',
          style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 32),
        ...options.map((opt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionTile(
              title: opt.$2,
              subtitle: opt.$3,
              selected: _age == opt.$1,
              onTap: () => setState(() => _age = opt.$1),
            ),
          );
        }),
        const SizedBox(height: 20),
        _ContinueButton(
          enabled: _age.isNotEmpty,
          label: 'Devam',
          onPressed: () => setState(() {
            final g = findCozgerGrup(_cozgerGrup);
            if (g?.agir == true && _agirAns == 0) _agirAns = 1;
            _step = _WizardStep.detay;
          }),
        ),
      ],
    );
  }

  Widget _buildIncomeStep() {
    const options = [
      ('low', '₺0 – ₺5.000', 'Asgari ücretin altı'),
      ('mid', '₺5.000 – ₺15.000', 'Orta'),
      ('high', '₺15.000+', 'Yüksek'),
    ];

    return Column(
      children: [
        const L10nText('💰', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        L10nText(
          'Hane kişi başı gelir?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        L10nText(
          'Net aylık yaklaşık',
          style: TextStyle(fontSize: 14, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 32),
        ...options.map((opt) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _OptionTile(
              title: opt.$2,
              subtitle: opt.$3,
              selected: _income == opt.$1,
              onTap: () => setState(() => _income = opt.$1),
            ),
          );
        }),
        const SizedBox(height: 20),
        _ContinueButton(
          enabled: _income.isNotEmpty,
          label: 'Devam',
          onPressed: () => setState(() => _step = _WizardStep.detay),
        ),
      ],
    );
  }

  Widget _buildDetayStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        L10nText(
          'Birkaç soru daha',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        L10nText(
          'İsteğe bağlı — cevaplamak istemediğinizi atlayabilirsiniz',
          style: TextStyle(fontSize: 13, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 20),
        _triQuestion(
          "Raporda 'özel koşul gereksinimi var' veya 'ağır engelli' ibaresi var mı?",
          _agirAns,
          (v) => setState(() => _agirAns = v),
        ),
        _triQuestion(
          'Rapor süreli mi?',
          _raporSureliAns,
          (v) => setState(() {
            _raporSureliAns = v;
            if (v != 1) _raporBitis = null;
          }),
        ),
        if (_raporSureliAns == 1) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _raporBitis ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                helpText: 'Rapor bitiş tarihi',
              );
              if (picked != null) setState(() => _raporBitis = picked);
            },
            icon: const Icon(Icons.event, size: 16),
            label: Text(
              _raporBitis == null
                  ? 'Rapor bitiş tarihi'
                  : 'Bitiş: ${_hakFmtDate(_raporBitis)}',
            ),
          ),
        ],
        _triQuestion(
          'Yatılı bir kurumda mı kalıyor?',
          _kurumdaAns,
          (v) => setState(() => _kurumdaAns = v),
        ),
        _triQuestion(
          'Bakımı üstlenen kişi aynı evde mi yaşıyor?',
          _ayniEvdeAns,
          (v) => setState(() => _ayniEvdeAns = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _haneKisiCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Evde kaç kişi yaşıyor?',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _haneGelirCtrl,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Evin toplam aylık net geliri (TL)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _kisiBasiText(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MetoColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        L10nText(
          'Bakımı üstlenen kişinin çalışma durumu',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in [
              ('memur', 'Memur'),
              ('isci', 'İşçi (SGK)'),
              ('emekli', 'Emekli'),
              ('calismiyor', 'Çalışmıyor'),
            ])
              ChoiceChip(
                label: Text(opt.$2),
                selected: _sgk == opt.$1,
                onSelected: (_) => setState(() {
                  _sgk = _sgk == opt.$1 ? null : opt.$1;
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _triQuestion(
          'Oturduğunuz evin (tek ev) sahibi misiniz?',
          _evSahibiAns,
          (v) => setState(() => _evSahibiAns = v),
        ),
        _triQuestion(
          'Araç sahibi misiniz veya almayı düşünüyor musunuz?',
          _aracAns,
          (v) => setState(() => _aracAns = v),
        ),
        if (_yasGrubu == '18alti')
          _triQuestion(
            'Okula gidiyor mu?',
            _okulAns,
            (v) => setState(() => _okulAns = v),
          ),
        const SizedBox(height: 24),
        _ContinueButton(
          enabled: true,
          label: 'Haklarımı Göster',
          onPressed: _saveAndShowResults,
        ),
      ],
    );
  }

  Widget _triQuestion(
    String title,
    int ans,
    ValueChanged<int> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _triChip('Evet', ans == 1, () => onChanged(1)),
              const SizedBox(width: 8),
              _triChip('Hayır', ans == 2, () => onChanged(2)),
              const SizedBox(width: 8),
              _triChip('Bilmiyorum', ans == 3, () => onChanged(3)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _triChip(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: selected
            ? MetoColors.primary.withValues(alpha: 0.12)
            : MetoColors.muted,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? MetoColors.primary : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? MetoColors.primary : MetoColors.mutedFg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? MetoColors.primary.withValues(alpha: 0.07)
          : MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? MetoColors.primary : MetoColors.muted,
              width: 2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        color: selected
                            ? MetoColors.primary
                            : MetoColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _RadioDot(selected: selected, color: MetoColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: selected ? color : MetoColors.muted, width: 2),
        color: selected ? color : Colors.transparent,
      ),
      child: selected
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: MetoColors.primary,
          disabledBackgroundColor: MetoColors.primary.withValues(alpha: 0.4),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}

class _WizardResultCard extends StatelessWidget {
  const _WizardResultCard({
    required this.scored,
    required this.cevaplar,
    this.takip,
  });

  final _ScoredRight scored;
  final Map<String, dynamic> cevaplar;
  final HakTakip? takip;

  @override
  Widget build(BuildContext context) {
    final item = scored.item;
    final neden = <String>[];
    final dosya = scored.dosya;
    if (dosya != null) {
      for (final k in dosya.kimler) {
        if (k.kural == null) continue;
        final s = degerlendir(k.kural!, cevaplar);
        final mark = switch (s) {
          KuralSonuc.saglaniyor => '✓',
          KuralSonuc.saglanmiyor => '✗',
          KuralSonuc.bilinmiyor => '?',
        };
        final short = k.metin.length > 72
            ? '${k.metin.substring(0, 72)}…'
            : k.metin;
        neden.add('$mark $short');
      }
    }
    final durum = _takipDurumKisa(takip?.durum ?? 'basvurmadim');

    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => HakDosyasiPage.open(context, item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child:
                        Text(item.icon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        L10nText(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                            color: MetoColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: item.bg,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                item.amount,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: item.color,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: MetoColors.muted,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                durum,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (neden.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Neden?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                for (final line in neden)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
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
}
