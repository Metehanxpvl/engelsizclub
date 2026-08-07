import 'package:flutter/material.dart';

import '../guest_limit_store.dart';
import 'mchat_onboarding_page.dart';
import '../l10n/l10n_text.dart';

/// Daha Fazlası menüsünden M-CHAT taramasını açar.
/// Her açılışta yasal sorumluluk reddi gösterilir.
/// Misafir: 1 dakika.
Future<void> openMchatFlow(
  BuildContext context, {
  bool isGuest = false,
  VoidCallback? onRequireLogin,
}) async {
  if (isGuest) {
    final ok = await GuestLimitStore.allowTimedTab('mchat');
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: L10nText(
            'Misafir otizm tarama süresi doldu (1 dk). Devam etmek için üye olun.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      onRequireLogin?.call();
      return;
    }
    final left = await GuestLimitStore.remainingTimedSeconds('mchat');
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
      builder: (_) => MchatOnboardingPage(
        isGuest: isGuest,
        onRequireLogin: onRequireLogin,
      ),
    ),
  );
}
