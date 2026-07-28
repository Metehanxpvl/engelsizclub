import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';

const pendingGoogleRoleKey = 'pending_google_user_type';

/// Yeni üye başlangıç kredisi (yalnız uzman / bakıcı).
const int kWelcomeKredi = 25;

/// Aile rolü başlangıç iyilik puanı (yükledikçe artar).
const int kAileStartKredi = 1;

/// Admin başlangıç / hedef kredisi.
const int kAdminKredi = 10000;

/// Tek seferlik yükleme: admin 10000, uzman/bakıcı 25, aile 1.
const int kKrediGrantVersion = 5;

String krediPrefsKeyFor(String email, {String fallback = 'anon'}) {
  final e = email.trim().toLowerCase();
  return 'user_kredi_${e.isEmpty ? fallback : e}';
}

String krediGrantPrefsKeyFor(String email) =>
    '${krediPrefsKeyFor(email)}_grant_v$kKrediGrantVersion';

bool isProfUserType(String? userType) {
  final t = (userType ?? '').trim().toLowerCase();
  return t == 'uzman' || t == 'bakici';
}

/// Aile: 1 · Uzman/Bakıcı: 25 · Admin: 10000
int startingKrediFor(String email, {String? userType}) {
  if (isAppAdmin(email)) return kAdminKredi;
  if (isProfUserType(userType)) return kWelcomeKredi;
  return kAileStartKredi;
}

class KrediSnapshot {
  const KrediSnapshot({
    required this.balance,
    required this.welcomeGiftGiven,
  });

  final int balance;
  final bool welcomeGiftGiven;
}

/// Buluttan kredi okur; yoksa seed. Grant yalnızca bir kez uygulanır.
Future<KrediSnapshot> loadUserKredi({
  required String email,
  required String? userType,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = krediPrefsKeyFor(email);
  final giftKey = '${key}_welcome_gift';
  final grantKey = krediGrantPrefsKeyFor(email);
  final target = startingKrediFor(email, userType: userType);
  final isProf = isProfUserType(userType) || isAppAdmin(email);

  Future<KrediSnapshot> finish(int balance, {bool gift = true}) async {
    await prefs.setInt(key, balance);
    if (gift) await prefs.setBool(giftKey, true);
    return KrediSnapshot(balance: balance, welcomeGiftGiven: gift);
  }

  Future<KrediSnapshot> applyGrantIfNeeded({
    required int? current,
    required bool welcomeGift,
  }) async {
    final granted = prefs.getBool(grantKey) ?? false;
    final bal = current ?? 0;

    // Admin: bu grant sürümünde hedef bakiyeye çek (10000).
    if (isAppAdmin(email)) {
      if (!granted || bal < target) {
        final saved = await saveUserKredi(
          email: email,
          balance: target,
          welcomeGiftGiven: true,
        );
        if (saved) await prefs.setBool(grantKey, true);
        await prefs.setInt(key, target);
        return finish(target);
      }
      await prefs.setBool(grantKey, true);
      return finish(bal);
    }

    // Aile: bir kez 1 iyilik puanı; yükleme/harcama sonrası bakiye korunur.
    if (!isProf) {
      if (!granted && bal < target) {
        final saved = await saveUserKredi(
          email: email,
          balance: target,
          welcomeGiftGiven: true,
        );
        if (saved) await prefs.setBool(grantKey, true);
        await prefs.setInt(key, target);
        return finish(target);
      }
      await prefs.setBool(grantKey, true);
      return finish(bal, gift: true);
    }

    // Hoş geldin / grant işlendiyse ASLA otomatik doldurma (harcama korunur).
    if (welcomeGift || granted) {
      await prefs.setBool(grantKey, true);
      if (welcomeGift) await prefs.setBool(giftKey, true);
      return finish(bal, gift: true);
    }

    // Zaten hedefte veya üstünde
    if (bal >= target) {
      await prefs.setBool(grantKey, true);
      await saveUserKredi(
        email: email,
        balance: bal,
        welcomeGiftGiven: true,
      );
      return finish(bal);
    }

    // Eski seed (0/3/10) veya boş → hedefe yükselt (bir kez)
    final looksLikeOldSeed =
        current == null || bal == 0 || bal == 3 || bal == 10;
    if (!looksLikeOldSeed) {
      await prefs.setBool(grantKey, true);
      return finish(bal);
    }

    final saved = await saveUserKredi(
      email: email,
      balance: target,
      welcomeGiftGiven: true,
    );
    if (saved) await prefs.setBool(grantKey, true);
    await prefs.setInt(key, target);
    return finish(target);
  }

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user != null) {
    try {
      final row = await client
          .from('user_profiles')
          .select('kredi, kredi_welcome_gift')
          .eq('owner_id', user.id)
          .maybeSingle();

      if (row != null) {
        final balance = (row['kredi'] as num?)?.toInt();
        final gift = row['kredi_welcome_gift'] == true;
        return applyGrantIfNeeded(current: balance, welcomeGift: gift);
      }

      final local = prefs.getInt(key);
      final giftLocal = prefs.getBool(giftKey) ?? false;
      return applyGrantIfNeeded(current: local, welcomeGift: giftLocal);
    } catch (_) {
      // Kolon henüz yoksa / ağ yoksa yerel yedek
    }
  }

  // Offline / oturumsuz
  final local = prefs.getInt(key);
  final giftLocal = prefs.getBool(giftKey) ?? false;
  final granted = prefs.getBool(grantKey) ?? false;
  if (isAppAdmin(email)) {
    if (!granted || (local ?? 0) < target) {
      await prefs.setInt(key, target);
      await prefs.setBool(giftKey, true);
      await prefs.setBool(grantKey, true);
      return KrediSnapshot(balance: target, welcomeGiftGiven: true);
    }
    return finish(local ?? target);
  }
  if (!isProf) {
    if (!granted && (local ?? 0) < target) {
      await prefs.setInt(key, target);
      await prefs.setBool(giftKey, true);
      await prefs.setBool(grantKey, true);
      return KrediSnapshot(balance: target, welcomeGiftGiven: true);
    }
    await prefs.setBool(grantKey, true);
    return finish(local ?? target, gift: true);
  }
  if (giftLocal || granted) {
    return finish(local ?? 0, gift: true);
  }
  if (local != null && local != 0 && local != 3 && local != 10) {
    await prefs.setBool(grantKey, true);
    return finish(local);
  }
  if ((local ?? 0) < target) {
    await prefs.setInt(key, target);
    await prefs.setBool(giftKey, true);
    await prefs.setBool(grantKey, true);
    return KrediSnapshot(balance: target, welcomeGiftGiven: true);
  }
  await prefs.setBool(grantKey, true);
  await prefs.setBool(giftKey, true);
  return finish(local ?? target);
}

