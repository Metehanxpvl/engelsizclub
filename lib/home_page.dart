import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'meto_theme.dart';

/// Figma Make `HomeTab` — birebir Flutter portu.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _activeDisease;
  int? _expandedFaq;
  int _heroIdx = 0;
  Timer? _heroTimer;

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
    _heroTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || _activeDisease != null) return;
      setState(() => _heroIdx = (_heroIdx + 1) % _heroSlides.length);
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    super.dispose();
  }

  DiseaseInfo? get _selected {
    if (_activeDisease == null || _activeDisease == 'nadir') return null;
    return kDiseases.cast<DiseaseInfo?>().firstWhere(
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
    if (_activeDisease == 'nadir') return _buildNadirDetail();
    final selected = _selected;
    if (selected != null) return _buildDiseaseDetail(selected);
    return _buildHome();
  }

  Widget _buildHome() {
    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Engelsiz Kahramanlar başlık
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0D2B1F), Color(0xFF1A6B4A)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Transform.translate(
                      offset: const Offset(0, 3),
                      child: Transform.scale(
                        scale: 1.5,
                        child: Image.asset(
                          'src/imports/119686.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Engelsiz Club',
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.25,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('🦸', style: TextStyle(fontSize: 20)),
                  ),
                ],
              ),
            ),
          ),

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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _HeroChip(
                            icon: Icons.people_alt_outlined,
                            label: '4.200+ Aile',
                          ),
                          const SizedBox(width: 8),
                          _HeroChip(
                            icon: Icons.verified_outlined,
                            label: 'Uzman Onaylı',
                          ),
                        ],
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
              placeholder: 'Hastalık veya tedavi araştır (PubMed · FDA)...',
            ),
          ),

          const DisclaimerBanner(),

          // Disease library
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
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: kDiseases.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (context, i) {
                    final d = kDiseases[i];
                    return _DiseaseCard(
                      disease: d,
                      onTap: () => setState(() {
                        _activeDisease = d.id;
                        _expandedFaq = null;
                      }),
                    );
                  },
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
                        child: Image.asset(
                          d.photo!,
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

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({required this.disease, required this.onTap});

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
                    child: Image.asset(
                      disease.photo!,
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
  List<_FdaItem> _fda = [];
  String? _expanded;
  int _pubmedPage = 0;
  int _trialsPage = 0;
  int _fdaPage = 0;

  /// Sayfa başına gösterilen kart sayısı.
  static const _pageSize = 6;

  /// API'den tek seferde çekilen maksimum sonuç (en güncelden eskiye).
  static const _fetchMax = 100;

  /// FDA sonuçları (çeviri kotası için daha az).
  static const _fdaFetchMax = 20;

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
      _fda = [];
      _expanded = null;
      _pubmedPage = 0;
      _trialsPage = 0;
      _fdaPage = 0;
    });

    final eng = await _queryToEnglish(raw);
    _translatedQ = eng;

    try {
      await Future.wait([
        _fetchPubmed(eng),
        _fetchTrials(eng),
        _fetchFda(eng),
      ]);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fdaSearchUrl([String? query]) {
    final q = (query ?? _translatedQ).trim();
    if (q.isEmpty) return 'https://www.fda.gov/search';
    return 'https://www.fda.gov/search?s=${Uri.encodeComponent(q)}';
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

  Future<void> _fetchFda(String eng) async {
    try {
      final items = <_FdaItem>[];
      final seen = <String>{};

      Future<void> pull(String path, String search) async {
        if (items.length >= _fdaFetchMax) return;
        final uri = Uri.parse(
          'https://api.fda.gov/$path'
          '?search=${Uri.encodeComponent(search)}'
          '&limit=${_fdaFetchMax - items.length}',
        );
        final r = await http.get(uri);
        if (r.statusCode != 200) return;
        final results =
            ((jsonDecode(r.body) as Map)['results'] as List?) ?? [];
        for (final raw in results) {
          if (items.length >= _fdaFetchMax) break;
          final m = Map<String, dynamic>.from(raw as Map);
          if (path == 'drug/label') {
            final openfda =
                Map<String, dynamic>.from((m['openfda'] as Map?) ?? {});
            final brands = ((openfda['brand_name'] as List?) ?? [])
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList();
            final generics = ((openfda['generic_name'] as List?) ?? [])
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList();
            final titleEng = brands.isNotEmpty
                ? brands.first
                : (generics.isNotEmpty ? generics.first : 'FDA ilaç kaydı');
            final indic = ((m['indications_and_usage'] as List?) ?? [])
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty);
            final purpose = ((m['purpose'] as List?) ?? [])
                .map((e) => e.toString())
                .where((e) => e.trim().isNotEmpty);
            var snippetEng =
                (indic.isNotEmpty ? indic.first : (purpose.isNotEmpty ? purpose.first : ''))
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim();
            if (snippetEng.length > 280) {
              snippetEng = '${snippetEng.substring(0, 280)}…';
            }
            final setId = m['set_id']?.toString() ??
                (() {
                  final spl = openfda['spl_set_id'] as List?;
                  if (spl == null || spl.isEmpty) return '';
                  return spl.first.toString();
                })();
            final key = setId.isNotEmpty ? setId : titleEng.toLowerCase();
            if (!seen.add(key)) continue;
            items.add(_FdaItem(
              id: key,
              title: titleEng,
              snippet: snippetEng,
              kind: 'İlaç etiketi',
              url: _fdaSearchUrl(eng),
            ));
          } else if (path == 'food/enforcement') {
            final titleEng =
                (m['product_description']?.toString() ?? 'Gıda kaydı')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim();
            var snippetEng =
                (m['reason_for_recall']?.toString() ?? '')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim();
            if (snippetEng.length > 280) {
              snippetEng = '${snippetEng.substring(0, 280)}…';
            }
            final report = m['report_date']?.toString() ?? '';
            final key =
                '${m['recall_number'] ?? titleEng}-$report'.toLowerCase();
            if (!seen.add(key)) continue;
            items.add(_FdaItem(
              id: key,
              title: titleEng.length > 120
                  ? '${titleEng.substring(0, 120)}…'
                  : titleEng,
              snippet: snippetEng,
              kind: 'Gıda / geri çağırma',
              url: _fdaSearchUrl(eng),
            ));
          }
        }
      }

      // Önce tırnaklı tam ifade, az sonuçsa genel arama.
      await pull('drug/label', '"$eng"');
      if (items.length < 4) {
        await pull('drug/label', eng);
      }
      if (items.length < _fdaFetchMax) {
        await pull('food/enforcement', '"$eng"');
      }
      if (items.isEmpty) {
        await pull('food/enforcement', eng);
      }

      // Başlık + özeti toplu Türkçe'ye çevir.
      final titlesTr = await _translateMany(items.map((e) => e.title).toList());
      final snipsTr = await _translateMany(items.map((e) => e.snippet).toList());
      final translated = <_FdaItem>[];
      for (var i = 0; i < items.length; i++) {
        translated.add(_FdaItem(
          id: items[i].id,
          title: titlesTr[i],
          snippet: items[i].snippet.isEmpty ? '' : snipsTr[i],
          kind: items[i].kind,
          url: items[i].url,
          titleEn: items[i].title,
        ));
      }

      if (mounted) setState(() => _fda = translated);
    } catch (_) {}
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
      _fda = [];
      _searched = false;
      _translatedQ = '';
      _pubmedPage = 0;
      _trialsPage = 0;
      _fdaPage = 0;
      _expanded = null;
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
    final hasAny =
        _pubmed.isNotEmpty || _trials.isNotEmpty || _fda.isNotEmpty;
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
                'PubMed · ClinicalTrials.gov · FDA.gov · Türkçe sonuçlar',
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
                  'PubMed · ClinicalTrials.gov · FDA.gov',
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
              const SizedBox(width: 6),
              Expanded(
                  child: _tabButton('fda', '🏛️ FDA (${_fda.length})')),
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
                        _expanded = null;
                      }),
                    ),
                  ])
          else if (_tab == 'trials')
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
                        _expanded = null;
                      }),
                    ),
                  ])
          else
            ...(_fda.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        "FDA'de sonuç bulunamadı.",
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                      ),
                    ),
                  ]
                : [
                    ..._pageSlice(_fda, _fdaPage).map(_fdaCard),
                    _buildPagination(
                      page: _fdaPage,
                      pageCount: _pageCount(_fda.length),
                      total: _fda.length,
                      onChanged: (p) => setState(() {
                        _fdaPage = p;
                        _expanded = null;
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
          _expanded = null;
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
    final open = _expanded == r.pmid;
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
            onTap: () => setState(() => _expanded = open ? null : r.pmid),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    if (r.year.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                        style: const TextStyle(
                            fontSize: 10, color: MetoColors.mutedFg),
                      ),
                  ],
                ),
                if (r.authors.isNotEmpty)
                  Text(
                    r.authors,
                    style: const TextStyle(
                        fontSize: 10, color: MetoColors.mutedFg),
                  ),
              ],
            ),
          ),
          if (open) ...[
            const Divider(height: 16),
            if (r.titleEn.isNotEmpty && r.titleEn != r.title) ...[
              Text(
                'Orijinal başlık (EN):',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                r.titleEn,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 10),
            ],
            InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://pubmed.ncbi.nlm.nih.gov/${r.pmid}/'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Row(
                children: [
                  Icon(Icons.open_in_new, size: 12, color: MetoColors.primary),
                  SizedBox(width: 6),
                  Text(
                    "PubMed'de Aç",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _trialCard(_TrialItem t) {
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
          Text(
            t.title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
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
            const SizedBox(height: 8),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse('https://clinicaltrials.gov/study/${t.nctId}'),
                mode: LaunchMode.externalApplication,
              ),
              child: Text(
                t.nctId,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fdaCard(_FdaItem f) {
    final open = _expanded == f.id;
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
            onTap: () => setState(() => _expanded = open ? null : f.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A3161).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    f.kind,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A3161),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  f.title,
                  maxLines: open ? 6 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                if (f.snippet.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    f.snippet,
                    maxLines: open ? 12 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.35,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (open) ...[
            const Divider(height: 16),
            InkWell(
              onTap: () => launchUrl(
                Uri.parse(_fdaSearchUrl()),
                mode: LaunchMode.externalApplication,
              ),
              child: const Row(
                children: [
                  Icon(Icons.open_in_new, size: 12, color: MetoColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'fda.gov/search · Aç',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.primary,
                    ),
                  ),
                ],
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

class FaqItem {
  const FaqItem(this.q, this.a);
  final String q;
  final String a;
}

class DiseaseInfo {
  const DiseaseInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.bg,
    required this.desc,
    required this.symptoms,
    required this.diagnosis,
    required this.support,
    required this.faq,
    this.photo,
  });

  final String id;
  final String name;
  final String icon;
  final Color color;
  final Color bg;
  final String? photo;
  final String desc;
  final List<String> symptoms;
  final String diagnosis;
  final List<String> support;
  final List<FaqItem> faq;
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

class _FdaItem {
  const _FdaItem({
    required this.id,
    required this.title,
    required this.snippet,
    required this.kind,
    required this.url,
    this.titleEn = '',
  });
  final String id;
  final String title;
  final String snippet;
  final String kind;
  final String url;
  final String titleEn;
}

const kDiseases = <DiseaseInfo>[
  DiseaseInfo(
    id: 'otizm',
    name: 'Otizm Spektrum Bozukluğu',
    icon: '🧩',
    color: Color(0xFF5B8DD9),
    bg: Color(0xFFEEF3FC),
    photo: 'assets/images/otizm.png',
    desc:
        "Otizm Spektrum Bozukluğu (OSB), sosyal iletişim ve etkileşimde güçlük ile kısıtlı, tekrarlayıcı davranış örüntüleriyle karakterize, erken gelişimsel dönemde ortaya çıkan nörogelişimsel bir durumdur. Her bireyde farklı biçimde görülür; bu nedenle 'spektrum' adını alır.",
    symptoms: [
      'Göz temasından kaçınma veya sınırlı göz teması',
      'Dil ve konuşma gelişiminde gecikme ya da gerileme',
      'Tekrarlayıcı hareketler (el çırpma, sallanma)',
      'Rutin değişikliklerine aşırı direnç',
      'Duyusal uyaranlara (ses, ışık, dokunma) aşırı veya yetersiz tepki',
      'Akran ilişkilerinde güçlük, sosyal ipuçlarını okuyamama',
      'Sınırlı ilgi alanları ve obsesif odaklanma',
    ],
    diagnosis:
        'Çocuk psikiyatristi veya çocuk nöroloğu tarafından DSM-5 ölçütleri esas alınarak kapsamlı gelişimsel değerlendirme yapılır. ADOS-2 ve ADI-R standart araçlardır. Erken belirtiler 12–18 aylarda fark edilebilir; kesin tanı genellikle 2–3 yaşında konulur.',
    support: [
      'Uygulamalı Davranış Analizi (ABA)',
      'Dil ve konuşma terapisi',
      'Ergoterapi (duyusal entegrasyon)',
      'PECS ve AAC iletişim sistemleri',
      'Sosyal beceri grupları',
      'Aile rehberliği ve ebeveyn eğitimi',
      'Özel eğitim ve kaynaştırma programları',
    ],
    faq: [
      FaqItem(
        'Otizm tedavi edilebilir mi?',
        "Otizm 'tedavi edilmez' ancak erken ve yoğun müdahaleyle bireyler bağımsızlıklarını ve yaşam kalitelerini önemli ölçüde artırabilir. ABA en kanıta dayalı yöntemdir.",
      ),
      FaqItem(
        'Kaç yaşında tanı konulabilir?',
        '18–24 ay gibi erken dönemde belirtiler fark edilebilir. Güvenilir tanı genellikle 2–3 yaşında konulur.',
      ),
      FaqItem(
        'Otizm kalıtsal mıdır?',
        "Genetik yatkınlık önemli bir rol oynar. İkizlerde uyum oranı %70–90'a ulaşmaktadır.",
      ),
    ],
  ),
  DiseaseInfo(
    id: 'serebral',
    name: 'Serebral Palsi',
    icon: '🌟',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
    photo: 'assets/images/serebral_palsi.png',
    desc:
        "Serebral Palsi (SP), beyin gelişimini etkileyen, erken yaşta meydana gelen beyin hasarından kaynaklanan motor fonksiyon bozukluğudur. Türkiye'de her 1000 canlı doğumda 2–3 çocukta görülür.",
    symptoms: [
      'Spastisite (kas sertliği ve anormal refleksler)',
      'Ataksi (denge ve koordinasyon güçlüğü)',
      'Diskinezi (istemsiz hareketler)',
      'Yürüme bozukluğu veya yürüyememe',
      'Konuşma güçlüğü (dizartri)',
      'Yutma güçlüğü',
      "Zihinsel ve öğrenme güçlükleri (vakaların yaklaşık %50'sinde)",
      'Epilepsi nöbetleri',
    ],
    diagnosis:
        'Nörolog tarafından klinik değerlendirme ve beyin MRI ile tanı konulur. Erken belirtiler ilk 6 ayda fark edilebilir. Kesin tanı çoğunlukla 12–24 ayda netleşir.',
    support: [
      'Fizik tedavi ve rehabilitasyon (Bobath, Vojta yöntemleri)',
      'Ergoterapi (günlük yaşam becerileri)',
      'Dil ve konuşma terapisi',
      'Ortez ve yardımcı cihazlar (AFO, tekerlekli sandalye)',
      'Hidroterapi ve at terapisi (hippoterapi)',
      'Botoks enjeksiyonu (spastisite yönetimi)',
      'Bakıcı ve aile eğitimi',
    ],
    faq: [
      FaqItem(
        'SP ilerleyici midir?',
        'Hayır. Beyin hasarı sabit kalır; ancak birey büyüdükçe kaslar ve eklemler etkilenebilir.',
      ),
      FaqItem(
        "SP'li çocuklar bağımsız yürüyebilir mi?",
        'SP tipine göre değişir. GMFCS Düzey 1–2’deki çocukların büyük çoğunluğu bağımsız yürür.',
      ),
      FaqItem(
        'Serebral palsi tipleri nelerdir?',
        'Dört ana tip: Spastik SP, Ataksik SP, Diskinetik SP ve Miks Tip SP.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'down',
    name: 'Down Sendromu',
    icon: '💛',
    color: Color(0xFFF4A832),
    bg: Color(0xFFFFF8ED),
    photo: 'assets/images/down_sendromu.png',
    desc:
        'Down Sendromu, 21. kromozomun fazladan bir kopyasının (trizomi 21) bulunmasından kaynaklanır. Dünyada her 700–1000 canlı doğumda bir görülür.',
    symptoms: [
      'Kas hipotonisi (düşük kas tonusu)',
      'Karakteristik yüz özellikleri',
      'Kısa boy ve geniş el-ayak yapısı',
      "Konjenital kalp defekti (vakaların yaklaşık %40–50'sinde)",
      'Zihinsel ve gelişimsel gecikmeler',
      'Tiroid sorunları ve işitme kaybı riski',
      'Erken yaşlanma eğilimi ve Alzheimer riski',
    ],
    diagnosis:
        'Prenatal: İkili/üçlü tarama, NIPT, amniyosentez, KVÖ. Doğumda klinik bulgular ve karyotip analizi kesin tanıyı sağlar.',
    support: [
      'Erken müdahale programları (0–3 yaş kritik dönem)',
      'Özel eğitim ve kaynaştırma eğitimi',
      'Konuşma ve dil terapisi',
      'Fizik tedavi (kas tonusu ve motor gelişim)',
      'Ergoterapi (ince motor beceriler)',
      'Kalp sorunları için kardiyoloji takibi',
      'Down Sendromu Araştırma Vakfı (DSRF) destek programları',
    ],
    faq: [
      FaqItem(
        'Down sendromlu bireyler ne kadar süre yaşar?',
        'Modern tıptaki gelişmeler sayesinde yaşam beklentisi 60 yılın üzerine çıkmıştır.',
      ),
      FaqItem('Okula gidebilirler mi?',
          'Evet. Kaynaştırma eğitimi ve özel eğitim programlarıyla okul eğitimi alabilirler.'),
      FaqItem(
        'Anne yaşı Down sendromu riskini etkiler mi?',
        'Evet. 35 yaş üstü annelerde risk artar; ancak vakaların büyük bölümü genç annelerde görülür.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'sma',
    name: 'SMA (Spinal Müsküler Atrofi)',
    icon: '💪',
    color: Color(0xFF7C3AED),
    bg: Color(0xFFF5F0FF),
    photo: 'assets/images/SMA_.png',
    desc:
        "Spinal Müsküler Atrofi (SMA), SMN1 genindeki mutasyon sonucu motor nöronların işlev görmemesiyle oluşan genetik bir hastalıktır. Türkiye'de yaklaşık 1500–2000 hasta bulunduğu tahmin edilmektedir.",
    symptoms: [
      'Kas güçsüzlüğü ve erimesi',
      'Solunum güçlüğü',
      'Yutma ve beslenme güçlüğü',
      'Oturma, ayakta durma ve yürümede güçlük',
      'Hipotonik bebek (floppy baby) görünümü',
      'Omurga deformiteleri (skolyoz)',
    ],
    diagnosis:
        'SMN1 gen analizi altın standarttır. EMG ve kas biyopsisi destekleyicidir. Semptom başlangıcına göre Tip 1–4 sınıflandırması yapılır.',
    support: [
      'Zolgensma (gen tedavisi)',
      'Nusinersen/Spinraza',
      'Risdiplam/Evrysdi',
      'Solunum desteği (BiPAP)',
      'Beslenme desteği',
      'Fizik tedavi, ergoterapi, ortez',
      'SMA Derneği Türkiye',
    ],
    faq: [
      FaqItem(
        'SMA tedavi edilebilir mi?',
        'Zolgensma, Spinraza ve Evrysdi hastalığın seyrini ciddi biçimde değiştirmektedir.',
      ),
      FaqItem(
        "Türkiye'de tedaviye erişim nasıl?",
        'Spinraza SGK kapsamındadır. Zolgensma için Sağlık Bakanlığına bireysel başvuru yapılabilmektedir.',
      ),
      FaqItem(
        'Gelecekte ne gibi tedaviler bekleniyor?',
        'Miyostatin inhibitörleri, yeni nesil gen tedavileri ve nöroprotektif ajanlar klinik deneme aşamasındadır.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'dehb',
    name: 'DEHB',
    icon: '⚡',
    color: Color(0xFFE8960A),
    bg: Color(0xFFFFF3DB),
    photo: 'assets/images/DEHB.png',
    desc:
        "Dikkat Eksikliği ve Hiperaktivite Bozukluğu (DEHB), dikkat süresinin kısalığı, dürtüsellik ve hiperaktivite ile karakterize nörogelişimsel bir bozukluktur. Okul çağı çocuklarının yaklaşık %5–8'ini etkiler.",
    symptoms: [
      'Derse veya göreve odaklanamama',
      'Ayrıntılarda dikkatsiz hatalar',
      'Görevleri organize etmede güçlük',
      'Sakin oturamama',
      'Sırasını bekleyememe',
      'Düşüncesizce hareket etme',
      'Eşyaları sık kaybetme, unutkanlık',
    ],
    diagnosis:
        'Çocuk psikiyatristi veya klinisyen psikolog tarafından DSM-5 ölçütleriyle değerlendirme yapılır. En az 6 ay ve birden fazla ortamda görülen belirtiler tanı için gereklidir.',
    support: [
      'Davranış terapisi ve BDT',
      'Metilfenidat bazlı ilaçlar',
      'Atomoksetin (Strattera)',
      'Okul düzenlemeleri',
      'Aile rehberliği',
      'Sosyal beceri grupları',
      'Spor ve hareket aktiviteleri',
    ],
    faq: [
      FaqItem('DEHB ilaçsız tedavi edilir mi?',
          'Hafif vakalarda davranış terapisi yeterli olabilir.'),
      FaqItem('DEHB büyüyünce geçer mi?',
          'Hiperaktivite azalabilir ancak dikkat sorunları yetişkinlikte de sürebilir.'),
      FaqItem('DEHB zeka düzeyiyle ilişkili midir?',
          'Hayır. DEHB zekanın yüksek veya düşük olmasıyla ilgili değildir.'),
    ],
  ),
  DiseaseInfo(
    id: 'gelisim',
    name: 'Gelişim Geriliği',
    icon: '🌱',
    color: Color(0xFF5BA882),
    bg: Color(0xFFE4F0E9),
    photo: 'assets/images/geli_im_gerili_i.png',
    desc:
        "Global Gelişim Geriliği, motor, dil, bilişsel ve sosyal-duygusal alanlarda yaşa uygun gelişimin gerisinde kalma durumudur. Türkiye'de her 100 çocuktan 1–3'ünü etkiler.",
    symptoms: [
      'Motor gelişimde gecikme',
      'Dil ve konuşma ediniminde yavaşlık',
      'Sosyal etkileşim ve oyun becerilerinde güçlük',
      'Öz bakım becerilerinde gecikme',
      'Akademik öğrenme güçlükleri',
      'Dikkat ve bellek problemleri',
    ],
    diagnosis:
        'Gelişim pediatristi tarafından Denver II ile tarama yapılır. Nörolojik muayene, MRI, metabolik testler ve genetik panel uygulanabilir.',
    support: [
      'Erken müdahale programları (0–6 yaş)',
      'Fizik tedavi',
      'Dil ve konuşma terapisi',
      'Ergoterapi',
      'Özel eğitim ve BEP',
      'Beslenme desteği',
      'Aile eğitimi ve ev programları',
    ],
    faq: [
      FaqItem('Erken müdahale neden bu kadar önemli?',
          '0–6 yaş arası beyin plastisitesi en yüksek dönemdir.'),
      FaqItem('Gelişim geriliği büyüdükçe düzelir mi?',
          'Nedene göre değişir. Destek tedavileri yaşam kalitesini artırır.'),
      FaqItem(
        'Büyüme geriliği ile gelişim geriliği aynı şey midir?',
        'Hayır. Büyüme geriliği fiziksel; gelişim geriliği bilişsel ve motor alanları kapsar.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'duyu',
    name: 'Duyu Bütünleme Sorunları',
    icon: '✋',
    color: Color(0xFF9C6DB3),
    bg: Color(0xFFF5EEFB),
    photo: 'assets/images/duyu_b_t_nleme_sorunlar_.png',
    desc:
        'Duyu Bütünleme Sorunları, beynin çevreden gelen duyusal bilgileri etkin biçimde organize edip yanıt vermesindeki yetersizliği ifade eder.',
    symptoms: [
      'Giysi dikişlerine veya etiketlere aşırı tepki',
      'Gürültülü ortamlarda panik',
      'Denge kaybı ve koordinasyon güçlüğü',
      'Aşırı duyusal arayışı',
      'Yeme güçlükleri',
      'Acıya veya sıcağa alışılmadık tepkiler',
      'Kalabalık ortamlarda aşırı stres',
    ],
    diagnosis:
        "Ergoterapi uzmanı tarafından 'Duyu Profili' veya SPM değerlendirmesi yapılır.",
    support: [
      'Duyusal entegrasyon terapisi',
      'Duyusal diyet planı',
      'Ağırlıklı yelek ve battaniye',
      'Ev ve okul ortamı düzenlemeleri',
      'Proprioseptif egzersizler',
      'Sosyal öykü ve duygusal düzenleme',
    ],
    faq: [
      FaqItem(
        'Duyu bütünleme sorunları otizmle aynı şey midir?',
        'Hayır. Ayrı bir tanıdır ve otizm olmaksızın da görülebilir.',
      ),
      FaqItem(
        'Ergoterapi ne zaman işe yarar?',
        'Erken başlanan ergoterapi en iyi sonuçları verir. Genellikle 6–12 ay içinde belirgin gelişme görülür.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'iletisim',
    name: 'İletişim Bozuklukları',
    icon: '💬',
    color: Color(0xFFE07A5F),
    bg: Color(0xFFFDF0EC),
    photo: 'assets/images/ileti_im_bozukluklar_.png',
    desc:
        "İletişim Bozuklukları, konuşma sesi bozuklukları, dil bozuklukları, sosyal iletişim bozukluğu ve kekemeliği kapsayan geniş bir tanı grubudur. Çocukların yaklaşık %8–9'u konuşma veya dil desteğine ihtiyaç duyar.",
    symptoms: [
      'Geç konuşma başlangıcı',
      'Konuşma seslerinin yanlış üretimi',
      'Kekeleme veya akıcılık bozukluğu',
      'Dili anlama güçlüğü',
      'Duygu ve düşünceleri söze dökememe',
      'Sosyal bağlamda uygun iletişim kuramama',
      'Sınırlı kelime dağarcığı',
    ],
    diagnosis:
        'Dil ve konuşma terapisti tarafından standart dil değerlendirme araçları kullanılır. Odiyolojik değerlendirme ve nörolojik muayene ek tanı araçlarıdır.',
    support: [
      'Bireysel dil ve konuşma terapisi',
      'AAC — PECS, cihazlar, işaret dili',
      'Aile rehberliği ve ev programları',
      'Dil zengini çevre oluşturma',
      'Akıcılık terapisi',
      'Grup terapisi',
      'Erken müdahale dil programları',
    ],
    faq: [
      FaqItem(
        'AAC cihazı kullanmak konuşmayı engellemez mi?',
        'Araştırmalar AAC doğal konuşmayı desteklediğini göstermektedir.',
      ),
      FaqItem(
        'Çocuğum 3 yaşında konuşmuyorsa ne yapmalıyım?',
        'En kısa sürede dil ve konuşma terapistine başvurun.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'nadir',
    name: 'Nadir Hastalıklar',
    icon: '🔬',
    color: Color(0xFF7C3AED),
    bg: Color(0xFFF0EEFF),
    photo: 'assets/images/nadir_hastal_klar.png',
    desc:
        "Dünyada 7.000'den fazla nadir hastalık tanımlanmıştır; her biri 200.000'den az kişiyi etkiler.",
    symptoms: [
      'Spina Bifida',
      'Rett Sendromu',
      'Angelman Sendromu',
      'Prader-Willi Sendromu',
      'PKU (Fenilketonüri)',
      'Fragile X Sendromu',
      'Duchenne Müsküler Distrofi',
      'Williams Sendromu',
      'CDKL5 Eksikliği',
      'Tuberous Sclerosis',
    ],
    diagnosis:
        'Tıbbi Genetik uzmanı tarafından kapsamlı genetik panel testleri ve klinik değerlendirme yapılır.',
    support: [
      'Tıbbi Genetik bölümleri',
      'nadir.org.tr',
      'Orphanet Türkiye',
      'NORD',
      'SGK Erişilemeyen İlaçlar birimi',
      'Hasta dernekleri',
    ],
    faq: [
      FaqItem(
        'Nadir hastalıkta nereye başvurmalıyım?',
        "Üniversite hastanelerinin Tıbbi Genetik bölümlerine başvurun. nadir.org.tr üzerinden uzman merkezlere ulaşabilirsiniz.",
      ),
      FaqItem(
        'SGK nadir hastalık ilaçlarını karşılar mı?',
        'Bazı ilaçlar özel onay süreciyle SGK tarafından karşılanabilir.',
      ),
    ],
  ),
];
