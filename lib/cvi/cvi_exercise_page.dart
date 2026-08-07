import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'cvi_colors.dart';
import 'cvi_models.dart';
import 'cvi_results_page.dart';
import 'cvi_session.dart';
import 'cvi_shape_painter.dart';
import '../l10n/l10n_text.dart';

class CviExercisePage extends StatefulWidget {
  const CviExercisePage({
    super.key,
    required this.config,
    this.isGuest = false,
    this.onRequireLogin,
  });

  final CviConfig config;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<CviExercisePage> createState() => _CviExercisePageState();
}

class _CviExercisePageState extends State<CviExercisePage> {
  late final CviSessionController _session;
  late List<CviOption> _shuffled;
  final _rng = math.Random();
  String? _flash; // 'ok' | 'miss'

  @override
  void initState() {
    super.initState();
    _session = CviSessionController(widget.config);
    _prepareStep();
  }

  void _prepareStep() {
    if (_session.isComplete) return;
    final opts = List<CviOption>.from(_session.current.options);
    opts.shuffle(_rng);
    _shuffled = opts;
    _flash = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _session.startStepTimer();
    });
  }

  Future<void> _onTapOption(int index) async {
    if (_session.locked || _session.isComplete) return;
    if (index < 0 || index >= _shuffled.length) return;

    final correct = _shuffled[index].correct;
    HapticFeedback.selectionClick();
    _session.recordTap(correct: correct);
    setState(() => _flash = correct ? 'ok' : 'miss');

    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (!mounted) return;

    if (_session.isComplete) {
      final summary = _session.buildSummary();
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => CviResultsPage(summary: summary),
        ),
      );
      return;
    }

    setState(_prepareStep);
  }

  @override
  Widget build(BuildContext context) {
    final step = _session.isComplete ? null : _session.current;
    final progress = _session.results.length;
    final total = _session.totalSteps;

    return Scaffold(
      backgroundColor: CviColors.stageBlack,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: L10nText(
          'Adım ${math.min(progress + 1, total)} / $total',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (widget.config.fromOfflineFallback)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: L10nText(
                  'Çevrimdışı',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: step == null
          ? const SizedBox.shrink()
          : SafeArea(
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: total == 0 ? 0 : progress / total,
                    backgroundColor: Colors.white12,
                    color: CviColors.primary,
                    minHeight: 4,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: L10nText(
                      step.prompt,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  L10nText(
                    'Karmaşa seviyesi: ${step.clutter}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      color: Colors.white54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        final layout = cviLayoutForCount(size, _shuffled.length);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (d) {
                            final hit = cviHitTest(
                              local: d.localPosition,
                              size: size,
                              layout: layout,
                            );
                            if (hit != null) _onTapOption(hit);
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: CviShapePainter(
                                  options: _shuffled,
                                  layout: layout,
                                ),
                                size: size,
                              ),
                              if (_flash != null)
                                ColoredBox(
                                  color: (_flash == 'ok'
                                          ? const Color(0xFF00C853)
                                          : const Color(0xFFFF1744))
                                      .withValues(alpha: 0.18),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: L10nText(
                      'Hedef şekle dokunun',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
