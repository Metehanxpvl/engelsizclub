import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../utils/async_timeout.dart';
import 'kesfet_models.dart';
import 'kesfet_scoring.dart';

final _kesfetShuffleRng = Random();

/// Fisher-Yates. New permutation each call; does not mutate [input].
List<T> shuffleKesfetVideos<T>(List<T> input, [Random? random]) {
  final list = List<T>.of(input);
  final rng = random ?? _kesfetShuffleRng;
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final tmp = list[i];
    list[i] = list[j];
    list[j] = tmp;
  }
  return list;
}

bool _isMissingRelation(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('kesfet_') &&
      (s.contains('does not exist') ||
          s.contains('schema cache') ||
          s.contains('could not find the table') ||
          s.contains('42p01'));
}

class KesfetStore {
  KesfetStore._();
  static final KesfetStore instance = KesfetStore._();

  SupabaseClient get _c => Supabase.instance.client;

  List<KesfetKeyword>? _keywordCache;

  Future<List<KesfetKeyword>> loadKeywords({bool force = false}) async {
    if (!force && _keywordCache != null) return _keywordCache!;
    try {
      final rows = await withNetworkTimeout(
        _c.from('kesfet_keywords').select().order('polarity').order('phrase'),
      );
      final list = [
        for (final e in (rows as List).whereType<Map>())
          KesfetKeyword.fromRow(Map<String, dynamic>.from(e)),
      ].where((k) => k.phrase.trim().isNotEmpty).toList();
      _keywordCache = list.isEmpty ? kKesfetFallbackKeywords : list;
      return _keywordCache!;
    } catch (e) {
      if (_isMissingRelation(e)) return kKesfetFallbackKeywords;
      return _keywordCache ?? kKesfetFallbackKeywords;
    }
  }

  Future<KesfetScore> scoreFields({
    required String title,
    required String description,
    List<String> tags = const [],
    String channel = '',
  }) async {
    final keys = await loadKeywords();
    try {
      final raw = await withNetworkTimeout(
        _c.rpc('kesfet_score_text', params: {
          'p_title': title,
          'p_description': description,
          'p_tags': tags,
          'p_channel': channel,
        }),
      );
      if (raw is Map) {
        final m = Map<String, dynamic>.from(raw);
        final pos = <String>[];
        final neg = <String>[];
        final p = m['matched_positives'];
        final n = m['matched_negatives'];
        if (p is List) {
          for (final x in p) {
            final s = x?.toString() ?? '';
            if (s.isNotEmpty) pos.add(s);
          }
        }
        if (n is List) {
          for (final x in n) {
            final s = x?.toString() ?? '';
            if (s.isNotEmpty) neg.add(s);
          }
        }
        return KesfetScore(
          score: (m['score'] as num?)?.toInt() ?? 0,
          safetyFlag: m['safety_flag'] == true,
          suggestedCategory:
              m['suggested_category']?.toString() ?? 'engellilik',
          safetyNote: m['safety_note']?.toString() ?? '',
          matchedPositives: pos,
          matchedNegatives: neg,
        );
      }
    } catch (_) {}
    return scoreKesfetText(
      title: title,
      description: description,
      tags: tags,
      channel: channel,
      keywords: keys,
    );
  }

  Future<List<KesfetVideo>> fetchApproved({
    String category = 'sana-ozel',
    bool savedOnly = false,
  }) async {
    try {
      if (savedOnly) {
        final user = _c.auth.currentUser;
        if (user == null) return const [];
        final rows = await withNetworkTimeout(
          _c
              .from('kesfet_saves')
              .select('video_id, kesfet_videos(*)')
              .eq('owner_id', user.id)
              .order('created_at', ascending: false)
              .limit(80),
        );
        final videos = <KesfetVideo>[];
        for (final e in (rows as List).whereType<Map>()) {
          final v = e['kesfet_videos'];
          if (v is Map) {
            final video = KesfetVideo.fromRow(
              Map<String, dynamic>.from(v),
              savedByMe: true,
            );
            if (video.status == 'approved') videos.add(video);
          }
        }
        return _withMine(videos);
      }

      var q = _c.from('kesfet_videos').select().eq('status', 'approved');
      if (category.isNotEmpty && category != 'sana-ozel') {
        q = q.eq('category', category);
      }
      final rows = await withNetworkTimeout(
        q.order('published_at', ascending: false).limit(80),
      );
      final list = [
        for (final e in (rows as List).whereType<Map>())
          KesfetVideo.fromRow(Map<String, dynamic>.from(e)),
      ].where((v) => v.youtubeVideoId.isNotEmpty).toList();
      final withMine = await _withMine(list);
      return shuffleKesfetVideos(withMine);
    } catch (e) {
      if (_isMissingRelation(e)) return const [];
      rethrow;
    }
  }

