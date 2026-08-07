import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mchat_colors.dart';
import 'mchat_data.dart';
import 'mchat_guest_guard.dart';
import 'mchat_result_page.dart';
import 'mchat_store.dart';
import '../l10n/l10n_text.dart';

/// 20 soruluk anket — tek ekranda 1 soru, swipe + ileri/geri.
class MchatQuizPage extends StatefulWidget {
  const MchatQuizPage({
    super.key,
    this.isGuest = false,
    this.onRequireLogin,
  });

  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<MchatQuizPage> createState() => _MchatQuizPageState();
}

class _MchatQuizPageState extends State<MchatQuizPage> {
  final _pageController = PageController();
  Map<int, String> _cevaplar = {};
  int _index = 0;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final answers = await MchatStore.loadAnswers();
    final idx = await MchatStore.loadQuestionIndex();
    if (!mounted) return;
    setState(() {
      _cevaplar = Map<int, String>.from(answers);
      _index = idx;
      _ready = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_index);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _select(String value) async {
    final soru = mchatSorular[_index];
    setState(() => _cevaplar[soru.id] = value);
    await MchatStore.saveAnswer(soru.id, value);

    // Otomatik sonraki soruya geç (kısa gecikme ile görsel geri bildirim)
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    if (_index < mchatSorular.length - 1) {
      await _goTo(_index + 1);
    } else {
      await _finish();
    }
  }

  Future<void> _goTo(int i) async {
    final next = i.clamp(0, mchatSorular.length - 1);
    setState(() => _index = next);
    await MchatStore.saveQuestionIndex(next);
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    // Tüm sorular yanıtlandı mı?
    final eksik = mchatSorular.any((s) => !_cevaplar.containsKey(s.id));
    if (eksik) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Lütfen tüm soruları yanıtlayın.')),
      );
      // İlk boş soruya git
      final firstEmpty = mchatSorular.indexWhere((s) => !_cevaplar.containsKey(s.id));
      if (firstEmpty >= 0) await _goTo(firstEmpty);
      return;
    }
    final sonuc = hesaplaMchatSonuc(_cevaplar);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MchatResultPage(
          sonuc: sonuc,
          cevaplar: Map<int, String>.from(_cevaplar),
          isGuest: widget.isGuest,
          onRequireLogin: widget.onRequireLogin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: MchatColors.bg,
        body: Center(child: CircularProgressIndicator(color: MchatColors.primary)),
      );
    }

    final progress = (_index + 1) / mchatSorular.length;

    return MchatGuestGuard(
      isGuest: widget.isGuest,
      onRequireLogin: widget.onRequireLogin,
      child: Scaffold(
      backgroundColor: MchatColors.bg,
      appBar: AppBar(
        backgroundColor: MchatColors.card,
        foregroundColor: MchatColors.text,
        elevation: 0,
        title: L10nText(
          'Tarama (${_index + 1}/${mchatSorular.length})',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: MchatColors.border,
                      color: MchatColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  L10nText(
                    'Soru ${_index + 1} / ${mchatSorular.length}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MchatColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: mchatSorular.length,
                onPageChanged: (i) async {
                  setState(() => _index = i);
                  await MchatStore.saveQuestionIndex(i);
                },
                itemBuilder: (context, i) {
                  final soru = mchatSorular[i];
                  final secili = _cevaplar[soru.id];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: MchatColors.card,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: MchatColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (soru.kritik)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3CD),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: L10nText(
                                      'Kritik madde',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF856404),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: Center(
                                    child: L10nText(
                                      soru.soru,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.nunito(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        height: 1.35,
                                        color: MchatColors.text,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Büyük Evet / Hayır
                        _BigAnswerButton(
                          label: 'Evet',
                          selected: secili == 'Evet',
                          color: MchatColors.yes,
                          soft: MchatColors.yesSoft,
                          onTap: () => _select('Evet'),
                        ),
                        const SizedBox(height: 12),
                        _BigAnswerButton(
                          label: 'Hayır',
                          selected: secili == 'Hayır',
                          color: MchatColors.no,
                          soft: MchatColors.noSoft,
                          onTap: () => _select('Hayır'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // İleri / Geri
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _index == 0 ? null : () => _goTo(_index - 1),
                      icon: const Icon(Icons.chevron_left),
                      label: L10nText(
                        'Geri',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: MchatColors.primary,
                        side: const BorderSide(color: MchatColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        if (_index < mchatSorular.length - 1) {
                          _goTo(_index + 1);
                        } else {
                          _finish();
                        }
                      },
                      icon: Icon(
                        _index < mchatSorular.length - 1
                            ? Icons.chevron_right
                            : Icons.check,
                      ),
                      label: Text(
                        _index < mchatSorular.length - 1 ? 'İleri' : 'Sonuç',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: MchatColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
    ),
    );
  }
}

class _BigAnswerButton extends StatelessWidget {
  const _BigAnswerButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.soft,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final Color soft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: Material(
        color: selected ? color : soft,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: L10nText(
              label,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
