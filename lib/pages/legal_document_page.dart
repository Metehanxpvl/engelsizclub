import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../legal/legal_texts.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';

/// Kullanım Koşulları / Gizlilik / Sorumluluk Reddi okuma sayfası.
class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({
    super.key,
    required this.kind,
    this.showAcceptButton = false,
    this.onAccepted,
  });

  final LegalDocKind kind;
  final bool showAcceptButton;
  final VoidCallback? onAccepted;

  static Future<T?> open<T>(
    BuildContext context,
    LegalDocKind kind, {
    bool showAcceptButton = false,
  }) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(
        builder: (_) => LegalDocumentPage(
          kind: kind,
          showAcceptButton: showAcceptButton,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = legalDocumentBody(kind);
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: L10nText(
          kind.titleTr,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: MetoColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: MetoColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: MetoColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              switch (kind) {
                                LegalDocKind.terms => Icons.gavel_outlined,
                                LegalDocKind.privacy => Icons.privacy_tip_outlined,
                                LegalDocKind.disclaimer => Icons.health_and_safety_outlined,
                              },
                              color: MetoColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                L10nText(
                                  kind.titleTr,
                                  style: GoogleFonts.nunito(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: MetoColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                L10nText(
                                  kind.subtitleTr,
                                  style: GoogleFonts.nunito(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: MetoColors.mutedFg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (kind == LegalDocKind.disclaimer) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF7ED),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDBA74)),
                          ),
                          child: L10nText(
                            kDisclaimerSummaryTr,
                            style: GoogleFonts.nunito(
                              fontSize: 13.5,
                              height: 1.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF9A3412),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SelectableText(
                        body,
                        style: GoogleFonts.nunito(
                          fontSize: 13.5,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                          color: MetoColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showAcceptButton)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      onAccepted?.call();
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(true);
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: MetoColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: L10nText(
                      'Anladım',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
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
