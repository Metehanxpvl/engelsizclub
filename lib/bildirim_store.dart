import 'package:supabase_flutter/supabase_flutter.dart';

import 'sohbet_store.dart';

class AppBildirim {
  const AppBildirim({
    required this.id,
    required this.ownerEmail,
    required this.actorEmail,
    required this.actorName,
    required this.type,
    required this.title,
    required this.body,
    required this.ilanId,
    required this.sohbetKey,
    required this.read,
    required this.createdAt,
  });

  final int id;
  final String ownerEmail;
  final String actorEmail;
  final String actorName;
  final String type;
  final String title;
  final String body;
  final int? ilanId;
  final String? sohbetKey;
  final bool read;
  final DateTime createdAt;

  bool get isTeklif => type == 'teklif';

  factory AppBildirim.fromJson(Map<String, dynamic> json) => AppBildirim(
        id: (json['id'] as num?)?.toInt() ?? 0,
        ownerEmail: (json['owner_email']?.toString() ?? '').toLowerCase(),
        actorEmail: (json['actor_email']?.toString() ?? '').toLowerCase(),
        actorName: json['actor_name']?.toString() ?? '',
        type: json['type']?.toString() ?? 'teklif',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        ilanId: (json['ilan_id'] as num?)?.toInt(),
        sohbetKey: json['sohbet_key']?.toString(),
        read: json['read'] == true,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

/// İlan sahibine teklif bildirimi gönderir + sohbete ilk mesajı yazar.
Future<void> notifyIlanSahibiTeklif({
  required String ownerEmail,
  required String actorName,
  int? ilanId,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final actorEmail = (user?.email ?? '').trim().toLowerCase();
  final owner = ownerEmail.trim().toLowerCase();
  if (user == null || actorEmail.isEmpty || owner.isEmpty) return;
  if (owner == actorEmail) return;

  final name = actorName.trim().isEmpty
      ? actorEmail.split('@').first
      : actorName.trim();
  final key = sohbetKeyFor(actorEmail, owner);
  final ilanLabel = ilanId == null ? 'ilanınıza' : '#$ilanId nolu ilanınıza';

  // Sohbete otomatik teklif mesajı
  try {
    await sendSohbetMesaj(
      peerEmail: owner,
      body: 'Merhaba! $ilanLabel teklif verdim. Görüşmek isterim.',
    );
  } catch (_) {
    // Sohbet tablosu yoksa yine de bildirim dene
  }

  try {
    await client.from('bildirimler').insert({
      'owner_email': owner,
      'actor_email': actorEmail,
      'actor_name': name,
      'type': 'teklif',
      'title': 'Yeni teklif',
      'body': '$name $ilanLabel teklif verdi.',
      'ilan_id': ilanId,
      'sohbet_key': key,
      'read': false,
    });
  } catch (_) {
    // Tablo yoksa sessizce geç
  }
}

Future<List<AppBildirim>> loadBildirimler() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null || me.isEmpty) return const [];
  try {
    final rows = await client
        .from('bildirimler')
        .select()
        .eq('owner_email', me)
        .order('created_at', ascending: false)
        .limit(50);
    return (rows as List)
        .whereType<Map>()
        .map((e) => AppBildirim.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<int> loadUnreadBildirimCount() async {
  final list = await loadBildirimler();
  return list.where((b) => !b.read).length;
}

Future<void> markBildirimOkundu(int id) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null || me.isEmpty || id <= 0) return;
  try {
    await client
        .from('bildirimler')
        .update({'read': true})
        .eq('id', id)
        .eq('owner_email', me);
  } catch (_) {}
}

Future<void> markAllBildirimlerOkundu() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null || me.isEmpty) return;
  try {
    await client
        .from('bildirimler')
        .update({'read': true})
        .eq('owner_email', me)
        .eq('read', false);
  } catch (_) {}
}

/// Alıcı kendi teklif/bildirimini siler.
Future<void> deleteBildirim(int id) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null || me.isEmpty || id <= 0) {
    throw StateError('Bildirim silmek için giriş yapın.');
  }
  await client
      .from('bildirimler')
      .delete()
      .eq('id', id)
      .eq('owner_email', me);
}
