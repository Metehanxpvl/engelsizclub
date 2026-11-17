import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'l10n/l10n_text.dart';
import 'services/broadcast_push_service.dart';

const kSectionBroadcastTypes = {'gezi', 'kampanya', 'etkinlik', 'kariyer'};

String sectionBroadcastTitle({
  required String type,
  required String title,
}) {
  final t = title.trim();
  switch (type) {
    case 'gezi':
      return t.isEmpty ? 'Yeni gezi yeri yayınlandı' : 'Gezi Rehberi: $t';
    case 'kampanya':
      return t.isEmpty ? 'Yeni kampanya yayınlandı' : 'Kampanya: $t';
    case 'etkinlik':
      return t.isEmpty ? 'Yeni etkinlik yayınlandı' : 'Etkinlik: $t';
    case 'kariyer':
      return t.isEmpty ? 'Yeni iş ilanı yayınlandı' : 'Engelsiz Kariyer: $t';
    default:
      return t.isEmpty ? 'Yeni içerik yayınlandı' : t;
  }
}

String sectionBroadcastBody({
  required String type,
  String description = '',
  String location = '',
}) {
  final loc = location.trim();
  final where = loc.isEmpty ? '' : ' ($loc)';
  final desc = description.trim();
  switch (type) {
    case 'gezi':
      return desc.isEmpty
          ? 'Gezi Rehberi’nde yeni bir yer$where yayınlandı. İncelemek için tıklayın.'
          : desc;
    case 'kampanya':
      return desc.isEmpty
          ? 'Kampanyalar’da yeni bir kampanya$where yayınlandı. İncelemek için tıklayın.'
          : desc;
    case 'etkinlik':
      return desc.isEmpty
          ? 'Etkinlikler’de yeni bir etkinlik$where yayınlandı. İncelemek için tıklayın.'
          : desc;
    case 'kariyer':
      return desc.isEmpty
          ? 'Engelsiz Kariyer’de yeni bir ilan$where yayınlandı. İncelemek için tıklayın.'
          : desc;
    default:
      return desc.isEmpty ? 'İncelemek için tıklayın.' : desc;
  }
}

String sectionBroadcastRef(String type, String id) {
  final key = id.trim();
  switch (type) {
    case 'gezi':
      return 'gz:$key';
    case 'kampanya':
      return 'kp:$key';
    case 'etkinlik':
      return 'et:$key';
    case 'kariyer':
      return 'kr:$key';
    default:
      return key;
  }
}

String _clip(String text) {
  final t = text.trim();
  if (t.length <= 1800) return t;
  return '${t.substring(0, 1800)}…';
}

Future<bool> confirmKullanicilaraBildir(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const L10nText('Kullanıcılara bildir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.35)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const L10nText('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const L10nText('Gönder'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Admin: tüm üyelere zil + duyurular FCM konusu.
Future<int> notifySectionItemToMembers({
  required String type,
  required String title,
  required String body,
  String imageUrl = '',
  int? itemId,
  String sohbetKey = '',
}) async {
  final kind = type.trim().toLowerCase();
  if (!kSectionBroadcastTypes.contains(kind)) {
    throw StateError('Geçersiz bildirim türü.');
  }
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null || me.isEmpty || !isAppAdmin(me)) {
    throw StateError('Bu bildirimi yalnızca yönetici gönderebilir.');
  }

  final notifTitle = title.trim().isEmpty ? 'Yeni içerik yayınlandı' : title.trim();
  final notifBody = _clip(body);
  final photo = imageUrl.trim();
  final ref = sohbetKey.trim();

  unawaited(
    BroadcastPushService.instance.sendToTopic(
      topic: 'duyurular',
      title: notifTitle,
      body: notifBody.isEmpty ? notifTitle : notifBody,
      imageUrl: photo,
      data: {
        'type': kind,
        if (itemId != null && itemId > 0) 'id': '$itemId',
        if (ref.isNotEmpty) 'sohbet_key': ref,
      },
      requireAdmin: true,
    ),
  );

  try {
    final rawUsers = await client.rpc(
      'admin_list_users',
      params: {
        'p_q': '',
        'p_filter': 'all',
        'p_limit': 4000,
      },
    );
    final users = rawUsers is List ? rawUsers : const [];
    final rows = <Map<String, dynamic>>[];
    for (final u in users) {
      if (u is! Map) continue;
      final email = (u['owner_email'] ?? '').toString().trim().toLowerCase();
      if (email.isEmpty || email == me) continue;
      rows.add({
        'owner_email': email,
        'actor_email': me,
        'actor_name': 'Engelsiz Club',
        'type': kind,
        'title': notifTitle,
        'body': notifBody,
        'ilan_id': itemId != null && itemId > 0 ? itemId : null,
        'sohbet_key': ref.isEmpty ? null : ref,
        'read': false,
      });
    }
    if (rows.isEmpty) return 0;

    const chunk = 80;
    var sent = 0;
    for (var i = 0; i < rows.length; i += chunk) {
      final end = i + chunk > rows.length ? rows.length : i + chunk;
      await client.from('bildirimler').insert(rows.sublist(i, end));
      sent += end - i;
    }
    return sent;
  } catch (_) {
    return 0;
  }
}
