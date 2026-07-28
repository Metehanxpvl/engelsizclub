import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/forum_data.dart';
import 'meto_theme.dart';

String forumRelativeTime(DateTime createdAt) {
  final diff = DateTime.now().difference(createdAt.toLocal());
  if (diff.inMinutes < 1) return 'Az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} saat önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  final d = createdAt.toLocal();
  return '${d.day}.${d.month}.${d.year}';
}

ForumPost forumPostFromRow(
  Map<String, dynamic> json, {
  bool likedByMe = false,
}) {
  final created =
      DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
  final colorVal = (json['avatar_color'] as num?)?.toInt() ?? 0xFF1A6B4A;
  final photosRaw = json['photos'];
  final photos = <String>[];
  if (photosRaw is List) {
    for (final item in photosRaw) {
      final s = item?.toString() ?? '';
      if (s.isNotEmpty) photos.add(s);
    }
  }
  return ForumPost(
    id: (json['id'] as num?)?.toInt() ?? 0,
    author: json['author']?.toString() ?? 'Anonim',
    avatar: json['avatar']?.toString() ?? '?',
    avatarColor: Color(colorVal),
    category: json['category']?.toString() ?? 'Genel',
    title: json['title']?.toString() ?? '',
    content: json['content']?.toString() ?? '',
    likes: (json['likes'] as num?)?.toInt() ?? 0,
    comments: (json['comments'] as num?)?.toInt() ?? 0,
    time: forumRelativeTime(created),
    pinned: json['pinned'] == true,
    expert: json['expert'] == true,
    likedByMe: likedByMe,
    meslek: json['meslek']?.toString() ?? '',
    ownerEmail: (json['owner_email']?.toString() ?? '').toLowerCase(),
    photos: photos,
  );
}

ForumComment forumCommentFromRow(Map<String, dynamic> json) {
  final created =
      DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
  final colorVal = (json['avatar_color'] as num?)?.toInt() ?? 0xFFF4A832;
  return ForumComment(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['author']?.toString() ?? 'Üye',
    text: json['body']?.toString() ?? '',
    time: forumRelativeTime(created),
    color: Color(colorVal),
    ownerEmail: (json['owner_email']?.toString() ?? '').toLowerCase(),
  );
}

