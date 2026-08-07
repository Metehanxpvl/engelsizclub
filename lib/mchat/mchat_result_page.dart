import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mchat_colors.dart';
import 'mchat_data.dart';
import 'mchat_guest_guard.dart';
import 'mchat_onboarding_page.dart';
import 'mchat_store.dart';
import '../l10n/l10n_text.dart';

/// Sonuç: risk seviyesi + uyarı + danışmanlık önerisi.
class MchatResultPage extends StatelessWidget {
  const MchatResultPage({
    super.key,
    required this.sonuc,
    required this.cevaplar,
    this.isGuest = false,
    this.onRequireLogin,
  });

  final MchatSonuc sonuc;
  final Map<int, String> cevaplar;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  Color get _badgeColor => switch (sonuc.seviye) {
        MchatRiskSeviye.yuksek => const Color(0xFFDC2626),
        MchatRiskSeviye.orta => const Color(0xFFD97706),
        MchatRiskSeviye.dusuk => const Color(0xFF059669),
      };

  Color get _badgeSoft => switch (sonuc.seviye) {
        MchatRiskSeviye.yuksek => const Color(0xFFFEE2E2),
        MchatRiskSeviye.orta => const Color(0xFFFEF3C7),
        MchatRiskSeviye.dusuk => const Color(0xFFD1FAE5),
      };

  Future<void> _restart(BuildContext context) async {
    await MchatStore.clearAnswers();
    if (!context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => MchatOnboardingPage(
          isGuest: isGuest,
          onRequireLogin: onRequireLogin,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MchatGuestGuard(
      isGuest: isGuest,
      onRequireLogin: onRequireLogin,
      child: Scaffold(
        backgroundColor: MchatColors.bg,
        appBar: AppBar(
          backgroundColor: MchatColors.card,
          foregroundColor: MchatColors.text,
          elevation: 0,
          title: L10nText(
            'Tarama Sonucu',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MchatColors.warnBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MchatColors.warnBorder, width: 1.5),
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: MchatColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: MchatColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _badgeSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        sonuc.baslik,
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _badgeColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    L10nText(
                      'Toplam risk: ${sonuc.toplamRisk}  ·  '
                      'Kritik madde: ${sonuc.kritikRisk}',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MchatColors.muted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      sonuc.aciklama,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        height: 1.45,
                        color: MchatColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MchatColors.primarySoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MchatColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.local_hospital_outlined,
                      color: _badgeColor,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        sonuc.oneri,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                          color: MchatColors.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => _restart(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MchatColors.primary,
                    side: const BorderSide(color: MchatColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: L10nText(
                    'Yeniden Tara',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