Future<bool> saveUserKredi({
  required String email,
  required int balance,
  bool? welcomeGiftGiven,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = krediPrefsKeyFor(email);
  final giftKey = '${key}_welcome_gift';
  final grantKey = krediGrantPrefsKeyFor(email);
  final safe = balance.clamp(0, 999999);
  await prefs.setInt(key, safe);
  // Harcama sonrası grant kilitlensin — reload bakiyeyi şişirmesin
  await prefs.setBool(grantKey, true);
  if (welcomeGiftGiven == true) {
    await prefs.setBool(giftKey, true);
  }

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return false;

  final payload = <String, dynamic>{
    'owner_id': user.id,
    'owner_email': email.trim().toLowerCase(),
    'kredi': safe,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  if (welcomeGiftGiven != null) {
    payload['kredi_welcome_gift'] = welcomeGiftGiven;
  } else {
    // Mevcut hediyeyi koru / işaretle — grant kilidi bulutta da dursun
    payload['kredi_welcome_gift'] = true;
  }

  try {
    await client.from('user_profiles').upsert(
      payload,
      onConflict: 'owner_id',
    );
    return true;
  } catch (_) {
    // Update dene (upsert policy sorunlarında)
    try {
      await client.from('user_profiles').update({
        'kredi': safe,
        'kredi_welcome_gift': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('owner_id', user.id);
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// 1 kredi harca; yeni bakiyeyi döner. Yetersizse null.
Future<int?> spendOneKredi({required String email}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = krediPrefsKeyFor(email);
  final current = prefs.getInt(key);
  int bal = current ?? 0;

  // Buluttan taze oku
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user != null) {
    try {
      final row = await client
          .from('user_profiles')
          .select('kredi')
          .eq('owner_id', user.id)
          .maybeSingle();
      final cloud = (row?['kredi'] as num?)?.toInt();
      if (cloud != null) bal = cloud;
    } catch (_) {}
  }

  if (bal <= 0) return null;
  final next = bal - 1;
  final ok = await saveUserKredi(
    email: email,
    balance: next,
    welcomeGiftGiven: true,
  );
  if (!ok && user != null) {
    // Yerel yine de düşsün; sonraki sync dener
    await prefs.setInt(key, next);
  }
  return next;
}

/// Yeni üye başlangıç kredisi: herkese [kWelcomeKredi], admin [kAdminKredi].
Future<void> seedWelcomeCredits({
  required String email,
  required String? userType,
}) async {
  await loadUserKredi(email: email, userType: userType);
}

Future<void> savePendingGoogleRole(String role) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(pendingGoogleRoleKey, role);
}

Future<void> clearPendingGoogleRole() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(pendingGoogleRoleKey);
}

Future<String?> readPendingGoogleRole() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(pendingGoogleRoleKey);
}
