import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cvi_colors.dart';
import 'cvi_models.dart';
import 'cvi_results_store.dart';
import '../l10n/l10n_text.dart';

class CviResultsPage extends StatefulWidget {
  const CviResultsPage({super.key, required this.summary});

  final CviSessionSummary summary;

  @override
  State<CviResultsPage> createState() => _CviResultsPageState();
}

class _CviResultsPageState extends State<CviResultsPage> {
  bool _saving = true;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _persist();
  }

  Future<void> _persist() async {
    final ok = await CviResultsStore.saveSession(widget.summary);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saved = ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final clutterEntries = s.clutterTolerance.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final colorEntries = s.colorPreference.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Scaffold(
      backgroundColor: CviColors.bg,
      appBar: AppBar(
        backgroundColor: CviColors.card,
        foregroundColor: CviColors.text,
        elevation: 0,
        title: L10nText(
          'Egzersiz Özeti',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: CviColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CviColors.border),
              ),
              child: Column(
                children: [
                  L10nText(
                    '${s.percentage.toStringAsFixed(0)}%',
                    style: GoogleFonts.nunito(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: CviColors.primary,
                    ),
                  ),
                  L10nText(
                    '${s.correctCount} / ${s.totalSteps} doğru',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: CviColors.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  L10nText(
                    'Ortalama tepki: ${s.avgReactionMs} ms',
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      color: CviColors.muted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_saving)
                    L10nText(
                      'Sonuçlar kaydediliyor…',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: CviColors.muted,
                      ),
                    )
                  else
                    Text(
                      _saved
                          ? 'Sonuçlar hesabınıza kaydedildi.'
                          : 'Yerel özet gösteriliyor (kayıt için giriş gerekir).',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        color: CviColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Adım tepki süreleri',
              child: Column(
                children: [
                  for (final r in s.stepResults)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 56,
                            child: L10nText(
                              '#${r.stepId}',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                color: CviColors.text,
                              ),
                            ),
                          ),
                          Icon(
                            r.correct ? Icons.check_circle : Icons.cancel,
                            size: 18,
                            color: r.correct
                                ? CviColors.primary
                                : CviColors.warnFg,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: L10nText(
                              '${r.reactionMs} ms · karmaşa ${r.clutter}',
                              style: GoogleFonts.nunito(
                                color: CviColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Karmaşa toleransı',
              child: Column(
                children: [
                  for (final e in clutterEntries)
                    _BarRow(
                      label: 'Seviye ${e.key}',
                      value: e.value,
                    ),
                  if (clutterEntries.isEmpty)
                    L10nText(
                      'Veri yok',
                      style: GoogleFonts.nunito(color: CviColors.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Renk tercihi performansı',
              child: Column(
                children: [
                  for (final e in colorEntries)
                    _BarRow(
                      label: e.key,
                      value: e.value,
                      swatch: parseCviColor(e.key),
                    ),
                  if (colorEntries.isEmpty)
                    L10nText(
                      'Veri yok',
                      style: GoogleFonts.nunito(color: CviColors.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: CviColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: L10nText(
                  'Kapat',
                  style: GoogleFonts.nunito(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: CviColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: CviColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: CviColors.text,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({required this.label, required this.value, this.swatch});
  final String label;
  final double value;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0, 100) / 100.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (swatch != null) ...[
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: swatch,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: CviColors.border),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: CviColors.text,
                  ),
                ),
              ),
              L10nText(
                '${value.toStringAsFixed(0)}%',
                style: GoogleFonts.nunito(color: CviColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: CviColors.primarySoft,
              color: CviColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
