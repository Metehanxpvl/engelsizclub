import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Son bu süre içinde heartbeat geldiyse çevrimiçi sayılır.
const presenceOnlineWindow = Duration(seconds: 90);

Timer? _heartbeat;
DateTime? _lastBeatAt;

bool isRecentlyOnline(DateTime? lastSeen) {
  if (lastSeen == null) return false;
  return DateTime.now().toUtc().difference(lastSeen.toUtc()) <=
      presenceOnlineWindow;
}

/// Uygulama açıkken kendi last_seen değerini düzenli günceller.
void startPresenceHeartbeat() {
  _heartbeat?.cancel();
  unawaited(touchMyPresence());
  _heartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
    unawaited(touchMyPresence());
  });
}

void stopPresenceHeartbeat() {
  _heartbeat?.cancel();
  _heartbeat = null;
}

Future<void> touchMyPresence() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final email = (user?.email ?? '').trim().toLowerCase();
  if (user == null || email.isEmpty) return;

  // Aynı saniyede gereksiz yazmayı kes.
  final now = DateTime.now().toUtc();
  if (_lastBeatAt != null && now.difference(_lastBeatAt!) < const Duration(seconds: 10)) {
    return;
  }
  _lastBeatAt = now;

  try {
    await client.from('user_presence').upsert(
      {
        'owner_email': email,
        'owner_id': user.id,
        'last_seen': now.toIso8601String(),
      },
      onConflict: 'owner_email',
    );
  } catch (_) {
    // Tablo yoksa / ağ hatası — sohbet çalışmaya devam eder.
  }
}

Future<bool> isEmailOnline(String email) async {
  final map = await loadPresenceOnlineMap([email]);
  return map[email.trim().toLowerCase()] == true;
}

/// Birden fazla e-posta için çevrimiçi haritası (küçük harf anahtar).
Future<Map<String, bool>> loadPresenceOnlineMap(Iterable<String> emails) async {
  final list = emails
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty && e.contains('@'))
      .toSet()
      .toList();
  if (list.isEmpty) return const {};

  try {
    final rows = await Supabase.instance.client
        .from('user_presence')
        .select('owner_email, last_seen')
        .inFilter('owner_email', list);
    final out = <String, bool>{
      for (final e in list) e: false,
    };
    for (final raw in rows as List) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final email = (m['owner_email']?.toString() ?? '').toLowerCase();
      final seen = DateTime.tryParse(m['last_seen']?.toString() ?? '');
      if (email.isEmpty) continue;
      out[email] = isRecentlyOnline(seen);
    }
    return out;
  } catch (_) {
    return {for (final e in list) e: false};
  }
}
