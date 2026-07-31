import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_config.dart';
import 'data/diseases_data.dart';
import 'meto_theme.dart';
import 'services/app_catalog_service.dart';
import 'services/catalog_adapters.dart';
import 'widgets/catalog_media.dart';

/// Figma Make `HomeTab` — birebir Flutter portu.
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.userEmail = ''});

  final String userEmail;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _activeDisease;
  int? _expandedFaq;
  int _heroIdx = 0;
  Timer? _heroTimer;
  bool _savingOrder = false;
  List<DiseaseInfo> _orderedDiseases = [];

  List<DiseaseInfo> get _diseases =>
      _orderedDiseases.isEmpty ? CatalogAdapters.diseases() : _orderedDiseases;

  bool get _canReorder => isAppAdmin(widget.userEmail);

  static const _heroSlides = [
    _HeroSlide(
      asset: 'assets/images/118547.png',
      alt: 'Terapist ve özel gereksinimli çocuk yürüyüş terapisinde',
    ),
    _HeroSlide(
      asset: 'assets/images/118587-1.png',
      alt: 'Gökkuşağı altında mutlu iki çocuk',
    ),
    _HeroSlide(
      asset: 'assets/images/118600.png',
      alt: 'Anne ve yeni doğan bebeği hastanede',
    ),
  ];

  static const _nadirHastaliklar = [
    _NadirItem('Spina Bifida', '🧠', 'Omurilik ve omurga gelişim bozukluğu.'),
    _NadirItem(
      'Rett Sendromu',
      '🌸',
      'Ağırlıklı olarak kız çocuklarında görülen nörolojik gelişim bozukluğu.',
    ),
    _NadirItem(
      'Angelman Sendromu',
      '😊',
      'Mutluluk davranışı ve gelişim geriliğiyle karakterize genetik hastalık.',
    ),
    _NadirItem(
      'Prader-Willi',
      '🧬',
      'Hipotoni, obezite eğilimi ve gelişim geriliğiyle seyreden genetik durum.',
    ),
    _NadirItem(
      'PKU (Fenilketonüri)',
      '🔴',
      'Fenilalanin metabolizmasındaki enzim eksikliğinden kaynaklanan metabolik hastalık.',
    ),
    _NadirItem(
      'Fragile X',
      '🔬',
      'En yaygın kalıtsal zihinsel engel nedeni olan genetik bozukluk.',
    ),
    _NadirItem(
      'Tuberous Sclerosis',
      '🔵',
      'Beyin, cilt ve organlarda iyi huylu tümörlere yol açan genetik hastalık.',
    ),
    _NadirItem(
      'Duchenne Müsküler Distrofi',
      '💪',
      'Kas gücünün ilerleyici kaybıyla seyreden genetik kas hastalığı.',
    ),
    _NadirItem(
      'Williams Sendromu',
      '🎵',
      'Sosyal kişilik, müzikal yetenek ve kardiyovasküler sorunlarla karakterize durum.',
    ),
    _NadirItem(
      'CDKL5 Eksikliği',
      '⚡',
      'Erken başlangıçlı nöbetler ve ciddi gelişimsel gecikmeye yol açan genetik bozukluk.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _syncDiseasesFromCatalog();
    AppCatalogService.instance.addListener(_onCatalogChanged);
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _activeDisease != null) return;
      setState(() => _heroIdx = (_heroIdx + 1) % _heroSlides.length);
    });
  }

  @override
  void dispose() {
    AppCatalogService.instance.removeListener(_onCatalogChanged);
    _heroTimer?.cancel();
    super.dispose();
  }

  void _onCatalogChanged() {
    if (!mounted || _savingOrder) return;
    _syncDiseasesFromCatalog();
  }

  void _syncDiseasesFromCatalog() {
    setState(() {
      _orderedDiseases = List<DiseaseInfo>.from(CatalogAdapters.diseases());
    });
  }

  Future<void> _onDiseaseReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _orderedDiseases.length) return;
    if (newIndex < 0 || newIndex >= _orderedDiseases.length) return;

    setState(() {
      final item = _orderedDiseases.removeAt(oldIndex);
      _orderedDiseases.insert(newIndex, item);
      _savingOrder = true;
    });

    final orderedIds = [for (final d in _orderedDiseases) d.id];
    try {
      if (_canReorder) {
        await AppCatalogService.instance.persistDiseaseOrder(orderedIds);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sıra Supabase’e kaydedildi'),
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Admin değilse yerel cache + oturum sırası.
        await AppCatalogService.instance.applyLocalDiseaseOrder(orderedIds);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sıra kaydedilemedi: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  DiseaseInfo? get _selected {
    if (_activeDisease == null || _activeDisease == 'nadir') return null;
    return _diseases.cast<DiseaseInfo?>().firstWhere(
          (d) => d!.id == _activeDisease,
          orElse: () => null,
        );
  }

  void _goBack() => setState(() {
        _activeDisease = null;
        _expandedFaq = null;
      });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppCatalogService.instance,
      builder: (context, _) {
        if (_activeDisease == 'nadir') return _buildNadirDetail();
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
        padding: EdgeInsets.zero,
        children: [
          // Hero photo slider
          SizedBox(
            height: 260,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (var i = 0; i < _heroSlides.length; i++)
                  AnimatedOpacity(
                    opacity: i == _heroIdx ? 1 : 0,
                    duration: const Duration(milliseconds: 700),
                    child: Image.asset(
                      _heroSlides[i].asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: MetoColors.primaryDark,
                        alignment: Alignment.center,
                        child: const Text('🌱', style: TextStyle(fontSize: 48)),
                      ),
                    ),
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
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('👋', style: GoogleFonts.nunito(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(
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
                      Text(
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
                    children: List.generate(_heroSlides.length, (i) {
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

          // PubMed search
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: PubMedSearchBar(
              placeholder: 'Hastalık veya tedavi araştır (PubMed · Klinik)...',
            ),
          ),

          const DisclaimerBanner(),

          // Disease library — basılı tutup sürükleyerek sıralanabilir
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hastalıklar & Durumlar',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Kartlara basılı tutup sürükleyerek sırayı değiştirebilirsiniz',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 12),
                ReorderableGridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.92,
                  dragEnabled: true,
                  onReorder: _onDiseaseReorder,
                  children: [
                    for (final d in _diseases)
                      _DiseaseCard(
                        key: ValueKey(d.id),
                        disease: d,
                        onTap: () => setState(() {
                          _activeDisease = d.id;
                          _expandedFaq = null;
                        }),
                      ),
                  ],
                ),
              ],
            ),
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
                Text(
                  'Uzman Canlı Danışmanlık',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Çocuk psikiyatristi ve terapistlerle video görüşmesi yapın.',
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
                          content: Text('Bildirim listesine eklendiniz.'),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text(
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
        ],
      ),
    );
  }

  Widget _buildDiseaseDetail(DiseaseInfo d) {
    return ColoredBox(
      color: MetoColors.background,
      child: Column(
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
                    label: Text(
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
                  Text(
                    d.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
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
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                const DisclaimerBanner(margin: EdgeInsets.only(bottom: 16)),
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
                          const Text(
                            'Belirtiler',
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
                _DetailCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.medical_services_outlined,
                              size: 16, color: d.color),
                          const SizedBox(width: 8),
                          const Text(
                            'Tanı Süreci',
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
                _DetailCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.favorite_outline,
                              size: 16, color: d.color),
                          const SizedBox(width: 8),
                          const Text(
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
                _DetailCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book_outlined,
                              size: 16, color: d.color),
                          const SizedBox(width: 8),
                          const Text(
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
      child: Column(
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
                    label: const Text(
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
                  const Text('🔬', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  const Text(
                    'Nadir Hastalıklar',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Dünyada 7.000+ nadir hastalık tanımlanmıştır. Her biri 200.000'den az kişiyi etkiler.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.60),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                        child: Text(
                          'Nadir hastalıklarda erken tanı hayati önem taşır. Şikayetleriniz için genetik hastalıklar uzmanına başvurun.',
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
                for (final h in _nadirHastaliklar) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                              Text(
                                h.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: MetoColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                h.desc,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: MetoColors.mutedFg,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Text(
                                    'Detay',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF9333EA),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right,
                                      size: 14, color: Color(0xFF9333EA)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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
                      const Text(
                        'Faydalı Kaynaklar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final r in const [
                        'NORD — Nadir Hastalıklar Örgütü',
                        'Orphanet Türkiye',
                        'TÜBİTAK Nadir Hastalıklar Portalı',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.open_in_new,
                                  size: 12, color: MetoColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  r,
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
}

// ─── Small widgets ───────────────────────────────────────────────────────────

class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({super.key, required this.disease, required this.onTap});

  final DiseaseInfo disease;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (disease.photo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: CatalogImage(
                      source: disease.photo!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: disease.bg,
                        alignment: Alignment.center,
                        child: Text(disease.icon,
                            style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: disease.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child:
                      Text(disease.icon, style: const TextStyle(fontSize: 20)),
                ),
              const SizedBox(height: 8),
              Text(
                disease.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.foreground,
                  height: 1.25,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Daha fazla',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: disease.color,
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 12, color: disease.color),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class DisclaimerBanner extends StatelessWidget {
  const DisclaimerBanner(
      {super.key, this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16)});

  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Bu uygulama yalnızca bilgilendirme amaçlıdır. Tanı, tedavi veya tıbbi tavsiye yerine geçmez. Her zaman uzman bir sağlık profesyoneline başvurun.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFB45309),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PubMed search bar ───────────────────────────────────────────────────────

class PubMedSearchBar extends StatefulWidget {
  const PubMedSearchBar(
      {super.key, this.placeholder = 'Hastalık veya tedavi araştır...'});

  final String placeholder;

  @override
  State<PubMedSearchBar> createState() => _PubMedSearchBarState();
}

class _PubMedSearchBarState extends State<PubMedSearchBar> {
  final _controller = TextEditingController();
  bool _loading = false;
  bool _searched = false;
  String _translatedQ = '';
  String _tab = 'pubmed';
  List<_PubMedItem> _pubmed = [];
  List<_TrialItem> _trials = [];
  int _pubmedPage = 0;
  int _trialsPage = 0;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _toEnglish(String text) {
    var t = text.toLowerCase().trim();
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
                    child: Text(
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
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(Icons.open_in_new, size: 10, color: MetoColors.mutedFg),
            SizedBox(width: 4),
            Expanded(
              child: Text(
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
                Text(
                  "Aranıyor ve Türkçe'ye çevriliyor...",
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: MetoColors.mutedFg),
                ),
                Text(
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
                const Text(
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
              child: Text(
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
                      'trials', '🧪 Klinik (${_trials.length})')),
            ],
          ),
          const SizedBox(height: 12),
          if (_tab == 'pubmed')
            ...(_pubmed.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
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
                      child: Text(
                        'Klinik çalışma bulunamadı.',
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
        child: Text(
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
          Text(
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
                          child: Text(
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
            child: Text(
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
            child: Text(
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

class _HeroSlide {
  const _HeroSlide({required this.asset, required this.alt});
  final String asset;
  final String alt;
}

class _NadirItem {
  const _NadirItem(this.name, this.icon, this.desc);
  final String name;
  final String icon;
  final String desc;
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