Future<List<ForumPost>> loadForumPosts() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const [];
  try {
    final rows = await client
        .from('forum_posts')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    final list = (rows as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    Set<int> liked = {};
    try {
      final likeRows = await client
          .from('forum_likes')
          .select('post_id')
          .eq('owner_id', user.id);
      liked = {
        for (final e in (likeRows as List).whereType<Map>())
          if ((e['post_id'] as num?) != null) (e['post_id'] as num).toInt(),
      };
    } catch (_) {}

    return list
        .map((e) => forumPostFromRow(
              e,
              likedByMe: liked.contains((e['id'] as num?)?.toInt() ?? -1),
            ))
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<ForumPost> publishForumPost({
  required String title,
  required String content,
  required String category,
  required String authorName,
  required String authorEmail,
  bool anon = false,
  bool expert = false,
  String meslek = '',
  List<String> photos = const [],
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    throw StateError('Forum paylaşımı için giriş yapın.');
  }
  final name = authorName.trim().isEmpty
      ? (user.email ?? 'Üye').split('@').first
      : authorName.trim();
  final author = anon ? 'Anonim' : name;
  final avatar = anon
      ? 'A'
      : (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?');

  final payload = <String, dynamic>{
    'author': author,
    'avatar': avatar,
    'avatar_color': MetoColors.primary.toARGB32(),
    'category': category,
    'title': title.trim(),
    'content': content.trim(),
    'likes': 0,
    'comments': 0,
    'pinned': false,
    'expert': expert,
    'anon': anon,
    'owner_email': authorEmail.trim().toLowerCase(),
    'owner_id': user.id,
  };
  // meslek sütunu yoksa insert yine çalışsın diye ayrı deneriz
  if (meslek.trim().isNotEmpty) {
    payload['meslek'] = meslek.trim();
  }
  final safePhotos = photos
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (safePhotos.isNotEmpty) {
    payload['photos'] = safePhotos;
  }

  try {
    final row =
        await client.from('forum_posts').insert(payload).select().single();
    return forumPostFromRow(Map<String, dynamic>.from(row));
  } catch (_) {
    payload.remove('meslek');
    payload.remove('photos');
    final row =
        await client.from('forum_posts').insert(payload).select().single();
    return forumPostFromRow(Map<String, dynamic>.from(row));
  }
}

Future<List<ForumComment>> loadForumComments(int postId) async {
  if (postId <= 0) return const [];
  try {
    final rows = await Supabase.instance.client
        .from('forum_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .limit(200);
    return (rows as List)
        .whereType<Map>()
        .map((e) => forumCommentFromRow(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<ForumComment> addForumComment({
  required int postId,
  required String body,
  required String authorName,
  required String authorEmail,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw StateError('Yorum için giriş yapın.');
  final text = body.trim();
  if (text.isEmpty) throw StateError('Boş yorum gönderilemez.');
  final name = authorName.trim().isEmpty
      ? (user.email ?? 'Üye').split('@').first
      : authorName.trim();
  final avatar = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?';

  final row = await client
      .from('forum_comments')
      .insert({
        'post_id': postId,
        'author': name,
        'avatar': avatar,
        'avatar_color': MetoColors.primary.toARGB32(),
        'body': text,
        'owner_email': authorEmail.trim().toLowerCase(),
        'owner_id': user.id,
      })
      .select()
      .single();

  try {
    final post = await client
        .from('forum_posts')
        .select('comments')
        .eq('id', postId)
        .maybeSingle();
    final current = (post?['comments'] as num?)?.toInt() ?? 0;
    await client
        .from('forum_posts')
        .update({'comments': current + 1}).eq('id', postId);
  } catch (_) {}

  return forumCommentFromRow(Map<String, dynamic>.from(row));
}

/// Beğeniyi aç/kapa. Yeni beğeni durumunu döner.
Future<({bool liked, int likes})> toggleForumLike(int postId) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw StateError('Beğeni için giriş yapın.');
  if (postId <= 0) throw StateError('Geçersiz gönderi.');

  final existing = await client
      .from('forum_likes')
      .select('id')
      .eq('post_id', postId)
      .eq('owner_id', user.id)
      .maybeSingle();

  final post = await client
      .from('forum_posts')
      .select('likes')
      .eq('id', postId)
      .maybeSingle();
  var likes = (post?['likes'] as num?)?.toInt() ?? 0;

  if (existing != null) {
    await client
        .from('forum_likes')
        .delete()
        .eq('post_id', postId)
        .eq('owner_id', user.id);
    likes = (likes - 1).clamp(0, 999999);
    await client.from('forum_posts').update({'likes': likes}).eq('id', postId);
    return (liked: false, likes: likes);
  }

  await client.from('forum_likes').insert({
    'post_id': postId,
    'owner_id': user.id,
    'owner_email': (user.email ?? '').toLowerCase(),
  });
  likes = likes + 1;
  await client.from('forum_posts').update({'likes': likes}).eq('id', postId);
  return (liked: true, likes: likes);
}

Future<void> deleteForumPost(int postId) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null) throw StateError('Silmek için giriş yapın.');
  if (postId <= 0) throw StateError('Geçersiz gönderi.');

  // Admin: SECURITY DEFINER RPC (RLS bypass) — yoksa doğrulamalı delete.
  if (isAppAdmin(me)) {
    try {
      await client.rpc('admin_delete_forum_post', params: {'p_id': postId});
      return;
    } catch (_) {
      // Fonksiyon henüz yoksa klasik delete + satır doğrulaması.
    }
  }

  var q = client.from('forum_posts').delete().eq('id', postId);
  if (!isAppAdmin(me)) {
    q = q.eq('owner_id', user.id);
  }
  final deleted = await q.select('id');
  if (deleted.isEmpty) {
    throw StateError(
      isAppAdmin(me)
          ? 'Admin silme yetkisi veritabanında yok. '
              'Supabase’de admin_moderation.sql dosyasını çalıştırın.'
          : 'Gönderi silinemedi (yetki yok veya bulunamadı).',
    );
  }
}

Future<void> deleteForumComment({
  required int commentId,
  required int postId,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final me = (user?.email ?? '').trim().toLowerCase();
  if (user == null) throw StateError('Silmek için giriş yapın.');
  if (commentId <= 0) throw StateError('Geçersiz yorum.');

  if (isAppAdmin(me)) {
    try {
      await client.rpc(
        'admin_delete_forum_comment',
        params: {'p_id': commentId},
      );
      try {
        final post = await client
            .from('forum_posts')
            .select('comments')
            .eq('id', postId)
            .maybeSingle();
        final current = (post?['comments'] as num?)?.toInt() ?? 0;
        await client.from('forum_posts').update({
          'comments': (current - 1).clamp(0, 999999),
        }).eq('id', postId);
      } catch (_) {}
      return;
    } catch (_) {}
  }

  var q = client.from('forum_comments').delete().eq('id', commentId);
  if (!isAppAdmin(me)) {
    q = q.eq('owner_id', user.id);
  }
  final deleted = await q.select('id');
  if (deleted.isEmpty) {
    throw StateError(
      isAppAdmin(me)
          ? 'Admin silme yetkisi veritabanında yok. '
              'Supabase’de admin_moderation.sql dosyasını çalıştırın.'
          : 'Yorum silinemedi (yetki yok veya bulunamadı).',
    );
  }
  try {
    final post = await client
        .from('forum_posts')
        .select('comments')
        .eq('id', postId)
        .maybeSingle();
    final current = (post?['comments'] as num?)?.toInt() ?? 0;
    await client.from('forum_posts').update({
      'comments': (current - 1).clamp(0, 999999),
    }).eq('id', postId);
  } catch (_) {}
}
