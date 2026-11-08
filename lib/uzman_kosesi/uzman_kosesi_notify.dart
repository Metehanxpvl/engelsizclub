import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../data/ilanlar_data.dart' show publicContactLabel;
import '../services/broadcast_push_service.dart';
import '../uzman_kosesi_profiles_store.dart';
import 'expert_cv_models.dart';

const kUzmanOnayBildirimTip = 'uzman_onay';

String uzmanOnayBildirimBaslik(ExpertCvProfile p) {
  final ad = p.fullName.trim();
  if (ad.isEmpty) return 'Uzman Onayları: yeni profil';
  return 'Uzman Onayları: $ad';
}

String uzmanOnayBildirimMetni(ExpertCvProfile p) {
  final ad = p.fullName.trim().isEmpty ? 'Bir üye' : p.fullName.trim();
  final meslek = p.meslekEtiket.trim();
  final yer = p.yerLabel;
  final job = meslek.isEmpty ? 'uzman profili' : '$meslek profili';
  final where = yer.isEmpty ? '' : ' ($yer)';
  return '$ad$where $job onay bekliyor. Uzman Onayları’ndan inceleyin.';
}

String uzmanOnayBildirimRef(int profileId) => 'uo:$profileId';

/// Üye yayınlayınca (pending) admin zil + FCM.
Future<void> notifyAdminUzmanOnay(ExpertCvProfile profile) async {
  if (profile.id <= 0 || isAppAdmin(profile.ownerEmail)) return;
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final actorEmail = (user?.email ?? profile.ownerEmail).trim().toLowerCase();
  if (user == null || actorEmail.isEmpty) return;

  final title = uzmanOnayBildirimBaslik(profile);
  final body = uzmanOnayBildirimMetni(profile);
  final name = publicContactLabel(
    actorEmail,
    preferredName: profile.fullName,
  );
  final ref = uzmanOnayBildirimRef(profile.id);

  for (final admin in kAppAdminEmails) {
    final owner = admin.trim().toLowerCase();
    if (owner.isEmpty || owner == actorEmail) continue;
    try {
      final existing = await client
          .from('bildirimler')
          .select('id')
          .eq('owner_email', owner)
          .eq('type', kUzmanOnayBildirimTip)
          .eq('sohbet_key', ref)
          .eq('read', false)
          .limit(1);
      if (existing.isEmpty) {
        await client.from('bildirimler').insert({
          'owner_email': owner,
          'actor_email': actorEmail,
          'actor_name': name,
          'type': kUzmanOnayBildirimTip,
          'title': title,
          'body': body.length > 1800 ? '${body.substring(0, 1800)}…' : body,
          'ilan_id': profile.id,
          'sohbet_key': ref,
          'read': false,
        });
      }
    } catch (_) {}
    unawaited(
      BroadcastPushService.instance.sendToUser(
        toEmail: owner,
        title: title,
        body: body,
        prefKey: 'admin',
        data: {
          'type': kUzmanOnayBildirimTip,
          'id': '${profile.id}',
          'sohbet_key': ref,
        },
      ),
    );
  }
}

String uzmanProfilYayinBildirimBaslik(UzmanKosesProfil p) {
  final meslek = p.meslek.trim().isEmpty ? 'uzman' : p.meslek.trim();
  final ad = p.fullName.trim();
  if (ad.isEmpty) return 'Yeni $meslek profili yayınlandı';
  return '$ad · $meslek profili yayınlandı';
}

String uzmanProfilYayinBildirimMetni(UzmanKosesProfil p) {
  final meslek = p.meslek.trim().isEmpty ? 'uzman' : p.meslek.trim();
  final ad = p.fullName.trim();
  final yer = p.yerLabel;
  final who = ad.isEmpty ? 'Bir $meslek' : ad;
  final where = yer.isEmpty ? '' : ' ($yer)';
  return '$who$where $meslek profili Uzman Profilleri Köşesi’nde yayınlandı. '
      'İncelemek için tıklayın.';
}

/// Admin: tüm üyelere zil + duyurular FCM konusu.
Future<int> notifyUzmanProfilYayinlandi(UzmanKosesProfil profile) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null || me.isEmpty || !isAppAdmin(me)) {
    throw StateError('Bu bildirimi yalnızca yönetici gönderebilir.');
  }

  final title = uzmanProfilYayinBildirimBaslik(profile);
  final body = uzmanProfilYayinBildirimMetni(profile);
  final ownerId = profile.ownerId.trim();
  final ownerEmail = profile.ownerEmail.trim().toLowerCase();
  final ref = ownerId.isNotEmpty ? ownerId : ownerEmail;
  final photo = profile.photoUrl.trim();

  unawaited(
    BroadcastPushService.instance.sendToTopic(
      topic: 'duyurular',
      title: title,
      body: body,
      imageUrl: photo,
      data: {
        'type': 'uzman_kosesi',
        if (profile.id > 0) 'id': '${profile.id}',
        if (ownerId.isNotEmpty) 'owner_id': ownerId,
        if (ownerEmail.isNotEmpty) 'owner_email': ownerEmail,
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
        'type': 'uzman_kosesi',
        'title': title,
        'body': body,
        'ilan_id': profile.id > 0 ? profile.id : null,
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
