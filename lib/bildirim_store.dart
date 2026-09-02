import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/ilanlar_data.dart'
    show
        kIlanCatUzmanAriyorum,
        chatPeerDisplayName,
        publicContactLabel,
        scrubEmailsInText;
import 'kredi_store.dart';
import 'services/broadcast_push_service.dart';
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
  bool get isForum =>
      type == 'forum' ||
      type == 'forum_comment' ||
      type == 'forum_reply' ||
      type == 'forum_like' ||
      type == 'forum_follow';
  bool get isForumLike => type == 'forum_like';
  bool get isForumReply => type == 'forum_reply';
  bool get isForumComment =>
      type == 'forum_comment' || type == 'forum';
  bool get isForumFollow => type == 'forum_follow';

  /// Forum bildiriminde `ilan_id` → gönderi id.
  int? get forumPostId => ilanId;

  /// Forum bildiriminden yorum id (sohbet_key = c:123).
  int? get forumCommentId => parseForumCommentRef(sohbetKey);
  bool get isGorus =>
      type == 'gorus' ||
      type == 'dilek' ||
      type == 'sikayet' ||
      type == 'oneri' ||
      type == 'diger';

  bool get isKredi => type == 'kredi' || type == 'kredi_odeme';

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

Future<String?> _fetchIlanTitle(int ilanId) async {
  try {
    final row = await Supabase.instance.client
        .from('ilanlar')
        .select('title')
        .eq('id', ilanId)
        .maybeSingle();
    final t = row?['title']?.toString().trim() ?? '';
    return t.isEmpty ? null : t;
  } catch (_) {
    return null;
  }
}