  Future<List<KesfetVideo>> _withMine(List<KesfetVideo> list) async {
    final user = _c.auth.currentUser;
    if (user == null || list.isEmpty) return list;
    final ids = [for (final v in list) v.id];
    try {
      final likes = await _c
          .from('kesfet_likes')
          .select('video_id')
          .eq('owner_id', user.id)
          .inFilter('video_id', ids);
      final saves = await _c
          .from('kesfet_saves')
          .select('video_id')
          .eq('owner_id', user.id)
          .inFilter('video_id', ids);
      final liked = {
        for (final e in (likes as List).whereType<Map>())
          e['video_id']?.toString() ?? '',
      };
      final saved = {
        for (final e in (saves as List).whereType<Map>())
          e['video_id']?.toString() ?? '',
      };
      return [
        for (final v in list)
          v.copyWith(
            likedByMe: liked.contains(v.id),
            savedByMe: saved.contains(v.id),
          ),
      ];
    } catch (_) {
      return list;
    }
  }

  Future<List<KesfetVideo>> adminList(String status) async {
    if (!isAppAdmin(_c.auth.currentUser?.email)) {
      throw StateError('Yalnızca admin Keşfet içeriklerini görebilir.');
    }
    final rows = await withNetworkTimeout(
      _c
          .from('kesfet_videos')
          .select()
          .eq('status', status)
          .order('created_at', ascending: false)
          .limit(120),
    );
    return [
      for (final e in (rows as List).whereType<Map>())
        KesfetVideo.fromRow(Map<String, dynamic>.from(e)),
    ];
  }

  Future<KesfetVideo> adminUpsertVideo({
    required String youtubeVideoId,
    required String youtubeUrl,
    required String title,
    required String description,
    required String thumbnailUrl,
    required String channelName,
    required String channelUrl,
    required String category,
    required String status,
    required KesfetScore score,
    String relatedArticleId = '',
    String relatedArticleSlug = '',
    List<String> tags = const [],
    Map<String, dynamic>? oembed,
  }) async {
    final email = (_c.auth.currentUser?.email ?? '').trim().toLowerCase();
    if (!isAppAdmin(email)) {
      throw StateError('Yalnızca admin video ekleyebilir.');
    }
    final cat = category.trim().isEmpty || category == 'sana-ozel'
        ? score.suggestedCategory
        : category.trim();
    final payload = <String, dynamic>{
      'youtube_video_id': youtubeVideoId,
      'youtube_url': youtubeUrl,
      'title': title.trim(),
      'description': description.trim(),
      'thumbnail_url': thumbnailUrl.trim(),
      'channel_name': channelName.trim(),
      'channel_url': channelUrl.trim(),
      'category': cat,
      'tags': tags,
      'source_url': youtubeUrl,
      'related_article_id': relatedArticleId.trim().isEmpty
          ? null
          : relatedArticleId.trim(),
      'related_article_slug': relatedArticleSlug.trim(),
      'status': status,
      'relevance_score': score.score,
      'safety_flag': score.safetyFlag,
      'safety_note': score.safetyNote,
      'published_at': status == 'approved'
          ? DateTime.now().toUtc().toIso8601String()
          : null,
      'created_by_email': email,
      'crawl_source': 'manual',
      'oembed': oembed ?? {},
    };
    final row = Map<String, dynamic>.from(
      await _c
          .from('kesfet_videos')
          .upsert(payload, onConflict: 'youtube_video_id')
          .select()
          .single(),
    );
    return KesfetVideo.fromRow(row);
  }

  Future<void> adminSetStatus(String id, String status) async {
    if (!isAppAdmin(_c.auth.currentUser?.email)) {
      throw StateError('Yalnızca admin durum değiştirebilir.');
    }
    await _c.rpc('admin_kesfet_set_status', params: {
      'p_id': id,
      'p_status': status,
    });
  }

  Future<void> upsertKeyword(KesfetKeyword k) async {
    if (!isAppAdmin(_c.auth.currentUser?.email)) {
      throw StateError('Yalnızca admin anahtar kelime düzenleyebilir.');
    }
    final payload = {
      'phrase': k.phrase.trim().toLowerCase(),
      'polarity': k.polarity,
      'weight': k.weight,
      'category_hint': k.categoryHint,
      'is_weak': k.isWeak,
      'is_active': k.isActive,
    };
    if (k.id > 0) {
      await _c.from('kesfet_keywords').update(payload).eq('id', k.id);
    } else {
      await _c.from('kesfet_keywords').insert(payload);
    }
    _keywordCache = null;
  }

