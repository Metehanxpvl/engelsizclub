import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../legal/legal_texts.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../pages/legal_document_page.dart';

const ugcTermsAcceptedKey = 'ugc_terms_v2_accepted';

/// Forum / ilan gibi UGC paylaşımından önce koşul onayı.
Future<bool> ensureUgcTermsAccepted(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(ugcTermsAcceptedKey) == true) return true;
  if (!context.mounted) return false;

  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const L10nText('Topluluk kuralları'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const L10nText(
              kUgcPolicySummaryTr,
              style: TextStyle(fontSize: 13, height: 1.45, color: MetoColors.mutedFg),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => LegalDocumentPage.open(ctx, LegalDocKind.terms),
              child: const Text(
                'Kullanım Koşulları’nın tamamını oku',
                style: TextStyle(
                  color: MetoColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const L10nText('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: MetoColors.primary),
          child: const L10nText('Kabul ediyorum'),
        ),
      ],
    ),
  );

  if (accepted == true) {
    await prefs.setBool(ugcTermsAcceptedKey, true);
    return true;
  }
  return false;
}
