import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';

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
}
