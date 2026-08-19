import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/ilanlar_data.dart';

const pendingGoogleRoleKey = 'pending_google_user_type';

/// Tüm üyeler (aile / uzman / bakıcı) başlangıç puanı.
const int kMemberStartKredi = 5;

/// Geriye dönük uyumluluk — UI metinleri bu sabiti kullanır.
const int kWelcomeKredi = kMemberStartKredi;

/// @deprecated Aile için ayrı başlangıç yok; [kMemberStartKredi] kullanın.
const int kAileStartKredi = kMemberStartKredi;

/// Admin başlangıç / hedef kredisi.
const int kAdminKredi = 10000;

/// Tek seferlik yükleme sürümü — artırınca mevcut üyelere hedef puan uygulanır.
const int kKrediGrantVersion = 6;

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

String normalizedUserType(String? userType) {
  final t = (userType ?? '').trim().toLowerCase();
  if (t == 'uzman' || t == 'bakici' || t == 'aile') return t;
  return 'aile';
}

String currentAuthUserType() {
  final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
  return normalizedUserType(meta?['user_type']?.toString());
}

bool isAileUserType(String? userType) =>
    normalizedUserType(userType) == 'aile';

bool canPostIlan({
  String? userType,
  String? email,
  String listingCategory = kIlanCatUzmanAriyorum,
}) {
  if (isAppAdmin(email)) return true;
  return isAileUserType(userType);
}

bool canOfferOnIlan({
  required String kind,
  String? userType,
  String? email,
  String listingCategory = kIlanCatUzmanAriyorum,
}) {
  if (isAppAdmin(email)) return true;
  // 2. el: aile (ve diğer roller) ücretsiz iletişim kurabilir.
  if (kind == 'ikinciel') return true;
  // Uzman arıyorum / bakıcı arıyorum: yalnızca uzman veya bakıcı rolü.
  return isProfUserType(userType);
}

/// Uzman/bakıcı ilanlarında teklif 1 puan harcar; 2. el ücretsiz.
bool offerCostsKredi({required String kind}) => kind != 'ikinciel';

/// Üye: 5 · Admin: 10000
int startingKrediFor(String email, {String? userType}) {
  if (isAppAdmin(email)) return kAdminKredi;
  return kMemberStartKredi;
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

    // Üye: grant sürümü yenilendiyse herkesi hedef puana (5) çek.
    if (!granted) {
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
    if (welcomeGift) await prefs.setBool(giftKey, true);
    return finish(bal, gift: true);
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
  if (!granted) {
    await prefs.setInt(key, target);
    await prefs.setBool(giftKey, true);
    await prefs.setBool(grantKey, true);
    return KrediSnapshot(balance: target, welcomeGiftGiven: true);
  }
  await prefs.setBool(grantKey, true);
  return finish(local ?? target, gift: true);
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
  final safe = balance.clamp(0, 99999999);
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

/// Yeni üye başlangıç kredisi: herkese [kMemberStartKredi], admin [kAdminKredi].
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