/// İlan sahibine teklif bildirimi gönderir + sohbete ilk mesajı yazar.
/// Aynı kişi + aynı ilan için yalnızca 1 kez çalışır (peş peşe tıklamada spam yok).
/// Dönüş: `true` yeni teklif gitti, `false` zaten daha önce gönderilmiş.
Future<bool> notifyIlanSahibiTeklif({
  required String ownerEmail,
  required String actorName,
  int? ilanId,
  String? ilanTitle,
  String kind = 'uzman',
  String listingCategory = kIlanCatUzmanAriyorum,
  String? userType,
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
  if (!canOfferOnIlan(
    kind: kind,
    userType: userType ?? currentAuthUserType(),
    email: user.email,
    listingCategory: listingCategory,
  )) {
    throw StateError(
      kind == 'ikinciel'
          ? 'Bu ilana teklif veremezsiniz.'
          : 'Teklif vermek için Uzman veya Bakıcı rolü gerekir (1 puan).',
    );
  }

  // Zaten teklif var mı? (çift tıklama / yarış durumu)
  try {
    var q = client
        .from('bildirimler')
        .select('id')
        .eq('actor_email', actorEmail)
        .eq('owner_email', owner)
        .eq('type', 'teklif');
    q = ilanId != null ? q.eq('ilan_id', ilanId) : q.isFilter('ilan_id', null);
    final existing = await q.limit(1);
    if (existing.isNotEmpty) {
      return false;
    }
  } catch (_) {
    // RLS / tablo yoksa insert denemesine devam; unique index varsa yine korur.
  }

  final name = chatPeerDisplayName(
    actorEmail,
    profileName: actorName,
  );
  final key = sohbetKeyFor(actorEmail, owner);

  var title = (ilanTitle ?? '').trim();
  if (title.isEmpty && ilanId != null) {
    title = (await _fetchIlanTitle(ilanId)) ?? '';
  }
  final forIlan = title.isEmpty ? 'ilanınız' : '$title ilanınız';
  final notifyBody = '$name, $forIlan için teklif verdi.';
  final chatBody =
      'Merhaba, $forIlan için teklif verdim. Görüşmek isterim.';

  try {
    await client.auth.refreshSession();
  } catch (_) {}

  try {
    await client.from('bildirimler').insert({
      'owner_email': owner,
      'actor_email': actorEmail,
      'actor_name': name,
      'type': 'teklif',
      'title': 'Yeni teklif',
      'body': notifyBody,
      'ilan_id': ilanId,
      'sohbet_key': key,
      'read': false,
    });
  } on PostgrestException catch (e) {
    if (e.code == '23505') return false;
    // Bildirim RLS keserse sohbet yine açılsın.
  } catch (_) {}

  await sendSohbetMesaj(
    peerEmail: owner,
    body: chatBody,
  );
  return true;
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

  final name = chatPeerDisplayName(
    actorEmail,
    profileName: actorName ?? '',
  );
  final raw = scrubEmailsInText(messageBody.trim());
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

  final name = publicContactLabel(
    actorEmail,
    preferredName: actorName ?? '',
  );
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

  final body = '$name\n\n$msg';
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

/// İyilik puanı / puan yükleme → admin hesabına bildirim.
Future<void> notifyAdminKrediYukleme({
  required int adet,
  required String birimLabel,
  String? actorName,
  String kaynak = 'mağaza',
  String? paketFiyat,
  String? referansKodu,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final actorEmail = (user?.email ?? '').trim().toLowerCase();
  if (user == null || actorEmail.isEmpty || adet <= 0) return;

  final name = publicContactLabel(
    actorEmail,
    preferredName: actorName ?? '',
  );
  final birim = birimLabel.trim().isEmpty ? 'puan' : birimLabel.trim();
  final kaynakLabel = kaynak.trim().isEmpty ? 'mağaza' : kaynak.trim();
  final fiyat = (paketFiyat ?? '').trim();
  final ref = (referansKodu ?? '').trim();

  final bodyParts = <String>[
    '$name ($actorEmail)',
    '+$adet $birim yüklendi',
    'Kaynak: $kaynakLabel',
    if (fiyat.isNotEmpty) 'Tutar: $fiyat',
    if (ref.isNotEmpty) 'Referans: $ref',
  ];
  final body = bodyParts.join('\n');

  final rows = <Map<String, dynamic>>[
    for (final admin in kAppAdminEmails)
      if (admin.trim().isNotEmpty &&
          admin.trim().toLowerCase() != actorEmail)
        {
          'owner_email': admin.trim().toLowerCase(),
          'actor_email': actorEmail,
          'actor_name': name,
          'type': 'kredi',
          'title': kaynakLabel.contains('onay bekliyor')
              ? 'Ödeme bildirimi: +$adet $birim'
              : 'Puan yükleme: +$adet $birim',
          'body': body.length > 1800 ? '${body.substring(0, 1800)}…' : body,
          'ilan_id': null,
          'sohbet_key': null,
          'read': false,
        },
  ];
  if (rows.isEmpty) return;
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

/// Alıcının tüm bildirimlerini siler (mesaj tipi dahil).
Future<void> deleteAllBildirimler() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null || me.isEmpty) {
    throw StateError('Bildirim silmek için giriş yapın.');
  }
  await client.from('bildirimler').delete().eq('owner_email', me);
}

Future<void> _insertBildirim({
  required String ownerEmail,
  required String actorName,
  required String type,
  required String title,
  required String body,
  int? ilanId,
  String? sohbetKey,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final actorEmail = (user?.email ?? '').trim().toLowerCase();
  final owner = ownerEmail.trim().toLowerCase();
  if (user == null || actorEmail.isEmpty || owner.isEmpty) return;
  if (owner == actorEmail) return;
  final safeBody =
      body.length > 1800 ? '${body.substring(0, 1800)}…' : body;
  try {
    await client.from('bildirimler').insert({
      'owner_email': owner,
      'actor_email': actorEmail,
      'actor_name': actorName.trim().isEmpty
          ? actorEmail.split('@').first
          : actorName.trim(),
      'type': type,
      'title': title,
      'body': safeBody,
      'ilan_id': ilanId,
      'sohbet_key': sohbetKey,
      'read': false,
    });
  } catch (_) {
    return;
  }

  // Uygulama içi zil + cihaza FCM (ekran kapalıyken de görünsün)
  final prefKey = switch (type) {
    'mesaj' || 'teklif' => 'mesajlar',
    'ilan' || 'ilan_yorum' => 'ilanlar',
    _ => 'forum',
  };
  unawaited(
    BroadcastPushService.instance.sendToUser(
      toEmail: owner,
      title: title,
      body: safeBody,
      prefKey: prefKey,
      data: {
        'type': type,
        if (ilanId != null) 'id': '$ilanId',
        if (sohbetKey != null) 'sohbet_key': sohbetKey,
      },
    ),
  );
}

/// Forum yorum referansı (bildirim → deep link).
String? forumCommentRef(int? commentId) {
  if (commentId == null || commentId <= 0) return null;
  return 'c:$commentId';
}

int? parseForumCommentRef(String? key) {
  final k = (key ?? '').trim();
  if (!k.startsWith('c:')) return null;
  return int.tryParse(k.substring(2));
}

/// Forum gönderisine yorum → gönderi sahibine.
Future<void> notifyForumPostComment({
  required String postOwnerEmail,
  required String actorName,
  required String postTitle,
  required String commentPreview,
  int? postId,
  int? commentId,
}) async {
  final title = postTitle.trim().isEmpty ? 'Forum gönderisi' : postTitle.trim();
  await _insertBildirim(
    ownerEmail: postOwnerEmail,
    actorName: actorName,
    type: 'forum_comment',
    title: 'Yeni yorum: $title',
    body: commentPreview.trim().isEmpty
        ? '$actorName gönderinize yorum yaptı.'
        : commentPreview.trim(),
    ilanId: postId,
    sohbetKey: forumCommentRef(commentId),
  );
}

/// Yoruma yanıt → yorum sahibine.
Future<void> notifyForumCommentReply({
  required String commentOwnerEmail,
  required String actorName,
  required String replyPreview,
  int? postId,
  int? commentId,
}) async {
  await _insertBildirim(
    ownerEmail: commentOwnerEmail,
    actorName: actorName,
    type: 'forum_reply',
    title: 'Yorumunuza yanıt geldi',
    body: replyPreview.trim().isEmpty
        ? '$actorName yorumunuza yanıt yazdı.'
        : replyPreview.trim(),
    ilanId: postId,
    sohbetKey: forumCommentRef(commentId),
  );
}

/// Yorum beğenisi → yorum sahibine (Facebook tarzı).
Future<void> notifyForumCommentLike({
  required String commentOwnerEmail,
  required String actorName,
  required String commentPreview,
  int? postId,
  int? commentId,
}) async {
  final preview = commentPreview.trim();
  await _insertBildirim(
    ownerEmail: commentOwnerEmail,
    actorName: actorName,
    type: 'forum_like',
    title: '$actorName yorumunuzu beğendi',
    body: preview.isEmpty ? 'Yorumunuz beğenildi.' : preview,
    ilanId: postId,
    sohbetKey: forumCommentRef(commentId),
  );
}

/// Gönderi beğenisi → gönderi sahibine.
Future<void> notifyForumPostLike({
  required String postOwnerEmail,
  required String actorName,
  required String postTitle,
  int? postId,
}) async {
  final title = postTitle.trim().isEmpty ? 'Forum gönderisi' : postTitle.trim();
  await _insertBildirim(
    ownerEmail: postOwnerEmail,
    actorName: actorName,
    type: 'forum_like',
    title: '$actorName gönderinizi beğendi',
    body: title,
    ilanId: postId,
  );
}

/// İlan değerlendirme/yorumu → ilan sahibine.
Future<void> notifyIlanYorum({
  required String ownerEmail,
  required String actorName,
  required String ilanTitle,
  required String reviewText,
  int? ilanId,
  int rating = 0,
}) async {
  final stars = rating > 0 ? ' ($rating★)' : '';
  await _insertBildirim(
    ownerEmail: ownerEmail,
    actorName: actorName,
    type: 'forum_comment',
    title: 'İlanınıza yorum$stars',
    body: reviewText.trim().isEmpty
        ? '$actorName “$ilanTitle” ilanınıza yorum yaptı.'
        : reviewText.trim(),
    ilanId: ilanId,
  );
}
