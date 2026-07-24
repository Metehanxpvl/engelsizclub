import 'package:flutter/material.dart';

import '../data/rights_data.dart';
import '../meto_theme.dart';

/// Figma Make `HaklarTab` + `RightsSihirbazi` — Flutter portu.
class HaklarPage extends StatefulWidget {
  const HaklarPage({super.key});

  @override
  State<HaklarPage> createState() => _HaklarPageState();
}

class _HaklarPageState extends State<HaklarPage> {
  bool _showWizard = false;
  String _activeCategory = 'tümü';
  String? _expandedId;

  List<RightItem> get _filtered => _activeCategory == 'tümü'
      ? allRights
      : allRights.where((r) => r.category == _activeCategory).toList();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColoredBox(
          color: MetoColors.background,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Devlet Destekleri',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.foreground,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Yasal haklar, maaşlar ve başvuru rehberleri',
                      style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _WizardBanner(onStart: () => setState(() => _showWizard = true)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: rightsCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = rightsCategories[i];
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
                                    color: MetoColors.primary.withValues(alpha: 0.27),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
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
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        if (_showWizard)
          RightsSihirbazi(onClose: () => setState(() => _showWizard = false)),
      ],
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A6B4A), Color(0xFF1A5C51)],
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
                    child: const Icon(Icons.auto_fix_high, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hak Sorgulama Sihirbazı',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
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
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
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
  });

  final RightItem item;
  final bool expanded;
  final VoidCallback onTap;

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
                    child: Text(item.icon, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: MetoColors.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  ...item.desc.split('\n\n').map(
                    (para) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        para,
                        style: const TextStyle(
                          fontSize: 12,
                          color: MetoColors.mutedFg,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
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
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: item.color,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.steps[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: MetoColors.foreground.withValues(alpha: 0.8),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: item.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.description_outlined, size: 12, color: item.color),
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
            child: Text(
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

enum _WizardStep { yas, cozger, rate, age, income, results }

/// Hak sorgulama sihirbazı — tam akış (18 altı ÇÖZGER + 18 üstü oran/gelir).
class RightsSihirbazi extends StatefulWidget {
  const RightsSihirbazi({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  State<RightsSihirbazi> createState() => _RightsSihirbaziState();
}

class _RightsSihirbaziState extends State<RightsSihirbazi> {
  _WizardStep _step = _WizardStep.yas;
  String _yasGrubu = '';
  String _cozgerGrup = '';
  String _rate = '';
  String _age = '';
  String _income = '';

  int get _stepCount => _yasGrubu == '18alti' ? 3 : 4;

  int get _stepIndex {
    switch (_step) {
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
      case _WizardStep.results:
        return _stepCount - 1;
    }
  }

  List<RightItem> get _matchedRights => filterRights(
        yasGrubu: _yasGrubu,
        cozgerGrup: _cozgerGrup,
        rate: _rate,
        age: _age,
        income: _income,
      );

  void _reset() {
    setState(() {
      _step = _WizardStep.yas;
      _yasGrubu = '';
      _cozgerGrup = '';
      _rate = '';
      _age = '';
      _income = '';
    });
  }

  @override
  Widget build(BuildContext context) {
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
        : 'Hak Sorgulama Sihirbazı';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: const BoxDecoration(
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
                if (_step != _WizardStep.results) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(_stepCount, (i) {
                      return Expanded(
                        child: Container(
                          height: 6,
                          margin: EdgeInsets.only(right: i < _stepCount - 1 ? 6 : 0),
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
      case _WizardStep.results:
        return const SizedBox.shrink();
    }
  }

  Widget _buildResults() {
    final matched = _matchedRights;
    final cozger = findCozgerGrup(_cozgerGrup);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: MetoColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, size: 16, color: MetoColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${matched.length} hak bulundu — seçimlerinize göre filtrelendi',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_yasGrubu == '18alti' && cozger != null) ...[
          const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        ...matched.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _WizardResultCard(item: r),
            )),
        OutlinedButton.icon(
          onPressed: _reset,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            side: const BorderSide(color: MetoColors.border),
          ),
          icon: const Icon(Icons.refresh, size: 14),
          label: const Text(
            'Yeniden Sorgula',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _buildYasStep() {
    return Column(
      children: [
        const Text('🎂', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text(
          'Kaç yaşında?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
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
            _step = _yasGrubu == '18alti' ? _WizardStep.cozger : _WizardStep.rate;
          }),
        ),
      ],
    );
  }

  Widget _buildCozgerStep() {
    return Column(
      children: [
        const Text('📋', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text(
          'ÇÖZGER Rapor Grubu',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
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
          child: const Text(
            '18 yaş altında geleneksel engellilik oranı kaldırılmıştır. Yerine ÇÖZGER (Çocuklar İçin Özel Gereksinim Raporu) sistemi kullanılmaktadır.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B21A8), height: 1.5),
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
                onTap: () => setState(() => _cozgerGrup = g.range),
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
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
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
                                if (g.agir)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      'Ağır Engelli',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${g.label} (${g.kisa})',
                              style: const TextStyle(
                                fontSize: 12,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                          ],
                        ),
                      ),
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
        const Text('📊', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text(
          'Engel oranı nedir?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
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
        const Text('🎈', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text(
          'Çocuğun yaşı?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
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
          label: 'Haklarımı Göster',
          onPressed: () => setState(() => _step = _WizardStep.results),
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
        const Text('💰', style: TextStyle(fontSize: 48)),
        const SizedBox(height: 12),
        const Text(
          'Hane kişi başı gelir?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
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
          label: 'Haklarımı Göster',
          onPressed: () => setState(() => _step = _WizardStep.results),
        ),
      ],
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
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
        border: Border.all(color: selected ? color : MetoColors.muted, width: 2),
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
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
  const _WizardResultCard({required this.item});

  final RightItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
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
                child: Text(item.icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
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
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.desc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(item.steps.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: item.color,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.steps[i],
                      style: const TextStyle(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: item.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.description_outlined, size: 11, color: item.color),
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
        ],
      ),
    );
  }
}
