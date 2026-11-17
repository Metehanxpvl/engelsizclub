import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../kredi_store.dart';
import '../l10n/l10n_text.dart';
import '../utils/async_timeout.dart';
import '../uzman_kosesi_profiles_store.dart';
import 'expert_cv_models.dart';
import 'expert_cv_store.dart';

bool _ready() {
  try {
    return Supabase.instance.isInitialized;
  } catch (_) {
    return false;
  }
}

/// Vadesi gelen yayınları yeniler veya bakiyesiz olanları yayından alır.
Future<void> yenileUzmanKosesAylikUcret() async {
  if (!_ready()) return;
  try {
    await withNetworkTimeout(
      Supabase.instance.client.rpc('uzman_kosesi_aylik_ucret'),
    );
    invalidateUzmanKosesProfilesCache();
  } catch (_) {}
}

Future<void> uyarUzmanKartBakiyesi(
  BuildContext context, {
  required String userEmail,
}) async {
  if (userEmail.trim().isEmpty) return;
  ExpertCvProfile? mine;
  try {
    mine = await loadMyExpertProfile();
  } catch (_) {
    return;
  }
  if (mine == null || !context.mounted) return;
  if (mine.isExpired) {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('İlanınız yayından kalktı'),
        content: const L10nText(kUzmanKartYayindanKalkti),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const L10nText('Tamam'),
          ),
        ],
      ),
    );
    return;
  }
  if (!mine.isPublished || mine.ucretBitis == null) return;
  final now = DateTime.now();
  final bitis = mine.ucretBitis!;
  if (bitis.difference(now).inDays > 3) return;
  int bal = 0;
  try {
    final snap = await loadUserKredi(email: userEmail, userType: currentAuthUserType());
    bal = snap.balance;
  } catch (_) {}
  final fee = uzmanKartPuan(mine.kartSpan);
  if (bal >= fee) return;
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const L10nText('Puan bakiyeniz yetersiz'),
      content: const L10nText(kUzmanKartYetersizUyarisi),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const L10nText('Tamam'),
        ),
      ],
    ),
  );
}
