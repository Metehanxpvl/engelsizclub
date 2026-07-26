import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';

class SohbetMesaj {
  const SohbetMesaj({
    required this.id,
    required this.sohbetKey,
    required this.senderEmail,
    required this.receiverEmail,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final String sohbetKey;
  final String senderEmail;
  final String receiverEmail;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory SohbetMesaj.fromJson(Map<String, dynamic> json) => SohbetMesaj(
        id: (json['id'] as num?)?.toInt() ?? 0,
        sohbetKey: json['sohbet_key']?.toString() ?? '',
        senderEmail: (json['sender_email']?.toString() ?? '').toLowerCase(),
        receiverEmail: (json['receiver_email']?.toString() ?? '').toLowerCase(),
        body: json['body']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
        readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
      );

  String get timeLabel {
    final local = createdAt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class SohbetOzet {
  const SohbetOzet({
    required this.sohbetKey,
    required this.peerEmail,
    required this.lastMsg,
    required this.lastTime,
    this.unreadCount = 0,
    this.lastFromPeer = false,
  });

  final String sohbetKey;
  final String peerEmail;
  final String lastMsg;
  final DateTime lastTime;
  /// Bana gelen ve henüz okunmamış mesaj sayısı (read_at == null).
  final int unreadCount;
  final bool lastFromPeer;

  bool get hasUnread => unreadCount > 0;
}

String sohbetKeyFor(String emailA, String emailB) {
  final a = emailA.trim().toLowerCase();
  final b = emailB.trim().toLowerCase();
  final pair = [a, b]..sort();
  return '${pair[0]}|${pair[1]}';
}

Future<List<SohbetMesaj>> loadSohbetMesajlari(String sohbetKey) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return const [];
  try {
    final rows = await Supabase.instance.client
        .from('sohbet_mesajlari')
        .select()
        .eq('sohbet_key', sohbetKey)
        .order('created_at', ascending: true)
        .limit(200);
    return (rows as List)
        .whereType<Map>()
        .map((e) => SohbetMesaj.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<SohbetMesaj> sendSohbetMesaj({
  required String peerEmail,
  required String body,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final myEmail = (user?.email ?? '').trim().toLowerCase();
  final peer = peerEmail.trim().toLowerCase();
  if (user == null || myEmail.isEmpty) {
    throw StateError('Mesaj göndermek için giriş yapın.');
  }
  if (peer.isEmpty) {
    throw StateError('Karşı taraf bulunamadı (örnek ilan olabilir).');
  }
  if (peer == myEmail) {
    throw StateError('Kendi ilanınıza teklif veremezsiniz.');
  }
  final text = body.trim();
  if (text.isEmpty) throw StateError('Boş mesaj gönderilemez.');

  final row = await client
      .from('sohbet_mesajlari')
      .insert({
        'sohbet_key': sohbetKeyFor(myEmail, peer),
        'sender_email': myEmail,
        'sender_id': user.id,
        'receiver_email': peer,
        'body': text,
        // read_at null → alıcı için okunmadı
      })
      .select()
      .single();
  return SohbetMesaj.fromJson(Map<String, dynamic>.from(row));
}

/// Sohbetteki bana gelen okunmamış mesajları okundu işaretler.
Future<void> markSohbetMesajlariOkundu(String sohbetKey) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  final key = sohbetKey.trim();
  if (user == null || me.isEmpty || key.isEmpty) return;

  final now = DateTime.now().toUtc();
  // Yerel yedek (SQL henüz yoksa bile UI temizlensin)
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localReadKey(me, key), now.toIso8601String());
  } catch (_) {}

  try {
    await client
        .from('sohbet_mesajlari')
        .update({'read_at': now.toIso8601String()})
        .eq('sohbet_key', key)
        .eq('receiver_email', me)
        .isFilter('read_at', null);
  } catch (_) {
    // Kolon / politika yoksa yerel anahtar yeterli
  }
}

String _localReadKey(String me, String sohbetKey) =>
    'sohbet_read_at_${me}_$sohbetKey';

Future<Map<String, DateTime>> _loadLocalReadMap(String me) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final prefix = 'sohbet_read_at_${me}_';
    final out = <String, DateTime>{};
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(prefix)) continue;
      final sohbetKey = k.substring(prefix.length);
      final raw = prefs.getString(k);
      final t = raw == null ? null : DateTime.tryParse(raw);
      if (t != null) out[sohbetKey] = t;
    }
    return out;
  } catch (_) {
    return {};
  }
}

/// Tek mesaj siler. Admin her mesajı silebilir; diğerleri yalnız kendi mesajını.
Future<void> deleteSohbetMesaj(int id) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null) throw StateError('Mesaj silmek için giriş yapın.');
  if (id <= 0) throw StateError('Geçersiz mesaj.');
  var q = client.from('sohbet_mesajlari').delete().eq('id', id);
  if (!isAppAdmin(me)) {
    q = q.eq('sender_id', user.id);
  }
  await q;
}

