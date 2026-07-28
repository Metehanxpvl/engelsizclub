import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
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
  bool get isMesaj => type == 'mesaj';
  bool get isGorus =>
      type == 'gorus' ||
      type == 'dilek' ||
      type == 'sikayet' ||
      type == 'oneri' ||
      type == 'diger';

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
/// Başarısız olursa hata fırlatır (sessizce yutmaz).
Future<void> notifyIlanSahibiTeklif({
  required String ownerEmail,
  required String actorName,
  int? ilanId,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final actorEmail = (user?.email ?? '').trim().toLowerCase();
  final owner = ownerEmail.trim().toLowerCase();
  if (user == null || actorEmail.isEmpty || owner.isEmpty) {
    throw StateError('Teklif göndermek için giriş yapın.');
  }
  if (owner == actorEmail) {
    throw StateError('Kendi ilanınıza teklif veremezsiniz.');
  }

  final name = actorName.trim().isEmpty
      ? actorEmail.split('@').first
      : actorName.trim();
  final key = sohbetKeyFor(actorEmail, owner);
  final ilanLabel = ilanId == null ? 'ilanınıza' : '#$ilanId nolu ilanınıza';

  // Sohbete otomatik teklif mesajı (ayrı mesaj bildirimi yok — teklif bildirimi yeterli)
  await sendSohbetMesaj(
    peerEmail: owner,
    body: 'Merhaba! $ilanLabel teklif verdim. Görüşmek isterim.',
  );

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
}

/// Karşı tarafa yeni sohbet mesajı bildirimi.
/// Aynı kişiden gelen mesajlar üst üste binmez; son mesaj + saati güncellenir.
Future<void> notifySohbetMesaj({
  required String peerEmail,
  required String messageBody,
  String? actorName,
  int? ilanId,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final actorEmail = (user?.email ?? '').trim().toLowerCase();
  final owner = peerEmail.trim().toLowerCase();
  if (user == null || actorEmail.isEmpty || owner.isEmpty) return;
  if (owner == actorEmail) return;

  final name = (actorName ?? '').trim().isEmpty
      ? actorEmail.split('@').first
      : actorName!.trim();
  final raw = messageBody.trim();
  if (raw.isEmpty) return;
  final preview = raw.length > 90 ? '${raw.substring(0, 90)}…' : raw;
  final key = sohbetKeyFor(actorEmail, owner);
  final nowIso = DateTime.now().toUtc().toIso8601String();
  final payload = <String, dynamic>{
    'owner_email': owner,
    'actor_email': actorEmail,
    'actor_name': name,
    'type': 'mesaj',
    'title': 'Yeni mesaj',
    'body': '$name: $preview',
    'ilan_id': ilanId,
    'sohbet_key': key,
    'read': false,
    'created_at': nowIso,
  };

  try {
    // Aynı sohbetten okunmamış mesaj bildirimi varsa güncelle (üst üste ekleme).
    final existing = await client
        .from('bildirimler')
        .select('id')
        .eq('owner_email', owner)
        .eq('actor_email', actorEmail)
        .eq('type', 'mesaj')
        .eq('read', false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null && (existing['id'] as num?) != null) {
      await client
          .from('bildirimler')
          .update({
            'actor_name': name,
            'title': 'Yeni mesaj',
            'body': '$name: $preview',
            'ilan_id': ilanId,
            'sohbet_key': key,
            'read': false,
            'created_at': nowIso,
          })
          .eq('id', (existing['id'] as num).toInt());
      return;
    }
  } catch (_) {
    // Politika / şema yoksa klasik insert'e düş.
  }

  await client.from('bildirimler').insert(payload);
}

/// Aynı kişiden biriken mesaj bildirimlerini tek satıra indir (en son saat kalır).
List<AppBildirim> collapseMesajBildirimler(List<AppBildirim> list) {
  final seenMesaj = <String>{};
  final out = <AppBildirim>[];
  final duplicateIds = <int>[];

  for (final b in list) {
    if (!b.isMesaj) {
      out.add(b);
      continue;
    }
    final key = (b.sohbetKey != null && b.sohbetKey!.isNotEmpty)
        ? 'sk:${b.sohbetKey}'
        : 'ae:${b.actorEmail}';
    if (seenMesaj.contains(key)) {
      if (b.id > 0) duplicateIds.add(b.id);
      continue;
    }
    seenMesaj.add(key);
    out.add(b);
  }

  // Eski kopyaları arka planda temizle (alıcı silme yetkisiyle).
  if (duplicateIds.isNotEmpty) {
    Future.microtask(() async {
      for (final id in duplicateIds) {
        try {
          await deleteBildirim(id);
        } catch (_) {}
      }
    });
  }

  return out;
}

/// Dilek / şikayet / öneri → admin hesabına bildirim.
/// `gorusler` tablosu varsa arşivler; yoksa yalnız bildirim gider.
Future<void> submitGorusToAdmin({
  required String type,
  required String subject,
  required String message,
  String? actorName,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final actorEmail = (user?.email ?? '').trim().toLowerCase();
  if (user == null || actorEmail.isEmpty) {
    throw StateError('Göndermek için giriş yapın.');
  }

  final sub = subject.trim();
  final msg = message.trim();
  if (sub.isEmpty || msg.isEmpty) {
    throw StateError('Konu ve mesaj zorunlu.');
  }

  final name = (actorName ?? '').trim().isEmpty
      ? actorEmail.split('@').first
      : actorName!.trim();
  final tip = type.trim().isEmpty ? 'dilek' : type.trim().toLowerCase();
  final tipLabel = switch (tip) {
    'sikayet' => 'Şikayet',
    'oneri' => 'Öneri',
    'diger' => 'Diğer',
    _ => 'Dilek',
  };

  try {
    await client.from('gorusler').insert({
      'user_email': actorEmail,
      'user_name': name,
      'type': tip,
      'subject': sub,
      'message': msg,
    });
  } catch (_) {
    // Tablo yoksa veya RLS engeli: bildirim yine gitsin.
  }

  final body = '$name · $actorEmail\n\n$msg';
  final rows = <Map<String, dynamic>>[
    for (final admin in kAppAdminEmails)
      if (admin.trim().isNotEmpty)
        {
          'owner_email': admin.trim().toLowerCase(),
          'actor_email': actorEmail,
          'actor_name': name,
          'type': 'gorus',
          'title': '$tipLabel: $sub',
          'body': body.length > 1800 ? '${body.substring(0, 1800)}…' : body,
          'ilan_id': null,
          'sohbet_key': null,
          'read': false,
        },
  ];
  if (rows.isEmpty) {
    throw StateError('Admin hesabı tanımlı değil.');
  }
  await client.from('bildirimler').insert(rows);
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
    return collapseMesajBildirimler(
      (rows as List)
          .whereType<Map>()
          .map((e) => AppBildirim.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
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
