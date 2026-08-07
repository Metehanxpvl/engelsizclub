import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'bildirim_store.dart';
import 'data/forum_data.dart';
import 'forum_post_follow_store.dart';
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
  final tagsRaw = json['tags'];
  final tags = <String>[];
  if (tagsRaw is List) {
    for (final item in tagsRaw) {
      final s = item?.toString().trim() ?? '';
      if (s.isNotEmpty) tags.add(s.startsWith('#') ? s : '#$s');
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
    createdAt: created,
    tags: tags,
    pinned: json['pinned'] == true,
    expert: json['expert'] == true,
    likedByMe: likedByMe,
    anon: json['anon'] == true ||
        (json['author']?.toString() ?? '').trim().toLowerCase() == 'anonim',
    meslek: json['meslek']?.toString() ?? '',
    ownerEmail: (json['owner_email']?.toString() ?? '').toLowerCase(),
    photos: photos,
  );
}

ForumComment forumCommentFromRow(
  Map<String, dynamic> json, {
  bool likedByMe = false,
}) {
  final created =
      DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
  final colorVal = (json['avatar_color'] as num?)?.toInt() ?? 0xFFF4A832;
  final parentRaw = json['parent_id'];
  final parentId = parentRaw == null ? null : (parentRaw as num?)?.toInt();
  return ForumComment(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['author']?.toString() ?? 'Üye',
    text: json['body']?.toString() ?? '',
    time: forumRelativeTime(created),
    color: Color(colorVal),
    avatar: json['avatar']?.toString() ?? '',
    ownerEmail: (json['owner_email']?.toString() ?? '').toLowerCase(),
    parentId: (parentId != null && parentId > 0) ? parentId : null,
    likes: (json['likes'] as num?)?.toInt() ?? 0,
    likedByMe: likedByMe,
  );
}

Future<List<ForumPost>> loadForumPosts() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
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
    if (user != null) {
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
    }

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
  List<String> tags = const [],
  String? avatarPhoto,
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
  final photo = (avatarPhoto ?? '').trim();
  final avatar = anon
      ? 'A'
      : (photo.startsWith('data:image') ||
              photo.startsWith('http://') ||
              photo.startsWith('https://'))
          ? photo
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
  final diseaseId = _forumDiseaseIdFromCategory(category);
  if (diseaseId != null) {
    payload['disease_id'] = diseaseId;
  }
  final safePhotos = photos
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (safePhotos.isNotEmpty) {
    payload['photos'] = safePhotos;
  }
  if (tags.isNotEmpty) {
    payload['tags'] = tags;
  }

  try {
    final row =
        await client.from('forum_posts').insert(payload).select().single();
    return forumPostFromRow(Map<String, dynamic>.from(row));
  } catch (_) {
    payload.remove('meslek');
    payload.remove('photos');
    payload.remove('disease_id');
    payload.remove('tags');
    final row =
        await client.from('forum_posts').insert(payload).select().single();
    return forumPostFromRow(Map<String, dynamic>.from(row));
  }
}

String? _forumDiseaseIdFromCategory(String category) {
  final c = category.trim().toLowerCase();
  if (c.isEmpty) return 'genel';
  if (c.contains('otizm')) return 'otizm';
  if (c.contains('serebral') || c.contains('palsi')) return 'serebral-palsi';
  if (c.contains('down')) return 'down-sendromu';
  if (c.contains('sma')) return 'sma';
  if (c.contains('dehb')) return 'dehb';
  if (c.contains('gelişim') || c.contains('gelisim')) return 'gelisim-geriligi';
  if (c.contains('duyu')) return 'duyu-butunleme';
  if (c.contains('iletişim') || c.contains('iletisim')) {
    return 'iletisim-bozukluklari';
  }
  if (c.contains('nadir')) return 'nadir-hastaliklar';
  if (c.contains('genel') || c.contains('köşe') || c.contains('kose')) {
    return 'genel';
  }
  return 'genel';
}