  Future<void> deleteKeyword(int id) async {
    if (!isAppAdmin(_c.auth.currentUser?.email)) {
      throw StateError('Yalnızca admin silebilir.');
    }
    await _c.from('kesfet_keywords').delete().eq('id', id);
    _keywordCache = null;
  }

  Future<List<KesfetReportRow>> adminReports() async {
    if (!isAppAdmin(_c.auth.currentUser?.email)) {
      throw StateError('Yalnızca admin raporları görebilir.');
    }
    final rows = await withNetworkTimeout(
      _c.rpc('admin_kesfet_list_reports', params: {'p_limit': 80}),
    );
    if (rows is! List) return const [];
    return [
      for (final e in rows.whereType<Map>())
        KesfetReportRow.fromRow(Map<String, dynamic>.from(e)),
    ];
  }

  Future<({bool liked, int likes})> toggleLike(KesfetVideo video) async {
    final user = _c.auth.currentUser;
    if (user == null) throw StateError('Beğeni için giriş yapın.');
    if (video.likedByMe) {
      await _c
          .from('kesfet_likes')
          .delete()
          .eq('video_id', video.id)
          .eq('owner_id', user.id);
      return (liked: false, likes: (video.likeCount - 1).clamp(0, 999999));
    }
    await _c.from('kesfet_likes').insert({
      'video_id': video.id,
      'owner_id': user.id,
      'owner_email': (user.email ?? '').toLowerCase(),
    });
    return (liked: true, likes: video.likeCount + 1);
  }

  Future<({bool saved, int saves})> toggleSave(KesfetVideo video) async {
    final user = _c.auth.currentUser;
    if (user == null) throw StateError('Kaydetmek için giriş yapın.');
    if (video.savedByMe) {
      await _c
          .from('kesfet_saves')
          .delete()
          .eq('video_id', video.id)
          .eq('owner_id', user.id);
      return (saved: false, saves: (video.saveCount - 1).clamp(0, 999999));
    }
    await _c.from('kesfet_saves').insert({
      'video_id': video.id,
      'owner_id': user.id,
      'owner_email': (user.email ?? '').toLowerCase(),
    });
    return (saved: true, saves: video.saveCount + 1);
  }

  Future<void> recordView(String videoId) async {
    final user = _c.auth.currentUser;
    if (user == null || videoId.isEmpty) return;
    try {
      await _c.from('kesfet_views').insert({
        'video_id': videoId,
        'owner_id': user.id,
        'owner_email': (user.email ?? '').toLowerCase(),
      });
    } catch (_) {}
  }

  Future<List<KesfetComment>> fetchComments(String videoId) async {
    final rows = await withNetworkTimeout(
      _c
          .from('kesfet_comments')
          .select()
          .eq('video_id', videoId)
          .order('created_at', ascending: false)
          .limit(80),
    );
    return [
      for (final e in (rows as List).whereType<Map>())
        KesfetComment.fromRow(Map<String, dynamic>.from(e)),
    ];
  }

  Future<KesfetComment> addComment({
    required String videoId,
    required String body,
    required String author,
  }) async {
    final user = _c.auth.currentUser;
    if (user == null) throw StateError('Yorum için giriş yapın.');
    final t = body.trim();
    if (t.isEmpty) throw StateError('Yorum boş olamaz.');
    final row = Map<String, dynamic>.from(
      await _c
          .from('kesfet_comments')
          .insert({
            'video_id': videoId,
            'body': t,
            'author': author.trim().isEmpty ? 'Üye' : author.trim(),
            'owner_id': user.id,
            'owner_email': (user.email ?? '').toLowerCase(),
          })
          .select()
          .single(),
    );
    return KesfetComment.fromRow(row);
  }

  Future<void> deleteComment(int id) async {
    await _c.from('kesfet_comments').delete().eq('id', id);
  }

  Future<void> reportVideo({
    required String videoId,
    required String reason,
  }) async {
    final user = _c.auth.currentUser;
    if (user == null) throw StateError('Bildirim için giriş yapın.');
    await _c.from('kesfet_reports').insert({
      'video_id': videoId,
      'reason': reason.trim(),
      'owner_id': user.id,
      'owner_email': (user.email ?? '').toLowerCase(),
    });
  }
}
