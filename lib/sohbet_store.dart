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
  });

  final int id;
  final String sohbetKey;
  final String senderEmail;
  final String receiverEmail;
  final String body;
  final DateTime createdAt;

  factory SohbetMesaj.fromJson(Map<String, dynamic> json) => SohbetMesaj(
        id: (json['id'] as num?)?.toInt() ?? 0,
        sohbetKey: json['sohbet_key']?.toString() ?? '',
        senderEmail: (json['sender_email']?.toString() ?? '').toLowerCase(),
        receiverEmail: (json['receiver_email']?.toString() ?? '').toLowerCase(),
        body: json['body']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
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
  });

  final String sohbetKey;
  final String peerEmail;
  final String lastMsg;
  final DateTime lastTime;
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
      })
      .select()
      .single();
  return SohbetMesaj.fromJson(Map<String, dynamic>.from(row));
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
  final me = myEmail.trim().toLowerCase();
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
            .limit(100);
    final list = (rows as List)
        .whereType<Map>()
        .map((e) => SohbetMesaj.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final seen = <String>{};
    final ozets = <SohbetOzet>[];
    for (final m in list) {
      if (!seen.add(m.sohbetKey)) continue;
      String peer;
      if (m.senderEmail == me) {
        peer = m.receiverEmail;
      } else if (m.receiverEmail == me) {
        peer = m.senderEmail;
      } else {
        // Admin, kendisinin olmadığı sohbet
        final a = m.senderEmail.split('@').first;
        final b = m.receiverEmail.split('@').first;
        peer = '$a ↔ $b';
      }
      ozets.add(SohbetOzet(
        sohbetKey: m.sohbetKey,
        peerEmail: peer,
        lastMsg: m.body,
        lastTime: m.createdAt,
      ));
    }
    return ozets;
  } catch (_) {
    return const [];
  }
}
