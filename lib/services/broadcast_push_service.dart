import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import 'force_update_logic.dart';

const kDidYouKnowTitle = 'Bunu biliyor musunuz?';
const kDidYouKnowType = 'biliyor_muydunuz';
const kDidYouKnowSource = 'did_you_know';
const kDidYouKnowMaxChars = 800;

/// 2. el ilanları (aile dahil, tercih açıksa).
const kIlanlarTopic = 'ilanlar';

/// Uzman / bakıcı / temizlikçi ilanları — yalnız uzman ve bakıcı rolü abone.
const kIlanlarProfTopic = 'ilanlar_prof';

bool isProfSeekIlanKind(String kind) {
  final k = kind.trim().toLowerCase();
  return k == 'uzman' || k == 'bakici';
}

String ilanPushTopicForKind(String kind) =>
    isProfSeekIlanKind(kind) ? kIlanlarProfTopic : kIlanlarTopic;

String didYouKnowPushBody(String message) => message.trim();

/// Supabase Edge Function `broadcast-push` — FCM topic bildirimi.
/// Secrets: `FCM_SERVER_KEY` (Firebase Cloud Messaging legacy server key)
class BroadcastPushService {
  BroadcastPushService._();
  static final BroadcastPushService instance = BroadcastPushService._();

  /// [imageUrl] yalnızca https public URL olmalı (data: desteklenmez).
  /// [requireAdmin]: duyuru için true; ilan/forum yayınında false.
  Future<bool> sendToTopic({
    required String topic,
    required String title,
    required String body,
    String? imageUrl,
    Map<String, String>? data,
    bool requireAdmin = false,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    if (requireAdmin) {
      var email = (user.email ?? '').trim().toLowerCase();
      if (!isAppAdmin(email)) {
        try {
          final row = await Supabase.instance.client
              .from('user_profiles')
              .select('owner_email')
              .eq('owner_id', user.id)
              .maybeSingle();
          email = (row?['owner_email'] as String? ?? '').trim().toLowerCase();
        } catch (_) {}
      }
      if (!isAppAdmin(email)) {
        debugPrint('broadcast-push: admin değil, atlandı');
        return false;
      }
    }

    final img = (imageUrl ?? '').trim();
    final safeImage =
        img.startsWith('https://') && !img.startsWith('https://data:')
            ? img
            : null;

    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final res = await Supabase.instance.client.functions.invoke(
        'broadcast-push',
        headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: {
          'topic': topic,
          'title': title,
          'body': body,
          if (safeImage != null) 'imageUrl': safeImage,
          if (data != null) 'data': data,
        },
      );
      final ok = res.status >= 200 && res.status < 300;
      if (!ok) {
        debugPrint('broadcast-push status=${res.status} data=${res.data}');
      }
      return ok;
    } catch (e) {
      debugPrint('broadcast-push hata: $e');
      return false;
    }
  }

  Future<bool> duyuru({
    required String title,
    required String body,
    String? imageUrl,
    String? duyuruId,
  }) =>
      sendToTopic(
        topic: 'duyurular',
        title: title,
        body: body.isEmpty ? 'Yeni duyuru' : body,
        imageUrl: imageUrl,
        data: {
          'type': 'duyuru',
          if (duyuruId != null) 'id': duyuruId,
        },
        requireAdmin: true,
      );

  /// Yeni kampanya: `duyurular` topic (cihazlar zaten abone).
  Future<bool> kampanya({
    required String title,
    required String body,
    String? imageUrl,
    String? kampanyaId,
  }) =>
      sendToTopic(
        topic: 'duyurular',
        title: title.isEmpty ? 'Yeni kampanya' : title,
        body: body.isEmpty ? 'Yeni bir kampanya eklendi.' : body,
        imageUrl: imageUrl,
        data: {
          'type': 'kampanya',
          if (kampanyaId != null) 'id': kampanyaId,
        },
        requireAdmin: true,
      );

  /// Admin: seçilen il / tüm ülke kampanya duyurusu.
  Future<bool> kampanyaSehir({
    required String title,
    required String body,
    String? city,
  }) =>
      sendToTopic(
        topic: 'duyurular',
        title: title.isEmpty ? 'Kampanyalar' : title,
        body: body.isEmpty
            ? 'Kampanyalar’da bugün yararlanabileceğiniz kampanyalar için lütfen göz atın.'
            : body,
        data: {
          'type': 'kampanya',
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        },
        requireAdmin: true,
      );

  /// Admin seçtiği günlük etkinlik: haberlerle aynı `duyurular` topic.
  Future<bool> etkinlik({
    required String title,
    required String body,
    String? imageUrl,
    String? etkinlikId,
  }) =>
      sendToTopic(
        topic: 'duyurular',
        title: title.isEmpty ? 'Etkinlik var' : title,
        body: body.isEmpty ? 'Etkinlik var' : body,
        imageUrl: imageUrl,
        data: {
          'type': 'etkinlik',
          if (etkinlikId != null) 'id': etkinlikId,
        },
        requireAdmin: true,
      );

