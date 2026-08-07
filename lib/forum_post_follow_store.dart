import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/ilanlar_data.dart' show publicContactLabel;

/// Tek bir forum gönderisini takip (yorum / etkileşim bildirimi).
class ForumPostFollowStore {
  ForumPostFollowStore._();

  static Future<bool> isFollowing({
    required String email,
    required int postId,
  }) async {
    final owner = email.trim().toLowerCase();
    if (owner.isEmpty || postId <= 0) return false;
    try {
      final row = await Supabase.instance.client
          .from('forum_post_follows')
          .select('id, notify_enabled')
          .eq('owner_email', owner)
          .eq('post_id', postId)
          .maybeSingle();
      if (row == null) return false;
      // Kolon yoksa / null gelirse eski davranış: satır varsa açık
      return row['notify_enabled'] != false;
    } catch (_) {
      try {
        final row = await Supabase.instance.client
            .from('forum_post_follows')
            .select('id')
            .eq('owner_email', owner)
            .eq('post_id', postId)
            .maybeSingle();
        return row != null;
      } catch (_) {
        return false;
      }
    }
  }

  /// Bildirim açık mı? Mute edilmişse false.
  static Future<bool> isMuted({
    required String email,
    required int postId,
  }) async {
    final owner = email.trim().toLowerCase();
    if (owner.isEmpty || postId <= 0) return false;
    try {
      final row = await Supabase.instance.client
          .from('forum_post_follows')
          .select('notify_enabled')
          .eq('owner_email', owner)
          .eq('post_id', postId)
          .maybeSingle();
      if (row == null) return false;
      return row['notify_enabled'] == false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setFollowing({
    required String email,
    required int postId,
    required bool follow,
  }) async {
    final owner = email.trim().toLowerCase();
    if (owner.isEmpty || postId <= 0) return;
    final client = Supabase.instance.client;
    if (follow) {
      try {
        await client.from('forum_post_follows').upsert(
          {
            'owner_email': owner,
            'post_id': postId,
            'notify_enabled': true,
          },
          onConflict: 'owner_email,post_id',
        );
      } catch (_) {
        await client.from('forum_post_follows').upsert(
          {
            'owner_email': owner,
            'post_id': postId,
          },
          onConflict: 'owner_email,post_id',
        );
      }
    } else {
      // Mute: satırı silme, bildirimleri kapat (yorum sonrası auto-follow yeniden açmasın)
      try {
        await client.from('forum_post_follows').upsert(
          {
            'owner_email': owner,
            'post_id': postId,
            'notify_enabled': false,
          },
          onConflict: 'owner_email,post_id',
        );
      } catch (_) {
        await client
            .from('forum_post_follows')
            .delete()
            .eq('owner_email', owner)
            .eq('post_id', postId);
      }
    }
  }

  /// Yorum sonrası: mute değilse bildirimi aç.
  static Future<void> ensureFollowingAfterComment({
    required String email,
    required int postId,
  }) async {
    final owner = email.trim().toLowerCase();
    if (owner.isEmpty || postId <= 0) return;
    if (await isMuted(email: owner, postId: postId)) return;
    await setFollowing(email: owner, postId: postId, follow: true);
  }

  static String _short(String t) {
    final s = t.trim();
    if (s.length <= 140) return s;
    return '${s.substring(0, 137)}…';
  }

  static String? _commentRef(int? commentId) {
    if (commentId == null || commentId <= 0) return null;
    return 'c:$commentId';
  }

  static Future<void> _insertCommentNotify({
    required String owner,
    required String actorEmail,
    required String actorName,
    required String postTitle,
    required String commentPreview,
    required int postId,
    int? commentId,
  }) async {
    final title = postTitle.trim().isEmpty
        ? 'Takip ettiğin gönderi'
        : postTitle.trim();
    final body = commentPreview.trim().isEmpty
        ? '$actorName yorum yaptı.'
        : _short(commentPreview);
    try {
      await Supabase.instance.client.from('bildirimler').insert({
        'owner_email': owner,
        'actor_email': actorEmail,
        'actor_name': actorName,
        'type': 'forum_follow',
        'title': title.length > 160
            ? 'Yeni yorum — ${title.substring(0, 140)}…'
            : 'Yeni yorum — $title',
        'body': body.length > 1800 ? '${body.substring(0, 1800)}…' : body,
        'ilan_id': postId,
        'sohbet_key': _commentRef(commentId),
        'read': false,
      });
    } catch (_) {}
  }

  /// Gönderiye yeni yorum → takipçiler + daha önce yorum yazanlar.
  /// Mute (`notify_enabled = false`) olanlara gitmez.
  static Future<void> notifyFollowersOfComment({
    required int postId,
    required String postTitle,
    required String actorName,
    required String actorEmail,
    required String commentPreview,
    int? commentId,
    Set<String> excludeEmails = const {},
  }) async {
    if (postId <= 0) return;
    final me = actorEmail.trim().toLowerCase();
    if (me.isEmpty) return;
    final skip = {
      me,
      for (final e in excludeEmails) e.trim().toLowerCase(),
    }..removeWhere((e) => e.isEmpty);

    final name = publicContactLabel(me, preferredName: actorName);
    final recipients = <String>{};

    try {
      final followRows = await Supabase.instance.client
          .from('forum_post_follows')
          .select('owner_email, notify_enabled')
          .eq('post_id', postId);
      for (final row in (followRows as List)) {
        final owner =
            (row['owner_email']?.toString() ?? '').trim().toLowerCase();
        if (owner.isEmpty || skip.contains(owner)) continue;
        if (row['notify_enabled'] == false) continue;
        recipients.add(owner);
      }
    } catch (_) {
      try {
        final followRows = await Supabase.instance.client
            .from('forum_post_follows')
            .select('owner_email')
            .eq('post_id', postId);
        for (final row in (followRows as List)) {
          final owner =
              (row['owner_email']?.toString() ?? '').trim().toLowerCase();
          if (owner.isEmpty || skip.contains(owner)) continue;
          recipients.add(owner);
        }
      } catch (_) {}
    }

    // Daha önce bu gönderiye yorum yazmış herkes (yanıt olmasa da)
    try {
      final commentRows = await Supabase.instance.client
          .from('forum_comments')
          .select('owner_email')
          .eq('post_id', postId);
      final muted = <String>{};
      try {
        final muteRows = await Supabase.instance.client
            .from('forum_post_follows')
            .select('owner_email')
            .eq('post_id', postId)
            .eq('notify_enabled', false);
        for (final row in (muteRows as List)) {
          final o =
              (row['owner_email']?.toString() ?? '').trim().toLowerCase();
          if (o.isNotEmpty) muted.add(o);
        }
      } catch (_) {}

      for (final row in (commentRows as List)) {
        final owner =
            (row['owner_email']?.toString() ?? '').trim().toLowerCase();
        if (owner.isEmpty || skip.contains(owner) || muted.contains(owner)) {
          continue;
        }
        recipients.add(owner);
      }
    } catch (_) {}

    for (final owner in recipients) {
      await _insertCommentNotify(
        owner: owner,
        actorEmail: me,
        actorName: name,
        postTitle: postTitle,
        commentPreview: commentPreview,
        postId: postId,
        commentId: commentId,
      );
    }
  }
}
