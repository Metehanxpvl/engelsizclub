import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mchat_colors.dart';
import '../l10n/l10n_text.dart';

/// Basit gizlilik politikası — veri toplamıyoruz.
class MchatPrivacyPage extends StatelessWidget {
  const MchatPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MchatColors.bg,
      appBar: AppBar(
        backgroundColor: MchatColors.card,
        foregroundColor: MchatColors.text,
        elevation: 0,
        title: L10nText(
          'Gizlilik',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MchatColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: MchatColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                L10nText(
                  'Gizlilik Politikası (Tarama)',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: MchatColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                L10nText(
                  'Otizm tarama modülü cevaplarınızı toplamaz, sunucuya '
                  'göndermez ve üçüncü taraflarla paylaşmaz.',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    height: 1.45,
                    color: MchatColors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                L10nText(
                  'Cevaplar yalnızca sizin cihazınızda (yerel depolama) tutulur. '
                  'PDF dışa aktarma da cihazınızda yapılır.',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    height: 1.45,
                    color: MchatColors.muted,
                  ),
                ),
                const SizedBox(height: 12),
                L10nText(
                  'Uygulamayı silerseniz veya tarayıcı verilerini temizlerseniz '
                  'bu kayıtlar da silinir.',
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    height: 1.45,
                    color: MchatColors.muted,
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
