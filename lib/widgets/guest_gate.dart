import 'package:flutter/material.dart';

import '../guest_limit_store.dart';
import '../l10n/app_strings.dart';

/// Misafirse üyelik ekranına yönlendirir. Üyeyse true döner.
Future<bool> ensureMemberAccess(
  BuildContext context, {
  required bool isGuest,
  required VoidCallback onRequireLogin,
  String? message,
}) async {
  if (!isGuest) return true;
  if (!context.mounted) {
    onRequireLogin();
    return false;
  }
  final msg = message ??
      S.auto('Bu işlem için giriş yapmanız veya üye olmanız gerekiyor.');
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      action: SnackBarAction(
        label: S.auto('Giriş'),
        textColor: Colors.white,
        onPressed: onRequireLogin,
      ),
      duration: const Duration(seconds: 3),
    ),
  );
  // Kısa bilgi sonrası auth ekranına dön
  await Future<void>.delayed(const Duration(milliseconds: 400));
  onRequireLogin();
  return false;
}

/// Misafir arama kotası: izin yoksa auth’a yönlendirir.
Future<bool> ensureGuestSearchAllowed(
  BuildContext context, {
  required bool isGuest,
  required VoidCallback onRequireLogin,
}) async {
  if (!isGuest) return true;
  final ok = await GuestLimitStore.canSearch();
  if (ok) {
    await GuestLimitStore.recordSearch();
    return true;
  }
  return ensureMemberAccess(
    context,
    isGuest: true,
    onRequireLogin: onRequireLogin,
    message: S.auto(
      'Misafir olarak en fazla ${GuestLimitStore.maxSearches} arama yapabilirsiniz. Devam için üye olun.',
    ),
  );
}

/// Haklar / Kartlar 2 dk kontrolü.
Future<bool> ensureGuestTimedTab(
  BuildContext context, {
  required bool isGuest,
  required String tab,
  required VoidCallback onRequireLogin,
}) async {
  if (!isGuest) return true;
  final ok = await GuestLimitStore.allowTimedTab(tab);
  if (ok) return true;
  return ensureMemberAccess(
    context,
    isGuest: true,
    onRequireLogin: onRequireLogin,
    message: S.auto(
      'Misafir erişimi 2 dakika ile sınırlıdır. Devam etmek için giriş yapın veya üye olun.',
    ),
  );
}
