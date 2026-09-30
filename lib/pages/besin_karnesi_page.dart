import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../nutrition/food_catalog.dart';
import '../nutrition/nutrient_references.dart';
import '../nutrition/nutrition_analyzer.dart';
import '../nutrition/nutrition_types.dart';

class BesinKarnesiPage extends StatefulWidget {
  const BesinKarnesiPage({super.key, required this.userEmail});

  final String userEmail;

  static Future<void> open(
    BuildContext context, {
    required String userEmail,
  }) async {
    if (userEmail.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: L10nText(
              'Vitamin karnesi için giriş yapmanız veya üye olmanız gerekiyor.',
            ),
          ),
        );
      }
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BesinKarnesiPage(userEmail: userEmail),
      ),
    );
  }

  @override
  State<BesinKarnesiPage> createState() => _BesinKarnesiPageState();
}

class _BesinKarnesiPageState extends State<BesinKarnesiPage> {
  final _input = TextEditingController();
  NutritionAgeBand _ageBand = NutritionAgeBand.y19to50;
  NutritionSex _sex = NutritionSex.male;
  bool _busy = false;
  NutritionAnalysis? _result;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    if (_busy) return;
    setState(() => _busy = true);
    final started = DateTime.now();
    try {
      final analysis = analyzeNutrition(
        _input.text,
        DateTime.now(),
        profile: NutritionUserProfile(ageBand: _ageBand, sex: _sex),
      );
      const minMs = 1700;
      final wait = minMs - DateTime.now().difference(started).inMilliseconds;
      if (wait > 0) {
        await Future<void>.delayed(Duration(milliseconds: wait));
      }
      if (!mounted) return;
      setState(() {
        _result = analysis;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    }
  }

  void _reset() {
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: L10nText(
          'Günlük Besin Analizi',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          _result == null ? _buildInput() : _buildResult(_result!),
          if (_busy) const _BesinAnalizLoading(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        L10nText(
          'Bugün tükettiğin yiyecek ve içecekleri tek seferde yaz, günlük vitamin ve mineral karneni çıkaralım.',
          style: GoogleFonts.nunito(
            fontSize: 14,
            height: 1.45,
            color: MetoColors.mutedFg,
          ),
        ),
        const SizedBox(height: 16),
        L10nText(
          'Yaş grubu',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final band in NutritionAgeBand.values)
              _ChoiceChip(
                label: band.labelTr,
                selected: _ageBand == band,
                enabled: !_busy,
                onTap: () => setState(() => _ageBand = band),
              ),
          ],
        ),
        if (_ageBand.needsSex) ...[
          const SizedBox(height: 16),
          L10nText(
            'Cinsiyet',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ChoiceChip(
                  label: 'Erkek',
                  selected: _sex == NutritionSex.male,
                  enabled: !_busy,
                  expand: true,
                  onTap: () => setState(() => _sex = NutritionSex.male),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChoiceChip(
                  label: 'Kadın',
                  selected: _sex == NutritionSex.female,
                  enabled: !_busy,
                  expand: true,
                  onTap: () => setState(() => _sex = NutritionSex.female),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        L10nText(
          'Bugün ne yedin?',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: 'Bugün ne yedin?',
          textField: true,
          child: TextField(
            controller: _input,
            minLines: 7,
            maxLines: 12,
            enabled: !_busy,
            textInputAction: TextInputAction.newline,
            style: GoogleFonts.nunito(fontSize: 15, height: 1.4),
            decoration: InputDecoration(
              filled: true,
              fillColor: MetoColors.card,
              hintText:
                  'Örn: sucuk, 2 yumurta, peynir, et, salata, sebze, çay, filtre kahve, maden suyu...',
              hintStyle: GoogleFonts.nunito(
                color: MetoColors.mutedFg,
                fontSize: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MetoColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MetoColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: MetoColors.primary),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _analyze,
          style: FilledButton.styleFrom(
            backgroundColor: MetoColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : L10nText(
                  'Karnemi Çıkar 🚀',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildResult(NutritionAnalysis analysis) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              children: [
                L10nText(
                  'Günün Mikro Besin Özeti',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                L10nText(
                  analysis.profile.labelTr,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: MetoColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      L10nText(
                        'Yaklaşık karşılama  %${analysis.overallFillPercent.round()}',
                        style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      L10nText(
                        '${analysis.inRangeCount} / ${analysis.nutrientCount} hedef aralıkta  ·  ${analysis.balanceLabel}',
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: MetoColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 4),
                      L10nText(
                        'Yaklaşık ortalama; tıbbi skor değildir.',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          height: 1.35,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                L10nText(
                  'Analiz güveni: ${analysis.confidence.labelTr}',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: MetoColors.selectedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MetoColors.border),
                  ),
                  child: L10nText(
                    'Yaklaşık hesaplamadır; laboratuvar veya tıbbi sonuç değildir.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      height: 1.4,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const _PercentColorLegend(),
                const SizedBox(height: 16),
                TabBar(
                  labelColor: MetoColors.primary,
                  unselectedLabelColor: MetoColors.mutedFg,
                  indicatorColor: MetoColors.primary,
                  labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  tabs: const [
                    Tab(text: 'Vitaminler'),
                    Tab(text: 'Mineraller'),
                  ],
                ),
                const SizedBox(height: 4),
                L10nText(
                  'Çubuğa dokun: o besini içeren gıdalar.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: TabBarView(
                    children: [
                      _NutrientBars(
                        analysis: analysis,
                        stats: [
                          for (final k in NutrientKey.values)
                            if (k.group == NutrientGroup.vitamin)
                              analysis.nutrients[k]!,
                        ],
                      ),
                      _NutrientBars(
                        analysis: analysis,
                        stats: [
                          for (final k in NutrientKey.values)
                            if (k.group == NutrientGroup.mineral)
                              analysis.nutrients[k]!,
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                L10nText(
                  'Eksiği kapatmaya yardımcı kaynaklar',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                for (final s in analysis.lowest())
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
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
                            '${s.key.labelTr}  ·  ${s.referenceType.labelTr}  ·  %${s.percentage.round()}',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          L10nText(
                            '${s.key.labelTr} açısından zengin besin kaynakları: ${kNutrientFoodSources[s.key]}',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              height: 1.4,
                              color: MetoColors.mutedFg,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                L10nText(
                  '${analysis.analyzedFoods.length} gıda analiz edildi.',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
                if (analysis.unknownTokens.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  L10nText(
                    '${analysis.unknownTokens.length} ifade tanınamadı.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ],
                if (analysis.analyzedFoods.any((e) => !e.portionSpecified)) ...[
                  const SizedBox(height: 4),
                  L10nText(
                    'Porsiyon belirtilmeyenler standart porsiyon üzerinden yaklaşık hesaplandı.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                for (final f in analysis.analyzedFoods)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      f.displayLine,
                      style: GoogleFonts.nunito(fontSize: 14),
                    ),
                  ),
                if (analysis.unknownTokens.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  L10nText(
                    'Tanınmayan: ${analysis.unknownTokens.join(', ')}',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                L10nText(
                  'Bu sonuçlar girilen yiyecek ve porsiyon bilgilerinden yapılan yaklaşık hesaplamadır.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MetoColors.primary,
                    side: const BorderSide(color: MetoColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: L10nText(
                    'Düzenle',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: enabled ? onTap : null,
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: selected ? MetoColors.primary : MetoColors.card,
        foregroundColor: selected ? Colors.white : MetoColors.foreground,
        side: BorderSide(
          color: selected ? MetoColors.primary : MetoColors.border,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: L10nText(
        label,
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

class _PercentColorLegend extends StatelessWidget {
  const _PercentColorLegend();

  static const _cells = <(NutritionBand, String, String, bool)>[
    (NutritionBand.low, '%0–49', 'Kritik Eksik', false),
    (NutritionBand.mid, '%50–79', 'Geliştirilmeli', false),
    (NutritionBand.target, '%80–120', 'İdeal Hedef', true),
    (NutritionBand.high, '%150+', 'Yüksek Alım', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          L10nText(
            'Renk skalası',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _LegendTile.fromCell(_cells[0])),
              const SizedBox(width: 8),
              Expanded(child: _LegendTile.fromCell(_cells[1])),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _LegendTile.fromCell(_cells[2])),
              const SizedBox(width: 8),
              Expanded(child: _LegendTile.fromCell(_cells[3])),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendTile extends StatelessWidget {
  const _LegendTile({
    required this.band,
    required this.range,
    required this.label,
    required this.ideal,
  });

  factory _LegendTile.fromCell((NutritionBand, String, String, bool) cell) {
    return _LegendTile(
      band: cell.$1,
      range: cell.$2,
      label: cell.$3,
      ideal: cell.$4,
    );
  }

  final NutritionBand band;
  final String range;
  final String label;
  final bool ideal;

  @override
  Widget build(BuildContext context) {
    final color = nutritionBarColorForBand(band);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 6),
              L10nText(
                range,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (ideal) ...[
                const SizedBox(width: 4),
                Icon(Icons.check_circle, size: 13, color: color),
              ],
            ],
          ),
          const SizedBox(height: 6),
          L10nText(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.2,
              color: MetoColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientBars extends StatelessWidget {
  const _NutrientBars({required this.stats, required this.analysis});

  final List<NutrientStat> stats;
  final NutritionAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: stats.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, i) => _Bar(
        stat: stats[i],
        analysis: analysis,
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.stat, required this.analysis});

  final NutrientStat stat;
  final NutritionAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final pct = stat.percentage.clamp(0, 180).toDouble();
    final h = (pct / 180) * 140;
    final color = nutritionBarColor(stat.percentage);
    return SizedBox(
      width: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showNutrientFoodsSheet(
            context,
            stat: stat,
            analysis: analysis,
          ),
          child: Column(
            children: [
              Text(
                '%${stat.percentage.round()}',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (stat.inTargetBand)
                const Icon(Icons.check, size: 12, color: MetoColors.primary),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: h),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return Container(
                        width: 22,
                        height: value.clamp(4, 140),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                stat.key.shortLabelTr,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showNutrientFoodsSheet(
  BuildContext context, {
  required NutrientStat stat,
  required NutritionAnalysis analysis,
}) {
  final band = nutritionBand(stat.percentage);
  final today = todayFoodsForNutrient(analysis.analyzedFoods, stat.key);
  final catalog = catalogFoodsForNutrient(stat.key);
  final sources = kNutrientFoodSources[stat.key] ?? '';
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: MetoColors.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: MetoColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                L10nText(
                  '${stat.key.labelTr}  ·  ${stat.referenceType.labelTr}',
                  style: GoogleFonts.nunito(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                L10nText(
                  '%${stat.percentage.round()}  ·  ${band.labelTr}  ·  ${band.rangeTr}',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: nutritionBarColor(stat.percentage),
                  ),
                ),
                const SizedBox(height: 8),
                L10nText(
                  band.meaningTr,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    height: 1.4,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 6),
                L10nText(
                  'Alım: ${stat.intake.toStringAsFixed(stat.intake >= 10 ? 0 : 1)} ${stat.unit}  ·  referans: ${stat.target.toStringAsFixed(stat.target >= 10 ? 0 : 1)} ${stat.unit}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 16),
                L10nText(
                  'Bugün yazdığın ve bunu içerenler',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                if (today.isEmpty)
                  L10nText(
                    'Bugünkü listede bu besini ölçülebilir miktarda içeren bir gıda bulunamadı.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: MetoColors.mutedFg,
                    ),
                  )
                else
                  for (final hit in today)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: L10nText(
                        '${hit.food.displayLine}  ·  ~${hit.amount.toStringAsFixed(hit.amount >= 10 ? 0 : 1)} ${stat.unit}',
                        style: GoogleFonts.nunito(fontSize: 14, height: 1.35),
                      ),
                    ),
                const SizedBox(height: 14),
                L10nText(
                  '${stat.key.labelTr} içeren gıdalar',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                if (sources.isNotEmpty)
                  L10nText(
                    sources,
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      height: 1.4,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                const SizedBox(height: 10),
                for (final food in catalog)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: L10nText(
                      '${food.emoji} ${food.labelTr}',
                      style: GoogleFonts.nunito(fontSize: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _BesinAnalizLoading extends StatefulWidget {
  const _BesinAnalizLoading();

  @override
  State<_BesinAnalizLoading> createState() => _BesinAnalizLoadingState();
}

class _BesinAnalizLoadingState extends State<_BesinAnalizLoading>
    with TickerProviderStateMixin {
  late final AnimationController _spin;
  late final AnimationController _pulse;
  late final AnimationController _dots;

  static const _orbitIcons = <IconData>[
    Icons.spa_outlined,
    Icons.water_drop_outlined,
    Icons.eco_outlined,
    Icons.local_dining_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..repeat();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _spin.dispose();
    _pulse.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: ColoredBox(
        color: MetoColors.background.withValues(alpha: 0.94),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 210,
                  height: 210,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_spin, _pulse]),
                    builder: (context, child) {
                      final pulse = 0.94 + (_pulse.value * 0.08);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.scale(
                            scale: 1 + _pulse.value * 0.16,
                            child: Container(
                              width: 168,
                              height: 168,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: MetoColors.primary.withValues(alpha: 0.07),
                              ),
                            ),
                          ),
                          Transform.scale(
                            scale: 1 + (1 - _pulse.value) * 0.1,
                            child: Container(
                              width: 126,
                              height: 126,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: MetoColors.primary.withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                          Transform.rotate(
                            angle: _spin.value * math.pi * 2,
                            child: SizedBox(
                              width: 188,
                              height: 188,
                              child: Stack(
                                children: [
                                  for (var i = 0; i < _orbitIcons.length; i++)
                                    Align(
                                      alignment: Alignment(
                                        math.cos(i * math.pi / 2),
                                        math.sin(i * math.pi / 2),
                                      ),
                                      child: _OrbitChip(icon: _orbitIcons[i]),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Transform.scale(scale: pulse, child: child),
                        ],
                      );
                    },
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: MetoColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: MetoColors.primary.withValues(alpha: 0.18),
                            blurRadius: 22,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.restaurant_outlined,
                        size: 42,
                        color: MetoColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedBuilder(
                  animation: _dots,
                  builder: (context, child) {
                    final n = (_dots.value * 3).floor() % 3 + 1;
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        child!,
                        Text(
                          List.filled(n, '.').join(),
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                      ],
                    );
                  },
                  child: L10nText(
                    'Analiz ediliyor',
                    style: GoogleFonts.nunito(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                L10nText(
                  'Öğünlerin vitamin ve minerallere bakılıyor',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    height: 1.4,
                    color: MetoColors.mutedFg,
                  ),
                ),
                const SizedBox(height: 22),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: SizedBox(
                    width: 196,
                    height: 7,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1650),
                      curve: Curves.easeInOut,
                      builder: (context, t, _) {
                        return LinearProgressIndicator(
                          value: t,
                          minHeight: 7,
                          backgroundColor: MetoColors.muted,
                          color: MetoColors.primary,
                        );
                      },
                    ),
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

class _OrbitChip extends StatelessWidget {
  const _OrbitChip({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: MetoColors.border),
        boxShadow: [
          BoxShadow(
            color: MetoColors.primary.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: MetoColors.primary),
    );
  }
}

Color nutritionBarColorForBand(NutritionBand band) {
  return switch (band) {
    NutritionBand.low => const Color(0xFFC45C26),
    NutritionBand.mid => MetoColors.accentGold,
    NutritionBand.target => MetoColors.primary,
    NutritionBand.above => MetoColors.primaryDark,
    NutritionBand.high => const Color(0xFF2563EB),
  };
}

Color nutritionBarColor(double percentage) {
  return nutritionBarColorForBand(nutritionBand(percentage));
}
