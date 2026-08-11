import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'admin_config.dart';
import 'data/diseases_data.dart';
import 'data/nadir_data.dart';
import 'home_hero_store.dart';
import 'info_library/info_library.dart';
import 'medical_disclaimer_store.dart';
import 'meto_theme.dart';
import 'nadir_store.dart';
import 'services/app_catalog_service.dart';
import 'services/catalog_adapters.dart';
import 'widgets/catalog_media.dart';
import 'widgets/duyurular_section.dart';
import 'widgets/hastaliklar_section.dart';
import 'widgets/home_social_footer.dart';
import 'pages/premature_gelisim_rehberi_page.dart';
import 'widgets/admin_disease_edit_sheet.dart';
import 'widgets/home_hero_admin_sheet.dart';
import 'widgets/medical_info_card.dart';
import 'widgets/guest_gate.dart';
import 'pages/tibbi_sorumluluk_reddi_page.dart';
import 'l10n/app_strings.dart';
import 'l10n/l10n_text.dart';

/// Figma Make `HomeTab` — birebir Flutter portu.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.userEmail = '',
    this.isGuest = false,
    this.onRequireLogin,
  });

  final String userEmail;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _activeDisease;
  DiseaseInfo? _openedDisease;
  String? _activeNadirId;
  List<NadirItem> _nadirItems = List<NadirItem>.from(kDefaultNadirItems);
  int? _expandedFaq;
  int _heroIdx = 0;
  Timer? _heroTimer;
  List<HomeHeroSlide> _heroSlides = List<HomeHeroSlide>.from(kDefaultHomeHeroSlides);

  List<DiseaseInfo> get _diseases => CatalogAdapters.diseases();

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  List<HomeHeroSlide> get _visibleHeroSlides {
    final active = _heroSlides.where((s) => s.isActive).toList();
    return active.isEmpty ? kDefaultHomeHeroSlides : active;
  }

  @override
  void initState() {
    super.initState();
    final cached = cachedNadirItems;
    if (cached != null) _nadirItems = List<NadirItem>.from(cached);
    final heroCached = cachedHomeHeroSlides;
    if (heroCached != null && heroCached.isNotEmpty) {
      _heroSlides = List<HomeHeroSlide>.from(heroCached);
    }
    _loadNadir();
    _loadHeroSlides();
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _activeDisease != null) return;
      final slides = _visibleHeroSlides;
      if (slides.isEmpty) return;
      setState(() => _heroIdx = (_heroIdx + 1) % slides.length);
    });
  }

  Future<void> _loadHeroSlides() async {
    final items = await loadHomeHeroSlides(
      forceRefresh: !hasFreshHomeHeroCache,
      viewerEmail: widget.userEmail,
    );
    if (!mounted) return;
    setState(() {
      _heroSlides = items;
      final n = _visibleHeroSlides.length;
      if (n > 0) _heroIdx = _heroIdx % n;
    });
  }

  Future<void> _openHeroAdmin() async {
    if (!_isAdmin) return;
    final all = await loadHomeHeroSlides(
      forceRefresh: true,
      viewerEmail: widget.userEmail,
    );
    if (!mounted) return;
    final result = await showModalBottomSheet<List<HomeHeroSlide>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HomeHeroAdminSheet(
        adminEmail: widget.userEmail,
        slides: all,
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _heroSlides = result;
        final n = _visibleHeroSlides.length;
        if (n > 0) _heroIdx = _heroIdx % n;
      });
    } else {
      await _loadHeroSlides();
    }
  }

  Future<void> _loadNadir() async {
    final items = await loadNadirItems(forceRefresh: !hasFreshNadirCache);
    if (!mounted) return;
    setState(() => _nadirItems = items);
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    super.dispose();
  }

  DiseaseInfo? get _selected {
    if (_activeDisease == null || _activeDisease == 'nadir') return null;
    if (_openedDisease?.id == _activeDisease) return _openedDisease;
    return _diseases.cast<DiseaseInfo?>().firstWhere(
          (d) => d!.id == _activeDisease,
          orElse: () => null,
        );
  }

  void _goBack() {
    if (_activeDisease == 'nadir' && _activeNadirId != null) {
      setState(() => _activeNadirId = null);
      return;
    }
    setState(() {
      _activeDisease = null;
      _openedDisease = null;
      _activeNadirId = null;
      _expandedFaq = null;
    });
  }

  Widget _buildHeroImage(HomeHeroSlide slide) {
    Widget fallback() => Container(
          color: MetoColors.primaryDark,
          alignment: Alignment.center,
          child: const L10nText('🌱', style: TextStyle(fontSize: 48)),
        );
    if (slide.isNetwork) {
      return Image.network(
        slide.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    if (slide.isAsset) {
      return Image.asset(
        slide.assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }
    return fallback();
  }

  void _openDisease(DiseaseInfo d) {
    if (d.id == 'premature') {
      PrematureGelisimRehberiPage.open(context);
      return;
    }
    setState(() {
      _activeDisease = d.id;
      _openedDisease = d;
      _activeNadirId = null;
      _expandedFaq = null;
    });
  }

  Future<void> _editDiseaseDetail(DiseaseInfo d) async {
    final result = await showModalBottomSheet<DiseaseInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminDiseaseEditSheet(disease: d),
    );
    if (result == null || !mounted) return;
    setState(() {
      _openedDisease = result;
      _activeDisease = result.id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: L10nText('İçerik kaydedildi.')),
    );
  }

  NadirItem? get _selectedNadir {
    final id = _activeNadirId;
    if (id == null) return null;
    return _nadirItems.cast<NadirItem?>().firstWhere(
          (n) => n!.id == id,
          orElse: () => null,
        );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppCatalogService.instance,
      builder: (context, _) {
        if (_activeDisease == 'nadir') {
          final nadir = _selectedNadir;
          if (nadir != null) return _buildNadirItemDetail(nadir);
          return _buildNadirDetail();
        }
        final selected = _selected;
        if (selected != null) return _buildDiseaseDetail(selected);
        return _buildHome();
      },
    );
  }

  Widget _buildHome() {
    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        key: const ValueKey('home_feed'),
        primary: false,
        padding: EdgeInsets.zero,
        children: [
          // Hero photo slider
          SizedBox(
            height: 260,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < _visibleHeroSlides.length; i++)
                  AnimatedOpacity(
                    opacity: i == _heroIdx ? 1 : 0,
                    duration: const Duration(milliseconds: 700),
                    child: _buildHeroImage(_visibleHeroSlides[i]),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x2E0D2B1F),
                        Color(0xB80D2B1F),
                      ],
                    ),
                  ),
                ),
                if (_isAdmin)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: _openHeroAdmin,
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_library_outlined,
                                  size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              L10nText(
                                'Görselleri yönet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          L10nText('👋', style: GoogleFonts.nunito(fontSize: 16)),
                          const SizedBox(width: 6),
                          L10nText(
                            'Hoş geldiniz',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xCCFFFFFF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      L10nText(
                        'Destek, bilgi ve\ntopluluk bir arada',
                        style: GoogleFonts.nunito(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.375,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 12,
                  child: Row(
                    children: List.generate(_visibleHeroSlides.length, (i) {
                      final active = i == _heroIdx;
                      return GestureDetector(
                        onTap: () => setState(() => _heroIdx = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(left: 6),
                          width: active ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: PubMedSearchBar(
              placeholder:
                  'Bilimsel kaynak veya konu araştır (makale · araştırma)...',
              isGuest: widget.isGuest,
              onRequireLogin: widget.onRequireLogin,
            ),
          ),

          const DisclaimerBanner(),

          DuyurularSection(
            key: ValueKey('duyurular_${widget.userEmail}'),
            userEmail: widget.userEmail,
          ),

          HastaliklarSection(
            userEmail: widget.userEmail,
            onOpenDisease: _openDisease,
          ),

          // Yakında teaser
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            decoration: BoxDecoration(
              color: MetoColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MetoColors.primary.withValues(alpha: 0.20),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        size: 16, color: MetoColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'YAKINDA',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: MetoColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                L10nText(
                  'Uzmanlarla Canlı Görüşme',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                L10nText(
                  'Eğitim ve destek uzmanlarıyla video görüşmesi (yakında).',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: MetoColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: L10nText('Bildirim listesine eklendiniz.'),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: L10nText(
                        'Bildirim Al',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MetoColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          HomeSocialFooter(adminEmail: widget.userEmail),
        ],
      ),
    );
  }

  Widget _buildDiseaseDetail(DiseaseInfo d) {
    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        // Ana sayfa kaydırma offset'i PrimaryScrollController'da kalmasın.
        key: ValueKey('disease_detail_${d.id}'),
        primary: false,
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  d.color.withValues(alpha: 0.13),
                  d.bg,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: _goBack,
                    icon: Icon(Icons.chevron_left, size: 20, color: d.color),
                    label: L10nText(
                      'Geri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: d.color,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  if (_isAdmin) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _editDiseaseDetail(d),
                        icon: Icon(Icons.edit_outlined, size: 18, color: d.color),
                        label: L10nText(
                          'Metni düzenle',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: d.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (d.photo != null)
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CatalogImage(
                          source: d.photo!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            d.icon,
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                    )
                  else
                    Text(d.icon, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  L10nText(
                    d.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  L10nText(
                    d.desc,
                    style: const TextStyle(
                      fontSize: 14,
                      color: MetoColors.mutedFg,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DisclaimerBanner(margin: EdgeInsets.only(bottom: 16)),
                if (d.symptoms.isNotEmpty) ...[
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: d.color,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const L10nText(
                              'Sık görülen özellikler',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        for (final s in d.symptoms) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle, size: 14, color: d.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  s,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (d.diagnosis.trim().isNotEmpty) ...[
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.medical_services_outlined,
                                size: 16, color: d.color),
                            const SizedBox(width: 8),
                            const L10nText(
                              'Bilgilendirme',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          d.diagnosis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: MetoColors.mutedFg,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (d.support.isNotEmpty) ...[
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite_outline,
                                size: 16, color: d.color),
                            const SizedBox(width: 8),
                            const L10nText(
                              'Destek Yolları',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in d.support)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: d.bg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  s,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: d.color,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (d.faq.isNotEmpty)
                  _DetailCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 16, color: d.color),
                          const SizedBox(width: 8),
                          const L10nText(
                            'Sık Sorulan Sorular',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: MetoColors.foreground,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      for (var i = 0; i < d.faq.length; i++) ...[
                        Container(
                          margin: EdgeInsets.only(
                              bottom: i == d.faq.length - 1 ? 0 : 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: MetoColors.border),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              InkWell(
                                onTap: () => setState(
                                  () => _expandedFaq =
                                      _expandedFaq == i ? null : i,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          d.faq[i].q,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: MetoColors.foreground,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        _expandedFaq == i
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        size: 18,
                                        color: MetoColors.mutedFg,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (_expandedFaq == i)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: Text(
                                    d.faq[i].a,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: MetoColors.mutedFg,
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                InfoLibraryMoreCard(
                  category: d.id,
                  title: 'Daha fazla içerik',
                  subtitle: 'Daha fazlası için tıklayınız',
                  listTitle: '${d.name} — Bilgi Kütüphanesi',
                  adminEmail: widget.userEmail,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNadirDetail() {
    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        key: const ValueKey('nadir_list'),
        primary: false,
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2E), Color(0xFF2D1B69)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: _goBack,
                    icon: const Icon(Icons.chevron_left,
                        size: 20, color: Color(0xCCFFFFFF)),
                    label: const L10nText(
                      'Geri',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xCCFFFFFF),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const L10nText('🔬', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  const L10nText(
                    'Nadir Durumlar',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  L10nText(
                    'Dünyada 7.000+ nadir durum tanımlanmıştır. Her biri 200.000’den az kişiyi etkiler.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DisclaimerBanner(margin: EdgeInsets.only(bottom: 16)),
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE9D5FF)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: Color(0xFF9333EA)),
                      SizedBox(width: 8),
                      Expanded(
                        child: L10nText(
                          'Nadir durumlarda erken bilgilendirme önemlidir. Destek için ilgili uzmanlara başvurabilirsiniz.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7E22CE),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (final h in _nadirItems) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: MetoColors.card,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setState(() => _activeNadirId = h.id),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: MetoColors.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF0EEFF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(h.icon,
                                    style: const TextStyle(fontSize: 20)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    L10nText(
                                      h.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: MetoColors.foreground,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      h.shortDesc,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: MetoColors.mutedFg,
                                        height: 1.45,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Row(
                                      children: [
                                        L10nText(
                                          'Detay',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF9333EA),
                                          ),
                                        ),
                                        Icon(Icons.chevron_right,
                                            size: 14,
                                            color: Color(0xFF9333EA)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MetoColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const L10nText(
                        'Faydalı Kaynaklar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final r in kNadirResources)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () => _openExternalUrl(r.url),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.open_in_new,
                                      size: 12, color: MetoColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      r.label,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: MetoColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Bağlantı açılamadı.')),
      );
    }
  }

  Widget _buildNadirItemDetail(NadirItem item) {
    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        key: ValueKey('nadir_item_${item.id}'),
        primary: false,
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A1A2E), Color(0xFF2D1B69)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: _goBack,
                        icon: const Icon(Icons.chevron_left,
                            size: 20, color: Color(0xCCFFFFFF)),
                        label: const L10nText(
                          'Nadir Durumlar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xCCFFFFFF),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const Spacer(),
                      if (_isAdmin)
                        IconButton(
                          tooltip: S.auto('Düzenle'),
                          onPressed: () => _openNadirEdit(item),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white24,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(item.icon, style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  L10nText(
                    item.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NadirSectionCard(
                  title: 'Tanım ve Gelişim',
                  body: item.definition,
                ),
                const SizedBox(height: 12),
                _NadirSectionCard(
                  title: 'Etkileri',
                  body: item.effects,
                ),
                if (_isAdmin) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openNadirEdit(item),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const L10nText('Metni düzenle'),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                InfoLibraryMoreCard(
                  category: item.id,
                  title: 'Daha fazla içerik',
                  subtitle: 'Daha fazlası için tıklayınız',
                  listTitle: '${item.name} — Bilgi Kütüphanesi',
                  adminEmail: widget.userEmail,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openNadirEdit(NadirItem item) async {
    final result = await showModalBottomSheet<NadirItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NadirEditSheet(item: item),
    );
    if (result == null || !mounted) return;
    try {
      final saved = await updateNadirItem(result);
      if (!mounted) return;
      setState(() {
        _nadirItems = [
          for (final n in _nadirItems)
            if (n.id == saved.id) saved else n,
        ];
        _activeNadirId = saved.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Nadir hastalık metni kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      // Lokal güncelle (tablo yoksa)
      setState(() {
        _nadirItems = [
          for (final n in _nadirItems)
            if (n.id == result.id) result else n,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('nadir') ||
                    e.toString().contains('PGRST') ||
                    e.toString().contains('schema')
                ? 'Yerelde kaydedildi. Kalıcı için nadir_hastaliklar.sql çalıştırın.'
                : 'Kayıt uyarısı: $e',
          ),
        ),
      );
    }
  }
}

// ─── Small widgets ───────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class DisclaimerBanner extends StatefulWidget {
  const DisclaimerBanner(
      {super.key, this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16)});

  final EdgeInsetsGeometry margin;

  @override
  State<DisclaimerBanner> createState() => _DisclaimerBannerState();
}

class _DisclaimerBannerState extends State<DisclaimerBanner> {
  bool _loading = true;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gone = await isInfoCardDismissed(kDismissHomeDisclaimer);
    if (!mounted) return;
    setState(() {
      _dismissed = gone;
      _loading = false;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    await dismissInfoCard(kDismissHomeDisclaimer);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed) return const SizedBox.shrink();

    return Container(
      margin: widget.margin,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: MetoColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MetoColors.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 16, color: MetoColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const TibbiSorumlulukReddiPage(),
                  ),
                );
              },
              child: L10nText(
                'Engelsiz Club bilgilendirme amaçlı bir topluluk destek platformudur; '
                'klinik hizmet sunmaz. Ayrıntılar için dokunun.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: MetoColors.mutedFg,
                  height: 1.45,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: S.auto('Kapat'),
            onPressed: _dismiss,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.close, size: 18, color: MetoColors.mutedFg),
          ),
        ],
      ),
    );
  }
}

// ─── PubMed search bar ───────────────────────────────────────────────────────

class PubMedSearchBar extends StatefulWidget {
  const PubMedSearchBar({
    super.key,
    this.placeholder =
        'Bilimsel kaynak veya konu araştır (makale · araştırma)...',
    this.isGuest = false,
    this.onRequireLogin,
  });

  final String placeholder;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<PubMedSearchBar> createState() => _PubMedSearchBarState();
}

class _PubMedSearchBarState extends State<PubMedSearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _loading = false;
  bool _searched = false;
  String _translatedQ = '';
  String _tab = 'pubmed';
  List<_PubMedItem> _pubmed = [];
  List<_TrialItem> _trials = [];
  int _pubmedPage = 0;
  int _trialsPage = 0;
  List<String> _suggestions = const [];

  /// Sayfa başına gösterilen kart sayısı.
  static const _pageSize = 6;

  /// API'den tek seferde çekilen maksimum sonuç (en güncelden eskiye).
  static const _fetchMax = 100;

  /// Çeviri önbelleği — aynı metni iki kez çevirmeyi önler.
  final Map<String, String> _trCache = {};

  static const _dict = {
    'otizm': 'autism',
    'serebral palsi': 'cerebral palsy',
    'down sendromu': 'down syndrome',
    'dehb': 'ADHD',
    'sma': 'spinal muscular atrophy',
    'gelişim geriliği': 'developmental delay',
    'nadir hastalık': 'rare disease',
    'duyu bütünleme': 'sensory integration',
    'iletişim bozukluğu': 'communication disorder',
    'tedavi': 'treatment',
    'terapi': 'therapy',
    'çocuk': 'children',
  };

  static const _typoHints = {
    'otizim': 'otizm',
    'otizim spektrum': 'otizm',
    'otizm spektrumu': 'otizm',
    'serebral pals': 'serebral palsi',
    'serebralpalasi': 'serebral palsi',
    'down sendormu': 'down sendromu',
    'dawn sendromu': 'down sendromu',
    'deh': 'dehb',
    'adhd': 'dehb',
    'gelisim geriligi': 'gelişim geriliği',
    'gelisim': 'gelişim geriliği',
    'duyu butunleme': 'duyu bütünleme',
    'iletisim': 'iletişim bozukluğu',
  };

  List<String> get _vocab {
    final names = <String>[
      for (final d in CatalogAdapters.diseases()) d.name,
      ..._dict.keys,
      'nadir hastalıklar',
      'fizyoterapi',
      'özel eğitim',
      'dil terapisi',
    ];
    final seen = <String>{};
    return [
      for (final n in names)
        if (seen.add(n.toLowerCase())) n,
    ];
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        // Kısa gecikme: öneri satırına tıklamaya izin ver
        Future<void>.delayed(const Duration(milliseconds: 120), () {
          if (mounted && !_focus.hasFocus) {
            setState(() => _suggestions = const []);
          }
        });
      } else {
        _onQueryChanged();
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  int _lev(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final m = a.length;
    final n = b.length;
    var prev = List<int>.generate(n + 1, (j) => j);
    for (var i = 1; i <= m; i++) {
      final cur = List<int>.filled(n + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [
          cur[j - 1] + 1,
          prev[j] + 1,
          prev[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return prev[n];
  }

  void _onQueryChanged() {
    final raw = _controller.text.trim().toLowerCase();
    if (raw.isEmpty) {
      if (_suggestions.isNotEmpty) setState(() => _suggestions = const []);
      return;
    }
    final corrected = _typoHints[raw] ?? raw;
    final scored = <(String, int)>[];
    for (final v in _vocab) {
      final vl = v.toLowerCase();
      if (vl.startsWith(corrected) || vl.contains(corrected)) {
        scored.add((v, 0));
        continue;
      }
      final d = _lev(corrected, vl.length > 24 ? vl.substring(0, 24) : vl);
      if (d <= 2 && corrected.length >= 3) scored.add((v, d + 1));
    }
    scored.sort((a, b) => a.$2.compareTo(b.$2));
    final out = <String>[];
    final typoFix = _typoHints[raw];
    if (typoFix != null) out.add(typoFix);
    for (final s in scored) {
      if (out.length >= 6) break;
      if (!out.any((e) => e.toLowerCase() == s.$1.toLowerCase())) {
        out.add(s.$1);
      }
    }
    setState(() => _suggestions = out);
  }

  void _applySuggestion(String s) {
    _controller.text = s;
    _controller.selection = TextSelection.collapsed(offset: s.length);
    setState(() => _suggestions = const []);
    _search();
  }

  String _toEnglish(String text) {
    var t = text.toLowerCase().trim();
    final typo = _typoHints[t];
    if (typo != null) t = typo;
    final keys = _dict.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      t = t.replaceAll(k, _dict[k]!);
    }
    return t;
  }

  Future<void> _search() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;
    final allowed = await ensureGuestSearchAllowed(
      context,
      isGuest: widget.isGuest,
      onRequireLogin: widget.onRequireLogin ?? () {},
    );
    if (!allowed) return;
    if (!mounted) return;
    setState(() {
      _loading = true;
      _searched = true;
      _pubmed = [];
      _trials = [];
      _pubmedPage = 0;
      _trialsPage = 0;
    });

    final eng = await _queryToEnglish(raw);
    _translatedQ = eng;

    try {
      await Future.wait([
        _fetchPubmed(eng),
        _fetchTrials(eng),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Türkçe sorguyu İngilizceye çevirir (Google → sözlük yedeği).
  Future<String> _queryToEnglish(String raw) async {
    final lowered = raw.toLowerCase().trim();
    final g = await _translate(raw, from: 'tr', to: 'en');
    if (g.isNotEmpty && g.toLowerCase() != lowered) return g;
    return _toEnglish(raw);
  }

  /// Tek bir metni çevirir. Önce keysiz Google uç noktası (kaliteli, yüksek
  /// kota), başarısız olursa MyMemory yedeği. Sonuç önbelleğe alınır.
  Future<String> _translate(String text,
      {required String from, required String to}) async {
    // Satır sonları toplu çeviride kayıt ayıracıdır; sadece yatay boşluk sadeleşir.
    final t = text
        .replaceAll(RegExp(r'[^\S\n]+'), ' ')
        .replaceAll(RegExp(r' *\n *'), '\n')
        .trim();
    if (t.isEmpty) return t;
    final cacheKey = '$from|$to|$t';
    final cached = _trCache[cacheKey];
    if (cached != null) return cached;

    // 1) Google (resmi olmayan, anahtarsız) uç noktası.
    try {
      final r = await http.get(Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx&sl=$from&tl=$to&dt=t&q=${Uri.encodeComponent(t)}',
      ));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as List;
        final segs = (data.isNotEmpty ? data[0] as List? : null) ?? const [];
        final buf = StringBuffer();
        for (final s in segs) {
          if (s is List && s.isNotEmpty) buf.write(s[0]?.toString() ?? '');
        }
        final out = buf.toString().trim();
        if (out.isNotEmpty) {
          _trCache[cacheKey] = out;
          return out;
        }
      }
    } catch (_) {}

    // 2) MyMemory yedeği (kısa metin sınırı).
    try {
      final q = t.length > 480 ? '${t.substring(0, 480)}…' : t;
      final r = await http.get(Uri.parse(
        'https://api.mymemory.translated.net/get'
        '?q=${Uri.encodeComponent(q)}&langpair=$from|$to',
      ));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map;
        final translated =
            (data['responseData'] as Map?)?['translatedText']?.toString() ?? '';
        if (translated.isNotEmpty &&
            !translated.toUpperCase().contains('MYMEMORY')) {
          _trCache[cacheKey] = translated;
          return translated;
        }
      }
    } catch (_) {}

    _trCache[cacheKey] = t;
    return t;
  }

  /// Çok sayıda metni verimli çevirir: satırları birleştirip tek istekte
  /// çevirir (Google satır sınırlarını korur), böylece 100 başlık ~birkaç
  /// istekte çevrilir.
  Future<List<String>> _translateMany(List<String> texts,
      {String from = 'en', String to = 'tr'}) async {
    final out = List<String>.filled(texts.length, '', growable: false);
    if (texts.isEmpty) return out;

    // ~1000 karakterlik gruplara böl (URL uzunluğu için güvenli).
    final chunks = <List<int>>[];
    var cur = <int>[];
    var curLen = 0;
    for (var i = 0; i < texts.length; i++) {
      final clean = texts[i].replaceAll(RegExp(r'\s+'), ' ').trim();
      final len = clean.length + 1;
      if (cur.isNotEmpty && curLen + len > 1000) {
        chunks.add(cur);
        cur = <int>[];
        curLen = 0;
      }
      cur.add(i);
      curLen += len;
    }
    if (cur.isNotEmpty) chunks.add(cur);

    await Future.wait(chunks.map((idxs) async {
      final joined = idxs
          .map((i) => texts[i].replaceAll(RegExp(r'\s+'), ' ').trim())
          .join('\n');
      final res = await _translate(joined, from: from, to: to);
      final parts = res.split('\n');
      if (parts.length == idxs.length) {
        for (var k = 0; k < idxs.length; k++) {
          final p = parts[k].trim();
          out[idxs[k]] = p.isEmpty ? texts[idxs[k]] : p;
        }
        return;
      }
      // Satır hizası bozulduysa güvenli yol: her kaydı ayrı çevir.
      await Future.wait(idxs.map((i) async {
        out[i] = await _translate(texts[i], from: from, to: to);
      }));
    }));
    return out;
  }

  Future<void> _fetchPubmed(String eng) async {
    try {
      final sr = await http.get(Uri.parse(
        'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi'
        '?db=pubmed&term=${Uri.encodeComponent('$eng children special needs')}'
        '&retmax=$_fetchMax&retmode=json&sort=pub_date',
      ));
      final ids =
          ((jsonDecode(sr.body) as Map)['esearchresult']?['idlist'] as List?)
                  ?.cast<String>() ??
              [];
      if (ids.isEmpty) return;

      // esummary tek seferde ~20 id ile daha güvenilir; batch'lere böl.
      final items = <_PubMedItem>[];
      for (var i = 0; i < ids.length; i += 20) {
        final batch = ids.sublist(i, (i + 20).clamp(0, ids.length));
        final sumR = await http.get(Uri.parse(
          'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi'
          '?db=pubmed&id=${batch.join(',')}&retmode=json',
        ));
        final result = (jsonDecode(sumR.body) as Map)['result'] as Map? ?? {};
        for (final id in batch) {
          final d = result[id] as Map? ?? {};
          final authors = ((d['authors'] as List?) ?? [])
              .take(2)
              .map((a) => (a as Map)['name']?.toString() ?? '')
              .where((n) => n.isNotEmpty)
              .join(', ');
          items.add(_PubMedItem(
            pmid: id,
            title: d['title']?.toString() ?? '—',
            authors: authors,
            journal: d['fulljournalname']?.toString() ??
                d['source']?.toString() ??
                '',
            year: (d['pubdate']?.toString() ?? '')
                .padRight(4)
                .substring(0, 4)
                .trim(),
          ));
        }
      }

      // Başlıkları toplu Türkçe'ye çevir (İngilizce başlığı da sakla).
      final titlesTr =
          await _translateMany(items.map((e) => e.title).toList());
      final translated = <_PubMedItem>[];
      for (var i = 0; i < items.length; i++) {
        translated.add(_PubMedItem(
          pmid: items[i].pmid,
          title: titlesTr[i],
          titleEn: items[i].title,
          authors: items[i].authors,
          journal: items[i].journal,
          year: items[i].year,
        ));
      }
      if (mounted) setState(() => _pubmed = translated);
    } catch (_) {}
  }

  Future<void> _fetchTrials(String eng) async {
    try {
      final r = await http.get(Uri.parse(
        'https://clinicaltrials.gov/api/v2/studies'
        '?query.term=${Uri.encodeComponent(eng)}&pageSize=$_fetchMax'
        '&sort=${Uri.encodeComponent('LastUpdatePostDate:desc')}&format=json',
      ));
      final studies = ((jsonDecode(r.body) as Map)['studies'] as List?) ?? [];
      final items = studies.map((s) {
        final p = (s as Map)['protocolSection'] as Map? ?? {};
        final id = p['identificationModule'] as Map? ?? {};
        final st = p['statusModule'] as Map? ?? {};
        final des = p['designModule'] as Map? ?? {};
        final cond = p['conditionsModule'] as Map? ?? {};
        final sp = p['sponsorCollaboratorsModule'] as Map? ?? {};
        final phases = ((des['phases'] as List?) ?? []).join(', ');
        final conditions =
            ((cond['conditions'] as List?) ?? []).take(2).join(', ');
        return _TrialItem(
          nctId: id['nctId']?.toString() ?? '',
          title: id['briefTitle']?.toString() ?? '—',
          status: st['overallStatus']?.toString() ?? '',
          phase: phases.isEmpty ? '—' : phases,
          conditions: conditions,
          sponsor: (sp['leadSponsor'] as Map?)?['name']?.toString() ?? '',
        );
      }).toList();

      // Başlık ve koşulları toplu Türkçe'ye çevir.
      final titlesTr = await _translateMany(items.map((e) => e.title).toList());
      final condsTr =
          await _translateMany(items.map((e) => e.conditions).toList());
      final translated = <_TrialItem>[];
      for (var i = 0; i < items.length; i++) {
        translated.add(_TrialItem(
          nctId: items[i].nctId,
          title: titlesTr[i],
          titleEn: items[i].title,
          status: items[i].status,
          phase: items[i].phase,
          conditions: condsTr[i],
          sponsor: items[i].sponsor,
        ));
      }
      if (mounted) setState(() => _trials = translated);
    } catch (_) {}
  }

  void _clear() {
    _controller.clear();
    setState(() {
      _pubmed = [];
      _trials = [];
      _searched = false;
      _translatedQ = '';
      _pubmedPage = 0;
      _trialsPage = 0;
    });
  }

  List<T> _pageSlice<T>(List<T> all, int page) {
    if (all.isEmpty) return const [];
    final start = page * _pageSize;
    if (start >= all.length) return const [];
    final end = (start + _pageSize).clamp(0, all.length);
    return all.sublist(start, end);
  }

  int _pageCount(int total) {
    if (total <= 0) return 0;
    return (total / _pageSize).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final hasAny = _pubmed.isNotEmpty || _trials.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MedicalInfoCard(
          margin: const EdgeInsets.only(bottom: 10),
          dismissKey: kDismissPubmedInfo,
          title: 'Bilgilendirme',
          body: _tab == 'trials'
              ? 'Bu bölüm ClinicalTrials.gov üzerinde herkese açık araştırmalarda '
                  'arama yapmanızı sağlar.\n\n'
                  'Engelsiz Club araştırmaları değerlendirmez, önermez veya yorumlamaz.'
              : 'Bu bölüm yalnızca PubMed veri tabanında arama yapmanızı sağlar.\n\n'
                  'Gösterilen sonuçlar Engelsiz Club tarafından oluşturulmaz.\n\n'
                  'Makaleler tavsiye niteliğinde değildir.',
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: MetoColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MetoColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 16, color: MetoColors.mutedFg),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  onSubmitted: (_) => _search(),
                  style: const TextStyle(
                      fontSize: 14, color: MetoColors.foreground),
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: const TextStyle(
                        fontSize: 14, color: MetoColors.mutedFg),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  onPressed: _clear,
                  icon: const Icon(Icons.close,
                      size: 14, color: MetoColors.mutedFg),
                  visualDensity: VisualDensity.compact,
                ),
              Material(
                color: MetoColors.primary,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _search,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: L10nText(
                      'Ara',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: MetoColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MetoColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _suggestions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  InkWell(
                    onTap: () => _applySuggestion(_suggestions[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.north_west,
                              size: 14, color: MetoColors.mutedFg),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _suggestions[i],
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MetoColors.foreground,
                              ),
                            ),
                          ),
                          if (_typoHints[
                                  _controller.text.trim().toLowerCase()] ==
                              _suggestions[i].toLowerCase())
                            const L10nText(
                              'Bunu mu demek istediniz?',
                              style: TextStyle(
                                fontSize: 10,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(Icons.open_in_new, size: 10, color: MetoColors.mutedFg),
            SizedBox(width: 4),
            Expanded(
              child: L10nText(
                'PubMed · ClinicalTrials.gov · Türkçe sonuçlar',
                style: TextStyle(fontSize: 10, color: MetoColors.mutedFg),
              ),
            ),
          ],
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: MetoColors.primary),
                ),
                SizedBox(height: 8),
                L10nText(
                  "Aranıyor ve Türkçe'ye çevriliyor...",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MetoColors.mutedFg),
                ),
                L10nText(
                  'PubMed · ClinicalTrials.gov',
                  style: TextStyle(fontSize: 10, color: MetoColors.mutedFg),
                ),
              ],
            ),
          ),
        if (!_loading && _searched && !hasAny)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const L10nText(
                  'Sonuç bulunamadı',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.foreground),
                ),
                const SizedBox(height: 4),
                Text(
                  _translatedQ.isNotEmpty
                      ? 'İngilizce olarak "$_translatedQ" arandı. Farklı bir kelime deneyin.'
                      : 'Farklı bir kelime deneyin.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                ),
              ],
            ),
          ),
        if (!_loading && hasAny) ...[
          if (_translatedQ.isNotEmpty &&
              _translatedQ.toLowerCase() != _controller.text.toLowerCase())
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: L10nText(
                '"${_controller.text}" → İngilizce: "$_translatedQ" olarak arandı',
                style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _tabButton('pubmed', '📄 PubMed (${_pubmed.length})')),
              const SizedBox(width: 6),
              Expanded(
                  child: _tabButton(
                      'trials', '🧪 Araştırmalar (${_trials.length})')),
            ],
          ),
          const SizedBox(height: 12),
          if (_tab == 'pubmed')
            ...(_pubmed.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: L10nText(
                        "PubMed'de sonuç bulunamadı.",
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                      ),
                    ),
                  ]
                : [
                    ..._pageSlice(_pubmed, _pubmedPage).map(_pubmedCard),
                    _buildPagination(
                      page: _pubmedPage,
                      pageCount: _pageCount(_pubmed.length),
                      total: _pubmed.length,
                      onChanged: (p) => setState(() {
                        _pubmedPage = p;
                      }),
                    ),
                  ])
          else
            ...(_trials.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: L10nText(
                        'Araştırma bulunamadı.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                      ),
                    ),
                  ]
                : [
                    ..._pageSlice(_trials, _trialsPage).map(_trialCard),
                    _buildPagination(
                      page: _trialsPage,
                      pageCount: _pageCount(_trials.length),
                      total: _trials.length,
                      onChanged: (p) => setState(() {
                        _trialsPage = p;
                      }),
                    ),
                  ]),
        ],
      ],
    );
  }

  Widget _buildPagination({
    required int page,
    required int pageCount,
    required int total,
    required ValueChanged<int> onChanged,
  }) {
    if (pageCount <= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: L10nText(
          '$total sonuç',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: MetoColors.mutedFg),
        ),
      );
    }

    // Çok sayfa olursa ortadaki aralığı göster (ör. 1 … 4 5 6 … 10).
    final pages = <int>[];
    if (pageCount <= 7) {
      pages.addAll(List.generate(pageCount, (i) => i));
    } else {
      pages.add(0);
      final start = (page - 1).clamp(1, pageCount - 4);
      final end = (page + 1).clamp(3, pageCount - 2);
      if (start > 1) pages.add(-1); // ellipsis
      for (var i = start; i <= end; i++) {
        if (!pages.contains(i)) pages.add(i);
      }
      if (end < pageCount - 2) pages.add(-1); // ellipsis
      if (!pages.contains(pageCount - 1)) pages.add(pageCount - 1);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Column(
        children: [
          L10nText(
            'Sayfa ${page + 1} / $pageCount · $total sonuç',
            style: const TextStyle(fontSize: 11, color: MetoColors.mutedFg),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _pageNavBtn(
                icon: Icons.chevron_left,
                enabled: page > 0,
                onTap: () => onChanged(page - 1),
              ),
              const SizedBox(width: 4),
              ...pages.map((p) {
                if (p < 0) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('…',
                        style: TextStyle(
                            fontSize: 12, color: MetoColors.mutedFg)),
                  );
                }
                final active = p == page;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Material(
                    color: active ? MetoColors.primary : MetoColors.muted,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onChanged(p),
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Center(
                          child: L10nText(
                            '${p + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: active ? Colors.white : MetoColors.mutedFg,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 4),
              _pageNavBtn(
                icon: Icons.chevron_right,
                enabled: page < pageCount - 1,
                onTap: () => onChanged(page + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageNavBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled ? MetoColors.muted : MetoColors.muted.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? MetoColors.foreground : MetoColors.mutedFg,
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String id, String label) {
    final active = _tab == id;
    return Material(
      color: active ? MetoColors.primary : MetoColors.muted,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => setState(() {
          _tab = id;
        }),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : MetoColors.mutedFg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _pubmedCard(_PubMedItem r) {
    final url = Uri.parse('https://pubmed.ncbi.nlm.nih.gov/${r.pmid}/');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => launchUrl(url, mode: LaunchMode.externalApplication),
            child: L10nText(
              r.title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: MetoColors.primary,
                decoration: TextDecoration.underline,
                decorationColor: MetoColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              if (r.year.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MetoColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    r.year,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.primary,
                    ),
                  ),
                ),
              if (r.journal.isNotEmpty)
                Text(
                  r.journal,
                  style: const TextStyle(fontSize: 10, color: MetoColors.mutedFg),
                ),
            ],
          ),
          if (r.authors.isNotEmpty)
            Text(
              r.authors,
              style: const TextStyle(fontSize: 10, color: MetoColors.mutedFg),
            ),
          if (r.titleEn.isNotEmpty && r.titleEn != r.title) ...[
            const SizedBox(height: 8),
            Text(
              r.titleEn,
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: MetoColors.mutedFg,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trialCard(_TrialItem t) {
    final url = t.nctId.isEmpty
        ? null
        : Uri.parse('https://clinicaltrials.gov/study/${t.nctId}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: url == null
                ? null
                : () => launchUrl(url, mode: LaunchMode.externalApplication),
            child: L10nText(
              t.title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: url == null ? MetoColors.foreground : MetoColors.primary,
                decoration: url == null ? null : TextDecoration.underline,
                decorationColor: MetoColors.primary,
              ),
            ),
          ),
          if (t.status.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              t.status,
              style: const TextStyle(fontSize: 10, color: MetoColors.mutedFg),
            ),
          ],
          if (t.nctId.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              t.nctId,
              style: const TextStyle(fontSize: 11, color: MetoColors.mutedFg),
            ),
          ],
          if (t.titleEn.isNotEmpty && t.titleEn != t.title) ...[
            const SizedBox(height: 8),
            Text(
              t.titleEn,
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: MetoColors.mutedFg,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Models & data ───────────────────────────────────────────────────────────

class _NadirSectionCard extends StatelessWidget {
  const _NadirSectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9333EA),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body.isEmpty ? 'İçerik henüz eklenmedi.' : body,
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: MetoColors.mutedFg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _NadirEditSheet extends StatefulWidget {
  const _NadirEditSheet({required this.item});

  final NadirItem item;

  @override
  State<_NadirEditSheet> createState() => _NadirEditSheetState();
}

class _NadirEditSheetState extends State<_NadirEditSheet> {
  late final TextEditingController _name;
  late final TextEditingController _short;
  late final TextEditingController _definition;
  late final TextEditingController _effects;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.item.name);
    _short = TextEditingController(text: widget.item.shortDesc);
    _definition = TextEditingController(text: widget.item.definition);
    _effects = TextEditingController(text: widget.item.effects);
  }

  @override
  void dispose() {
    _name.dispose();
    _short.dispose();
    _definition.dispose();
    _effects.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Başlık gerekli.')),
      );
      return;
    }
    setState(() => _saving = true);
    Navigator.of(context).pop(
      widget.item.copyWith(
        name: name,
        shortDesc: _short.text.trim(),
        definition: _definition.text.trim(),
        effects: _effects.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MetoColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: L10nText(
                'Nadir hastalık düzenle',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: S.auto('Başlık'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _short,
                      enabled: !_saving,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: S.auto('Kısa özet (liste kartı)'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _definition,
                      enabled: !_saving,
                      minLines: 4,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: S.auto('Tanım ve Gelişim'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _effects,
                      enabled: !_saving,
                      minLines: 4,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: S.auto('Etkileri'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: L10nText(
                  'Kaydet',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PubMedItem {
  const _PubMedItem({
    required this.pmid,
    required this.title,
    required this.authors,
    required this.journal,
    required this.year,
    this.titleEn = '',
  });
  final String pmid;
  final String title;
  final String authors;
  final String journal;
  final String year;
  final String titleEn;
}

class _TrialItem {
  const _TrialItem({
    required this.nctId,
    required this.title,
    required this.status,
    required this.phase,
    required this.conditions,
    required this.sponsor,
    this.titleEn = '',
  });
  final String nctId;
  final String title;
  final String status;
  final String phase;
  final String conditions;
  final String sponsor;
  final String titleEn;
}
