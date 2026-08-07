import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../guest_limit_store.dart';
import 'cvi_disclaimer_page.dart';
import '../l10n/l10n_text.dart';

/// Daha Fazlası menüsünden CVI egzersizini açar.
Future<void> openCviFlow(
  BuildContext context, {
  bool isGuest = false,
  VoidCallback? onRequireLogin,
}) async {
  if (isGuest) {
    final ok = await GuestLimitStore.allowTimedTab('cvi');
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: L10nText(
            'Misafir CVI egzersiz süresi doldu (1 dk). Devam etmek için üye olun.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      onRequireLogin?.call();
      return;
    }
    final left = await GuestLimitStore.remainingTimedSeconds('cvi');
    if (context.mounted && left > 0) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            left >= 60
                ? 'Misafir erişimi: yaklaşık 1 dk.'
                : 'Misafir erişimi: yaklaşık $left sn.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CviDisclaimerPage(
        isGuest: isGuest,
        onRequireLogin: onRequireLogin,
      ),
    ),
  );
}

/// İsteğe bağlı kısa bilgi chip'i.
Widget cviMenuSubtitle() {
  return L10nText(
    '20 adımlık yüksek kontrastlı görsel egzersiz',
    style: GoogleFonts.nunito(fontSize: 12),
  );
}