Future<List<ForumComment>> loadForumComments(int postId) async {
  if (postId <= 0) return const [];
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  try {
    final rows = await client
        .from('forum_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true)
        .limit(300);
    final list = (rows as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    Set<int> liked = {};
    if (user != null) {
      try {
        final ids = list
            .map((e) => (e['id'] as num?)?.toInt())
            .whereType<int>()
            .where((id) => id > 0)
            .toList();
        if (ids.isNotEmpty) {
          final likeRows = await client
              .from('forum_comment_likes')
              .select('comment_id')
              .eq('owner_id', user.id)
              .inFilter('comment_id', ids);
          liked = {
            for (final e in (likeRows as List).whereType<Map>())
              if ((e['comment_id'] as num?) != null)
                (e['comment_id'] as num).toInt(),
          };
        }
      } catch (_) {}
    }

    return list
        .map(
          (e) => forumCommentFromRow(
            e,
            likedByMe: liked.contains((e['id'] as num?)?.toInt() ?? -1),
          ),
        )
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<ForumComment?> _findRecentDuplicateComment({
  required String ownerId,
  required int postId,
  required String body,
  int? parentId,
}) async {
  try {
    final since = DateTime.now()
        .toUtc()
        .subtract(const Duration(seconds: 30))
        .toIso8601String();
    late final dynamic rows;
    if (parentId != null && parentId > 0) {
      rows = await Supabase.instance.client
          .from('forum_comments')
          .select()
          .eq('post_id', postId)
          .eq('owner_id', ownerId)
          .eq('body', body)
          .eq('parent_id', parentId)
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(1);
    } else {
      rows = await Supabase.instance.client
          .from('forum_comments')
          .select()
          .eq('post_id', postId)
          .eq('owner_id', ownerId)
          .eq('body', body)
          .gte('created_at', since)
          .order('created_at', ascending: false)
          .limit(1);
    }
    final list = (rows as List).whereType<Map>().toList();
    if (list.isEmpty) return null;
    return forumCommentFromRow(Map<String, dynamic>.from(list.first));
  } catch (_) {
    return null;
  }
}

bool _isMissingOptionalCommentColumn(Object e) {
  final msg = e.toString().toLowerCase();
  // FK / constraint hataları parent_id içerir ama sütun vardır — tekrar insert etme
  if (msg.contains('foreign key') ||
      msg.contains('_fkey') ||
      msg.contains('violates')) {
    return false;
  }
  return (msg.contains('could not find') &&
          (msg.contains('parent_id') || msg.contains("'likes'"))) ||
      msg.contains('pgrst204') ||
      (msg.contains('42703') &&
          (msg.contains('parent_id') || msg.contains('likes'))) ||
      (msg.contains('schema cache') &&
          (msg.contains('parent_id') || msg.contains('likes')));
}

Future<ForumComment> addForumComment({
  required int postId,
  required String body,
  required String authorName,
  required String authorEmail,
  int? parentId,
  bool anon = false,
  String? avatarPhoto,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw StateError('Yorum için giriş yapın.');
  final text = body.trim();
  if (text.isEmpty) throw StateError('Boş yorum gönderilemez.');

  // Aynı metin az önce yazıldıysa ikinci insert yapma (çift gönderim koruması)
  final dup = await _findRecentDuplicateComment(
    ownerId: user.id,
    postId: postId,
    body: text,
    parentId: parentId,
  );
  if (dup != null) return dup;

  final name = anon
      ? 'Anonim'
      : (authorName.trim().isEmpty
          ? (user.email ?? 'Üye').split('@').first
          : authorName.trim());
  final photo = (avatarPhoto ?? '').trim();
  final avatar = anon
      ? '?'
      : (photo.startsWith('data:image') ||
              photo.startsWith('http://') ||
              photo.startsWith('https://'))
          ? photo
          : (name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?');

  final payload = <String, dynamic>{
    'post_id': postId,
    'author': name,
    'avatar': avatar,
    'avatar_color': anon
        ? const Color(0xFF94A3B8).toARGB32()
        : MetoColors.primary.toARGB32(),
    'body': text,
    'owner_email': authorEmail.trim().toLowerCase(),
    'owner_id': user.id,
    'likes': 0,
  };
  if (parentId != null && parentId > 0) {
    payload['parent_id'] = parentId;
  }

  Map<String, dynamic> row;
  try {
    row = Map<String, dynamic>.from(
      await client.from('forum_comments').insert(payload).select().single(),
    );
  } catch (e) {
    // Insert belki oldu, select patladı → önce kopyayı bul
    final afterFail = await _findRecentDuplicateComment(
      ownerId: user.id,
      postId: postId,
      body: text,
      parentId: parentId,
    );
    if (afterFail != null) return afterFail;

    if (!_isMissingOptionalCommentColumn(e)) rethrow;

    payload.remove('parent_id');
    payload.remove('likes');
    // Sade insert öncesi bir kez daha kontrol
    final again = await _findRecentDuplicateComment(
      ownerId: user.id,
      postId: postId,
      body: text,
      parentId: null,
    );
    if (again != null) return again;

    row = Map<String, dynamic>.from(
      await client.from('forum_comments').insert(payload).select().single(),
    );
  }

  try {
    final post = await client
        .from('forum_posts')
        .select('comments, owner_email, title')
        .eq('id', postId)
        .maybeSingle();
    final current = (post?['comments'] as num?)?.toInt() ?? 0;
    await client
        .from('forum_posts')
        .update({'comments': current + 1}).eq('id', postId);

    final me = authorEmail.trim().toLowerCase();
    final postOwner = (post?['owner_email']?.toString() ?? '').toLowerCase();
    final postTitle = post?['title']?.toString() ?? '';
    final newCommentId = (row['id'] as num?)?.toInt();
    String? parentOwner;
    final effectiveParentId =
        (row['parent_id'] as num?)?.toInt() ?? parentId;
    if (effectiveParentId != null && effectiveParentId > 0) {
      try {
        final parent = await client
            .from('forum_comments')
            .select('owner_email')
            .eq('id', effectiveParentId)
            .maybeSingle();
        parentOwner = (parent?['owner_email']?.toString() ?? '').toLowerCase();
      } catch (_) {}
      if (parentOwner != null &&
          parentOwner.isNotEmpty &&
          parentOwner != me) {
        await notifyForumCommentReply(
          commentOwnerEmail: parentOwner,
          actorName: name,
          replyPreview: text,
          postId: postId,
          commentId: newCommentId,
        );
      }
    }
    if (postOwner.isNotEmpty &&
        postOwner != me &&
        postOwner != parentOwner) {
      await notifyForumPostComment(
        postOwnerEmail: postOwner,
        actorName: name,
        postTitle: postTitle,
        commentPreview: text,
        postId: postId,
        commentId: newCommentId,
      );
    }
    // Gönderiyi takip edenlere + daha önce yorum yazanlara
    await ForumPostFollowStore.notifyFollowersOfComment(
      postId: postId,
      postTitle: postTitle,
      actorName: name,
      actorEmail: me,
      commentPreview: text,
      commentId: newCommentId,
      excludeEmails: {
        if (postOwner.isNotEmpty) postOwner,
        if (parentOwner != null && parentOwner.isNotEmpty) parentOwner,
      },
    );
    // Yorum yazan, bu gönderiden bildirim almaya başlar (mute değilse)
    await ForumPostFollowStore.ensureFollowingAfterComment(
      email: me,
      postId: postId,
    );
  } catch (_) {}

  return forumCommentFromRow(row);
}

/// Yorum beğenisini aç/kapa.
Future<({bool liked, int likes})> toggleForumCommentLike(int commentId) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw StateError('Beğeni için giriş yapın.');
  if (commentId <= 0) throw StateError('Geçersiz yorum.');

  final existing = await client
      .from('forum_comment_likes')
      .select('id')
      .eq('comment_id', commentId)
      .eq('owner_id', user.id)
      .maybeSingle();

  final comment = await client
      .from('forum_comments')
      .select('likes')
      .eq('id', commentId)
      .maybeSingle();
  var likes = (comment?['likes'] as num?)?.toInt() ?? 0;

  if (existing != null) {
    await client
        .from('forum_comment_likes')
        .delete()
        .eq('comment_id', commentId)
        .eq('owner_id', user.id);
    likes = (likes - 1).clamp(0, 999999);
    await client
        .from('forum_comments')
        .update({'likes': likes}).eq('id', commentId);
    return (liked: false, likes: likes);
  }

  await client.from('forum_comment_likes').insert({
    'comment_id': commentId,
    'owner_id': user.id,
    'owner_email': (user.email ?? '').toLowerCase(),
  });
  likes = likes + 1;
  await client
      .from('forum_comments')
      .update({'likes': likes}).eq('id', commentId);

  try {
    final full = await client
        .from('forum_comments')
        .select('owner_email, body, post_id, author')
        .eq('id', commentId)
        .maybeSingle();
    final owner = (full?['owner_email']?.toString() ?? '').toLowerCase();
    final preview = full?['body']?.toString() ?? '';
    final postId = (full?['post_id'] as num?)?.toInt();
    final me = (user.email ?? '').trim().toLowerCase();
    final actorName = (user.userMetadata?['name']?.toString() ?? '')
            .trim()
            .isNotEmpty
        ? user.userMetadata!['name'].toString().trim()
        : (user.email ?? 'Birisi').split('@').first;
    if (owner.isNotEmpty && owner != me) {
      await notifyForumCommentLike(
        commentOwnerEmail: owner,
        actorName: actorName,
        commentPreview: preview,
        postId: postId,
        commentId: commentId,
      );
    }
  } catch (_) {}

  return (liked: true, likes: likes);
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
      .select('likes, owner_email, title')
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

  try {
    final owner = (post?['owner_email']?.toString() ?? '').toLowerCase();
    final title = post?['title']?.toString() ?? '';
    final me = (user.email ?? '').trim().toLowerCase();
    final actorName = (user.userMetadata?['name']?.toString() ?? '')
            .trim()
            .isNotEmpty
        ? user.userMetadata!['name'].toString().trim()
        : (user.email ?? 'Birisi').split('@').first;
    if (owner.isNotEmpty && owner != me) {
      await notifyForumPostLike(
        postOwnerEmail: owner,
        actorName: actorName,
        postTitle: title,
        postId: postId,
      );
    }
  } catch (_) {}

  return (liked: true, likes: likes);
}

Future<ForumPost> updateForumPost({
  required int postId,
  required String title,
  required String content,
  required String category,
  bool expert = false,
  String meslek = '',
  List<String> photos = const [],
  List<String> tags = const [],
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    throw StateError('Düzenlemek için giriş yapın.');
  }
  if (postId <= 0) throw StateError('Geçersiz gönderi.');

  final diseaseId = _forumDiseaseIdFromCategory(category);
  final payload = <String, dynamic>{
    'category': category.trim(),
    'title': title.trim(),
    'content': content.trim(),
    'expert': expert,
    'meslek': meslek.trim(),
    'photos': photos
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .take(2)
        .toList(growable: false),
    'tags': tags,
    if (diseaseId != null) 'disease_id': diseaseId,
  };

  try {
    final row = await client
        .from('forum_posts')
        .update(payload)
        .eq('id', postId)
        .eq('owner_id', user.id)
        .select()
        .maybeSingle();
    if (row == null) {
      throw StateError('Gönderi güncellenemedi (yetki yok veya bulunamadı).');
    }
    return forumPostFromRow(Map<String, dynamic>.from(row));
  } catch (e) {
    if (e is StateError) rethrow;
    // photos/tags sütunu yoksa düşürerek dene
    payload.remove('photos');
    payload.remove('tags');
    payload.remove('disease_id');
    final row = await client
        .from('forum_posts')
        .update(payload)
        .eq('id', postId)
        .eq('owner_id', user.id)
        .select()
        .maybeSingle();
    if (row == null) {
      throw StateError('Gönderi güncellenemedi: $e');
    }
    return forumPostFromRow(Map<String, dynamic>.from(row));
  }
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

  // Yanıtlar dahil kaç satır silinecek (sayaç için)
  var removeCount = 1;
  try {
    final kids = await client
        .from('forum_comments')
        .select('id')
        .eq('parent_id', commentId);
    removeCount += (kids as List).length;
  } catch (_) {}

  Future<void> bumpCounter() async {
    try {
      final post = await client
          .from('forum_posts')
          .select('comments')
          .eq('id', postId)
          .maybeSingle();
      final current = (post?['comments'] as num?)?.toInt() ?? 0;
      await client.from('forum_posts').update({
        'comments': (current - removeCount).clamp(0, 999999),
      }).eq('id', postId);
    } catch (_) {}
  }

  if (isAppAdmin(me)) {
    try {
      await client.rpc(
        'admin_delete_forum_comment',
        params: {'p_id': commentId},
      );
      await bumpCounter();
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
  await bumpCounter();
}