  Future<bool> gelisim({
    required String title,
    required String body,
    String? etkinlikId,
  }) =>
      sendToTopic(
        topic: 'duyurular',
        title: title.isEmpty ? 'Yeni gelişim etkinliği' : title,
        body: body.isEmpty ? 'Gelişim Etkinlikleri’ne yeni içerik eklendi.' : body,
        data: {
          'type': 'gelisim',
          if (etkinlikId != null) 'id': etkinlikId,
        },
        requireAdmin: true,
      );

  /// Admin: bugünkü kamu / özel sektör ilan sayısı (haberlerle aynı topic).
  Future<bool> kariyer({
    required String title,
    required String body,
    String? sektor,
  }) =>
      sendToTopic(
        topic: 'duyurular',
        title: title.isEmpty ? 'Engelsiz Kariyer' : title,
        body: body.isEmpty ? 'Engelsiz Kariyer’de yeni iş ilanları var.' : body,
        data: {
          'type': 'kariyer',
          if (sektor != null && sektor.isNotEmpty) 'sektor': sektor,
        },
        requireAdmin: true,
      );

  /// Admin: seçilen il için Gezi Rehberi duyurusu (haberlerle aynı topic).
  Future<bool> gezi({
    required String title,
    required String body,
    String? city,
  }) =>
      sendToTopic(
        topic: 'duyurular',
        title: title.isEmpty ? 'Gezi Rehberi' : title,
        body: body.isEmpty
            ? 'Gezi Rehberi’nde bugün gezebileceğiniz yerler için lütfen göz atın.'
            : body,
        data: {
          'type': 'gezi',
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        },
        requireAdmin: true,
      );

  /// Admin serbest mesaj: başlık «Bunu biliyor muydunuz?», gövde admin metni.
  Future<bool> biliyorMuydunuz({
    required String message,
    String? adminEmail,
  }) async {
    final body = didYouKnowPushBody(message);
    if (body.isEmpty) return false;
    final clipped = body.length > kDidYouKnowMaxChars
        ? body.substring(0, kDidYouKnowMaxChars).trim()
        : body;

    // Yorum bildirimiyle aynı yol: pg_net → Edge `source=db` (functions JWT gerekmez).
    try {
      await Supabase.instance.client.rpc(
        'admin_send_did_you_know',
        params: {'p_body': clipped},
      );
      return true;
    } catch (e) {
      debugPrint('did-you-know rpc: $e');
    }

    return sendToTopic(
      topic: 'duyurular',
      title: kDidYouKnowTitle,
      body: clipped,
      data: {
        'type': kDidYouKnowType,
        'text': clipped,
      },
      requireAdmin: !isAppAdmin(adminEmail),
    );
  }

  /// Mağazada yeni sürüm. `duyurular` topic — mevcut cihazlar zaten abone.
  Future<bool> yeniSurum({
    required String version,
    required int build,
  }) {
    final ver = version.trim().isEmpty ? 'yeni sürüm' : version.trim();
    return sendToTopic(
      topic: 'duyurular',
      title: 'Yeni sürüm yayınlandı',
      body: 'Engelsiz Club $ver mağazada. Güncellemek için dokunun.',
      data: {
        'type': kAppUpdatePushType,
        'version': ver,
        'build': '$build',
      },
      requireAdmin: true,
    );
  }

  Future<bool> yeniIlan({
    required String title,
    required String kind,
    String? ilanId,
  }) {
    final k = kind.trim().toLowerCase();
    return sendToTopic(
      topic: ilanPushTopicForKind(k),
      title: 'Yeni ilan',
      body: title,
      data: {
        'type': 'ilan',
        'kind': k,
        if (ilanId != null && ilanId.trim().isNotEmpty) 'id': ilanId.trim(),
      },
    );
  }

  Future<bool> forumPost({
    required String title,
    String? postId,
  }) =>
      sendToTopic(
        topic: 'forum',
        title: 'Yeni forum paylaşımı',
        body: title,
        data: {
          'type': 'forum',
          if (postId != null) 'id': postId,
        },
      );

  /// Belirli kullanıcıya FCM (token tablosu + edge function).
  Future<bool> sendToUser({
    required String toEmail,
    required String title,
    required String body,
    String prefKey = 'forum',
    Map<String, String>? data,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    final target = toEmail.trim().toLowerCase();
    if (target.isEmpty) return false;
    final me = (user.email ?? '').trim().toLowerCase();
    if (target == me) return false;

    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken ?? '';
      final res = await Supabase.instance.client.functions.invoke(
        'broadcast-push',
        headers: {
          if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
        body: {
          'toEmail': target,
          'title': title,
          'body': body,
          'prefKey': prefKey,
          if (data != null) 'data': data,
        },
      );
      final ok = res.status >= 200 && res.status < 300;
      if (!ok) {
        debugPrint('user-push status=${res.status} data=${res.data}');
      }
      return ok;
    } catch (e) {
      debugPrint('user-push hata: $e');
      return false;
    }
  }
}
