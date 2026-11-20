import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';

const kDidYouKnowTitle = 'Bunu biliyor musunuz?';
const kDidYouKnowType = 'biliyor_muydunuz';
const kDidYouKnowSource = 'did_you_know';
const kDidYouKnowMaxChars = 800;

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
    if (requireAdmin && !isAppAdmin(user.email)) {
      debugPrint('broadcast-push: admin değil, atlandı');
      return false;
    }

    final img = (imageUrl ?? '').trim();
    final safeImage =
        img.startsWith('https://') && !img.startsWith('https://data:')
            ? img
            : null;

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'broadcast-push',
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

  /// Admin serbest mesaj: başlık «Bunu biliyor musunuz?», gövde admin metni.
  /// Kayıt `admin_send_did_you_know` ile duyurulara eklenir (ana sayfa köşesi),
  /// bildirim `duyurular` topic'ine gider.
  Future<bool> biliyorMuydunuz({
    required String message,
    String? adminEmail,
  }) async {
    final body = didYouKnowPushBody(message);
    if (body.isEmpty) return false;
    final clipped = body.length > kDidYouKnowMaxChars
        ? body.substring(0, kDidYouKnowMaxChars).trim()
        : body;

    var saved = false;
    try {
      await Supabase.instance.client.rpc(
        'admin_send_did_you_know',
        params: {'p_body': clipped},
      );
      saved = true;
    } catch (e) {
      debugPrint('did-you-know rpc: $e');
    }

    final pushed = await sendToTopic(
      topic: 'duyurular',
      title: kDidYouKnowTitle,
      body: clipped,
      data: {
        'type': kDidYouKnowType,
        'text': clipped,
      },
      requireAdmin: !isAppAdmin(adminEmail),
    );
    return saved || pushed;
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

  Future<bool> yeniIlan({
    required String title,
    required String kind,
    String? ilanId,
  }) =>
      sendToTopic(
        topic: 'ilanlar',
        title: 'Yeni ilan',
        body: title,
        data: {
          'type': 'ilan',
          'kind': kind,
          if (ilanId != null) 'id': ilanId,
        },
      );

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
      final res = await Supabase.instance.client.functions.invoke(
        'broadcast-push',
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
