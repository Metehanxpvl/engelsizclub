import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../legal/legal_texts.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import 'legal_document_page.dart';

/// Platform sorumluluk reddi — [LegalDocumentPage] üzerinden yayınlanır.
class TibbiSorumlulukReddiPage extends StatelessWidget {
  const TibbiSorumlulukReddiPage({
    super.key,
    this.showAcceptButton = true,
    this.onAccepted,
  });

  final bool showAcceptButton;
  final VoidCallback? onAccepted;

  @override
  Widget build(BuildContext context) {
    return LegalDocumentPage(
      kind: LegalDocKind.disclaimer,
      showAcceptButton: showAcceptButton,
      onAccepted: onAccepted,
    );
  }
}

/// İlk açılış / giriş sonrası kısa sorumluluk uyarısı.
Future<void> showMedicalWelcomeDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        backgroundColor: MetoColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MetoColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.health_and_safety_outlined,
                color: MetoColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: L10nText(
                'Sorumluluk Reddi',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: L10nText(
            kDisclaimerSummaryTr,
            style: GoogleFonts.nunito(
              fontSize: 14,
              height: 1.5,
              color: MetoColors.mutedFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              LegalDocumentPage.open(context, LegalDocKind.disclaimer);
            },
            child: L10nText(
              'Tam metin',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: MetoColors.primary,
              foregroundColor: Colors.white,
            ),
            child: L10nText(
              'Kabul Ediyorum',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      );
    },
  );
}
