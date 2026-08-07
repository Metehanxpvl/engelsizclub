import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mchat_colors.dart';
import 'mchat_guest_guard.dart';
import 'mchat_privacy_page.dart';
import 'mchat_quiz_page.dart';
import 'mchat_store.dart';
import '../l10n/l10n_text.dart';

/// Sorumluluk reddi — kabul etmeden ankete geçilemez.
class MchatOnboardingPage extends StatefulWidget {
  const MchatOnboardingPage({
    super.key,
    this.isGuest = false,
    this.onRequireLogin,
  });

  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<MchatOnboardingPage> createState() => _MchatOnboardingPageState();
}

class _MchatOnboardingPageState extends State<MchatOnboardingPage> {
  bool _busy = false;

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    await MchatStore.acceptDisclaimer();
    if (!mounted) return;
    await MchatStore.clearAnswers();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MchatQuizPage(
          isGuest: widget.isGuest,
          onRequireLogin: widget.onRequireLogin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            'Otizm Tarama',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const MchatPrivacyPage(),
                  ),
                );
              },
              child: const L10nText('Gizlilik'),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: MchatColors.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: MchatColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: MchatColors.primarySoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.health_and_safety_outlined,
                              color: MchatColors.primary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 16),
                          L10nText(
                            'Sorumluluk Reddi',
                            style: GoogleFonts.nunito(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: MchatColors.text,
                            ),
                          ),
                          const SizedBox(height: 12),
                          L10nText(
                            'Bu otizm tarama aracı (M-CHAT-R tarzı) yalnızca '
                            'bilgilendirme ve erken farkındalık amaçlıdır.',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              height: 1.45,
                              color: MchatColors.muted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _Bullet(
                            'Klinik tanı koymaz, uzman yerine geçmez.',
                          ),
                          const _Bullet(
                            'Sonuçlar risk tahmini verir; tıbbi karar değildir.',
                          ),
                          const _Bullet(
                            'Endişeniz varsa çocuk doktoru / gelişim uzmanına danışın.',
                          ),
                          const _Bullet(
                            'Cevaplarınız yalnızca cihazınızda saklanır.',
                          ),
                          if (widget.isGuest) ...[
                            const SizedBox(height: 12),
                            const _Bullet(
                              'Misafir olarak tarama süresi 1 dakikadır.',
                            ),
                          ],
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: MchatColors.warnBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: MchatColors.warnBorder),
                            ),
                            child: L10nText(
                              'Bu uygulama tanı koymaz. Sadece tarama amaçlıdır.',
                              style: GoogleFonts.nunito(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: MchatColors.warnFg,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: _busy ? null : _accept,
                    style: FilledButton.styleFrom(
                      backgroundColor: MchatColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
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
                            'Kabul Ediyorum',
                            style: GoogleFonts.nunito(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MchatColors.muted,
                      side: const BorderSide(color: MchatColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: L10nText(
                      'Vazgeç',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Icon(
              Icons.check_circle,
              size: 18,
              color: MchatColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.nunito(
                fontSize: 15,
                height: 1.4,
                color: MchatColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
