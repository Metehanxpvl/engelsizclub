import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';

/// İstemci FCM yolu: yalnız Edge Function `broadcast-push`.
///
/// Auth: [functions.invoke] oturumdaki kullanıcı JWT’sini otomatik gönderir
/// (`supabase_flutter`). `NOTIFY_PUSH_SECRET`, service role ve
/// `FIREBASE_SERVICE_ACCOUNT_JSON` Flutter’a, dart-define’a veya git’e
/// konmaz. `notify-push` DB webhook / sunucu içindir; istemci çağırmaz.
class BroadcastPushService {
  BroadcastPushService._();
  static final BroadcastPushService instance = BroadcastPushService._();

  static const _timeout = Duration(seconds: 20);

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

    final heading = title.trim();
    if (heading.isEmpty) return false;

    final img = (imageUrl ?? '').trim();
    final safeImage =
        img.startsWith('https://') && !img.startsWith('https://data:')
            ? img
            : null;

    return _invoke({
      'topic': topic,
      'title': heading,
      'body': body,
      if (safeImage != null) 'imageUrl': safeImage,
      if (data != null && data.isNotEmpty) 'data': data,
    });
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
  ///
  /// [dedupeKey] / [bildirimId]: `notify-push` ile aynı anda çalışırsa tek FCM.
  /// Örnek:
  /// ```dart
  /// await BroadcastPushService.instance.sendToUser(
  ///   toEmail: 'alici@example.com',
  ///   title: 'Yeni mesaj',
  ///   body: "Engelsiz Club'da yeni bir mesajınız var.",
  ///   prefKey: 'mesajlar',
  ///   event: 'MESSAGE_RECEIVED',
  ///   dedupeKey: 'ins:mesaj:alici@example.com:ben@example.com:ab',
  ///   data: {'type': 'mesaj', 'event': 'MESSAGE_RECEIVED'},
  /// );
  /// ```
  Future<bool> sendToUser({
    required String toEmail,
    required String title,
    required String body,
    String prefKey = 'forum',
    String? event,
    int? bildirimId,
    String? dedupeKey,
    Map<String, String>? data,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;
    final target = toEmail.trim().toLowerCase();
    if (target.isEmpty) return false;
    final me = (user.email ?? '').trim().toLowerCase();
    if (target == me) return false;
    final heading = title.trim();
    if (heading.isEmpty) return false;

    return _invoke({
      'toEmail': target,
      'title': heading,
      'body': body,
      'prefKey': prefKey,
      if (event != null && event.isNotEmpty) 'event': event,
      if (bildirimId != null && bildirimId > 0) 'bildirimId': bildirimId,
      if (dedupeKey != null && dedupeKey.isNotEmpty) 'dedupeKey': dedupeKey,
      if (data != null && data.isNotEmpty) 'data': data,
    });
  }

  /// Kullanıcı JWT ile `broadcast-push`. Secret header yok.
  Future<bool> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await Supabase.instance.client.functions
          .invoke('broadcast-push', body: body)
          .timeout(_timeout);
      final ok = res.status >= 200 && res.status < 300;
      if (!ok) {
        debugPrint('broadcast-push status=${res.status} data=${res.data}');
      }
      return ok;
    } on FunctionException catch (e) {
      debugPrint(
        'broadcast-push FunctionException: ${e.status} ${e.reasonPhrase} ${e.details}',
      );
      return false;
    } on TimeoutException catch (e) {
      debugPrint('broadcast-push timeout: $e');
      return false;
    } catch (e) {
      debugPrint('broadcast-push hata: $e');
      return false;
    }
  }
}
