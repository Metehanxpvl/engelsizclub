import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const pendingGoogleRoleKey = 'pending_google_user_type';

String krediPrefsKeyFor(String email, {String fallback = 'anon'}) {
  final e = email.trim().toLowerCase();
  return 'user_kredi_${e.isEmpty ? fallback : e}';
}

class KrediSnapshot {
  const KrediSnapshot({
    required this.balance,
    required this.welcomeGiftGiven,
  });

  final int balance;
  final bool welcomeGiftGiven;
}

/// Buluttan kredi okur; yoksa yerel prefs + gerekirse hoş geldin seed.
Future<KrediSnapshot> loadUserKredi({
  required String email,
  required String? userType,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = krediPrefsKeyFor(email);
  final giftKey = '${key}_welcome_gift';
  final isProf = userType == 'uzman' || userType == 'bakici';
  final defaultStart = isProf ? 10 : 3;

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
        if (balance != null) {
          await prefs.setInt(key, balance);
          if (gift) await prefs.setBool(giftKey, true);
          return KrediSnapshot(balance: balance, welcomeGiftGiven: gift);
        }
      }

      // Profil yok / kredi kolonu boş → seed veya yerelden migrate
      final local = prefs.getInt(key);
      final giftLocal = prefs.getBool(giftKey) ?? false;
      if (local != null) {
        await saveUserKredi(
          email: email,
          balance: local,
          welcomeGiftGiven: giftLocal || isProf,
        );
        return KrediSnapshot(
          balance: local,
          welcomeGiftGiven: giftLocal || isProf,
        );
      }

      await saveUserKredi(
        email: email,
        balance: defaultStart,
        welcomeGiftGiven: isProf,
      );
      return KrediSnapshot(
        balance: defaultStart,
        welcomeGiftGiven: isProf,
      );
    } catch (_) {
      // Kolon henüz yoksa / ağ yoksa yerel yedek
    }
  }

  if (prefs.containsKey(key)) {
    return KrediSnapshot(
      balance: prefs.getInt(key) ?? defaultStart,
      welcomeGiftGiven: prefs.getBool(giftKey) ?? false,
    );
  }

  await prefs.setInt(key, defaultStart);
  if (isProf) await prefs.setBool(giftKey, true);
  return KrediSnapshot(
    balance: defaultStart,
    welcomeGiftGiven: isProf,
  );
}

Future<void> saveUserKredi({
  required String email,
  required int balance,
  bool? welcomeGiftGiven,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = krediPrefsKeyFor(email);
  final giftKey = '${key}_welcome_gift';
  final safe = balance.clamp(0, 999999);
  await prefs.setInt(key, safe);
  if (welcomeGiftGiven == true) {
    await prefs.setBool(giftKey, true);
  }

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  final payload = <String, dynamic>{
    'owner_id': user.id,
    'owner_email': email.trim().toLowerCase(),
    'kredi': safe,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  if (welcomeGiftGiven != null) {
    payload['kredi_welcome_gift'] = welcomeGiftGiven;
  }

  try {
    await client.from('user_profiles').upsert(
      payload,
      onConflict: 'owner_id',
    );
  } catch (_) {
    // Yerel kayıt yeterli; SQL migration sonrası bulut yazılır
  }
}

/// Yeni üye başlangıç kredisi: uzman/bakıcı → 10 hediye, aile → 3.
/// Mevcut kredi kaydı varsa üzerine yazmaz.
Future<void> seedWelcomeCredits({
  required String email,
  required String? userType,
}) async {
  final snap = await loadUserKredi(email: email, userType: userType);
  // loadUserKredi zaten yoksa seed eder; burada sadece garanti
  if (snap.balance < 0) return;
  final isProf = userType == 'uzman' || userType == 'bakici';
  if (!snap.welcomeGiftGiven && isProf) {
    await saveUserKredi(
      email: email,
      balance: snap.balance > 0 ? snap.balance : 10,
      welcomeGiftGiven: true,
    );
  }
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