/// Bir sohbetteki tüm mesajları siler.
Future<void> deleteSohbet(String sohbetKey) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null || me.isEmpty) {
    throw StateError('Sohbet silmek için giriş yapın.');
  }
  final key = sohbetKey.trim();
  if (key.isEmpty) throw StateError('Geçersiz sohbet.');
  var q = client.from('sohbet_mesajlari').delete().eq('sohbet_key', key);
  if (!isAppAdmin(me)) {
    q = q.or('sender_email.eq.$me,receiver_email.eq.$me');
  }
  await q;
}

/// Benim tarafım olduğum sohbetlerin son mesaj özetleri.
/// Admin tüm sohbetleri görür (moderasyon).
Future<List<SohbetOzet>> loadSohbetOzetleri(String myEmail) async {
  final authEmail =
      (Supabase.instance.client.auth.currentUser?.email ?? '')
          .trim()
          .toLowerCase();
  final me = myEmail.trim().toLowerCase().isNotEmpty
      ? myEmail.trim().toLowerCase()
      : authEmail;
  if (me.isEmpty) return const [];
  final admin = isAppAdmin(me);
  try {
    final rows = admin
        ? await Supabase.instance.client
            .from('sohbet_mesajlari')
            .select()
            .order('created_at', ascending: false)
            .limit(400)
        : await Supabase.instance.client
            .from('sohbet_mesajlari')
            .select()
            .or('sender_email.eq.$me,receiver_email.eq.$me')
            .order('created_at', ascending: false)
            .limit(200);
    final rawList = (rows as List).whereType<Map>().toList();
    final list = rawList
        .map((e) => SohbetMesaj.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final localRead = await _loadLocalReadMap(me);
    if (authEmail.isNotEmpty && authEmail != me) {
      localRead.addAll(await _loadLocalReadMap(authEmail));
    }

    bool isIncomingToMe(SohbetMesaj m) {
      return m.receiverEmail == me ||
          (authEmail.isNotEmpty && m.receiverEmail == authEmail);
    }

    // Okunmamış = bana gelen + read_at null (is_read == false)
    final unreadByKey = <String, int>{};
    for (final m in list) {
      if (!isIncomingToMe(m)) continue;
      if (m.isRead) continue; // read_at dolu
      final local = localRead[m.sohbetKey];
      // Yerel "okudum" damgası yalnız DB güncellemesi gecikirse iyimser temizlik
      if (local != null && !m.createdAt.toUtc().isAfter(local.toUtc())) {
        continue;
      }
      unreadByKey[m.sohbetKey] = (unreadByKey[m.sohbetKey] ?? 0) + 1;
    }

    final seen = <String>{};
    final ozets = <SohbetOzet>[];
    for (final m in list) {
      if (!seen.add(m.sohbetKey)) continue;
      String peer;
      if (m.senderEmail == me || m.senderEmail == authEmail) {
        peer = m.receiverEmail;
      } else if (isIncomingToMe(m)) {
        peer = m.senderEmail;
      } else {
        final a = m.senderEmail.split('@').first;
        final b = m.receiverEmail.split('@').first;
        peer = '$a ↔ $b';
      }

      var unread = unreadByKey[m.sohbetKey] ?? 0;
      final lastFromPeer = isIncomingToMe(m) &&
          m.senderEmail != me &&
          m.senderEmail != authEmail;
      // Son mesaj karşıdan ve okunmamışsa en az 1 göster
      if (lastFromPeer && !m.isRead) {
        final local = localRead[m.sohbetKey];
        final locallyRead = local != null &&
            !m.createdAt.toUtc().isAfter(local.toUtc());
        if (!locallyRead && unread < 1) unread = 1;
      }

      ozets.add(SohbetOzet(
        sohbetKey: m.sohbetKey,
        peerEmail: peer,
        lastMsg: m.body,
        lastTime: m.createdAt,
        unreadCount: unread,
        lastFromPeer: lastFromPeer,
      ));
    }
    return ozets;
  } catch (_) {
    return const [];
  }
}

/// Açık sohbet için Realtime aboneliği (Web/iOS/Android aynı kanal).
RealtimeChannel subscribeSohbetMesajlari({
  required String sohbetKey,
  required void Function() onChange,
}) {
  final key = sohbetKey.trim();
  final channel = Supabase.instance.client.channel('sohbet-msg-$key');
  channel.onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'sohbet_mesajlari',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'sohbet_key',
      value: key,
    ),
    callback: (_) => onChange(),
  );
  channel.subscribe();
  return channel;
}

/// Inbox özeti + bildirimler için Realtime.
RealtimeChannel subscribeInboxRealtime({
  required String myEmail,
  required void Function() onChange,
}) {
  final me = myEmail.trim().toLowerCase();
  final channel = Supabase.instance.client.channel('inbox-$me');
  channel
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sohbet_mesajlari',
      callback: (_) => onChange(),
    )
    ..onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'bildirimler',
      callback: (_) => onChange(),
    );
  channel.subscribe();
  return channel;
}

Future<void> unsubscribeRealtime(RealtimeChannel? channel) async {
  if (channel == null) return;
  try {
    await Supabase.instance.client.removeChannel(channel);
  } catch (_) {
    try {
      await channel.unsubscribe();
    } catch (_) {}
  }
}
