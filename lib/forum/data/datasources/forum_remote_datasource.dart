import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/forum_disease.dart';
import '../../domain/entities/forum_topic.dart';
import '../../../content_view_store.dart';

class ForumRemoteDataSource {
  ForumRemoteDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<ForumDisease>> fetchDiseases() async {
    try {
      final rows = await _client
          .from('forum_diseases')
          .select()
          .eq('is_active', true)
          .order('sort_order');
      return (rows as List)
          .whereType<Map>()
          .map((e) => ForumDisease.fromJson(Map<String, dynamic>.from(e)))
          .where((d) => d.id.isNotEmpty)
          .toList();
    } catch (_) {
      return _fallbackDiseases;
    }
  }

  Future<List<ForumSubCategory>> fetchSubCategories({String? diseaseId}) async {
    try {
      var q = _client
          .from('forum_sub_categories')
          .select()
          .eq('is_active', true);
      final id = diseaseId?.trim();
      if (id != null && id.isNotEmpty) {
        q = q.eq('disease_id', id);
      }
      final rows = await q.order('sort_order');
      return (rows as List)
          .whereType<Map>()
          .map((e) => ForumSubCategory.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<ForumTopicsPage> fetchTopics({
    required ForumFilterParams filter,
    required int page,
    int pageSize = 20,
  }) async {
    final safePage = page < 0 ? 0 : page;
    final from = safePage * pageSize;
    final to = from + pageSize; // inclusive upper bound +1 for hasMore probe

    try {
      var query = _client.from('forum_posts').select(
            'id, author, avatar, avatar_color, category, title, content, likes, comments, pinned, expert, anon, meslek, owner_email, photos, created_at, disease_id, sub_category_id, age_group, tags, views, is_resolved',
          );

      final diseaseId = filter.diseaseId?.trim();
      if (diseaseId != null && diseaseId.isNotEmpty) {
        query = query.eq('disease_id', diseaseId);
      }
      final subId = filter.subCategoryId?.trim();
      if (subId != null && subId.isNotEmpty) {
        query = query.eq('sub_category_id', subId);
      }
      final age = filter.ageGroup?.trim();
      if (age != null && age.isNotEmpty) {
        query = query.eq('age_group', age);
      }
      final tag = filter.tag?.trim();
      if (tag != null && tag.isNotEmpty) {
        query = query.contains('tags', [tag]);
      }
      if (filter.resolvedOnly == true) {
        query = query.eq('is_resolved', true);
      } else if (filter.resolvedOnly == false) {
        query = query.eq('is_resolved', false);
      }

      final qText = filter.query.trim();
      if (qText.isNotEmpty) {
        final escaped = qText.replaceAll('%', r'\%').replaceAll(',', ' ');
        query = query.or(
          'title.ilike.%$escaped%,content.ilike.%$escaped%,category.ilike.%$escaped%',
        );
      }

      if (filter.sort == ForumSortMode.unanswered) {
        query = query.eq('comments', 0);
      }

      // order() TransformBuilder döndürür — filtre değişkenine atama
      late final dynamic ordered;
      switch (filter.sort) {
        case ForumSortMode.popular:
          ordered = query
              .order('likes', ascending: false)
              .order('created_at', ascending: false);
        case ForumSortMode.mostReplied:
          ordered = query
              .order('comments', ascending: false)
              .order('created_at', ascending: false);
        case ForumSortMode.unanswered:
        case ForumSortMode.newest:
          ordered = query.order('created_at', ascending: false);
      }

      // hasMore için pageSize+1 çek
      final rows = await ordered.range(from, to);
      final list = (rows as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      final hasMore = list.length > pageSize;
      final pageRows = hasMore ? list.sublist(0, pageSize) : list;

      Set<int> liked = {};
      final user = _client.auth.currentUser;
      if (user != null && pageRows.isNotEmpty) {
        try {
          final ids = [
            for (final r in pageRows)
              if ((r['id'] as num?) != null) (r['id'] as num).toInt(),
          ];
          if (ids.isNotEmpty) {
            final likeRows = await _client
                .from('forum_likes')
                .select('post_id')
                .eq('owner_id', user.id)
                .inFilter('post_id', ids);
            liked = {
              for (final e in (likeRows as List).whereType<Map>())
                if ((e['post_id'] as num?) != null)
                  (e['post_id'] as num).toInt(),
            };
          }
        } catch (_) {}
      }

      final diseases = await fetchDiseases();
      final diseaseMap = {for (final d in diseases) d.id: d};
      List<ForumSubCategory> subs = const [];
      try {
        subs = await fetchSubCategories();
      } catch (_) {}
      final subMap = {for (final s in subs) s.id: s};

      final items = [
        for (final row in pageRows)
          _mapTopic(
            row,
            likedByMe: liked.contains((row['id'] as num?)?.toInt() ?? -1),
            diseaseMap: diseaseMap,
            subMap: subMap,
          ),
      ];

      return ForumTopicsPage(
        items: items,
        hasMore: hasMore,
        page: safePage,
      );
    } catch (e) {
      // Kolonlar yoksa eski şemaya düş
      debugPrint('[ForumRemote] fetchTopics fallback: $e');
      return _legacyFetch(filter: filter, page: safePage, pageSize: pageSize);
    }
  }

  Future<ForumTopicsPage> _legacyFetch({
    required ForumFilterParams filter,
    required int page,
    required int pageSize,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize;
    var query = _client.from('forum_posts').select();
    final qText = filter.query.trim();
    if (qText.isNotEmpty) {
      final escaped = qText.replaceAll('%', r'\%').replaceAll(',', ' ');
      query = query.or(
        'title.ilike.%$escaped%,content.ilike.%$escaped%,category.ilike.%$escaped%',
      );
    }
    final rows =
        await query.order('created_at', ascending: false).range(from, to);
    final list = (rows as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final hasMore = list.length > pageSize;
    final pageRows = hasMore ? list.sublist(0, pageSize) : list;
    return ForumTopicsPage(
      items: [
        for (final row in pageRows)
          _mapTopic(row, likedByMe: false, diseaseMap: const {}, subMap: const {}),
      ],
      hasMore: hasMore,
      page: page,
    );
  }

  Future<void> incrementViews(int topicId) async {
    if (topicId <= 0) return;
    try {
      await recordForumView(topicId);
    } catch (_) {}
  }

  ForumTopic _mapTopic(
    Map<String, dynamic> json, {
    required bool likedByMe,
    required Map<String, ForumDisease> diseaseMap,
    required Map<String, ForumSubCategory> subMap,
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
      for (final t in tagsRaw) {
        final s = t?.toString().trim() ?? '';
        if (s.isNotEmpty) tags.add(s);
      }
    }
    final diseaseId = json['disease_id']?.toString();
    final subId = json['sub_category_id']?.toString();
    final disease = diseaseId == null ? null : diseaseMap[diseaseId];
    final sub = subId == null ? null : subMap[subId];

    return ForumTopic(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Anonim',
      avatar: json['avatar']?.toString() ?? '?',
      avatarColor: Color(colorVal),
      category: json['category']?.toString() ?? 'Genel',
      createdAt: created,
      diseaseId: diseaseId,
      diseaseLabel: disease?.chipLabel,
      subCategoryId: subId,
      subCategoryLabel: sub?.label,
      ageGroup: json['age_group']?.toString() ?? '',
      tags: tags,
      views: (json['views'] as num?)?.toInt() ?? 0,
      replyCount: (json['comments'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      isResolved: json['is_resolved'] == true,
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

  static const _fallbackDiseases = <ForumDisease>[
    ForumDisease(id: 'otizm', label: 'Otizm Spektrum Bozukluğu', shortLabel: 'Otizm', sortOrder: 1),
    ForumDisease(id: 'serebral-palsi', label: 'Serebral Palsi', shortLabel: 'Serebral Palsi', sortOrder: 2),
    ForumDisease(id: 'down-sendromu', label: 'Down Sendromu', shortLabel: 'Down Sendromu', sortOrder: 3),
    ForumDisease(id: 'sma', label: 'SMA', shortLabel: 'SMA', sortOrder: 4),
    ForumDisease(id: 'dehb', label: 'DEHB', shortLabel: 'DEHB', sortOrder: 5),
    ForumDisease(id: 'gelisim-geriligi', label: 'Gelişim Geriliği', shortLabel: 'Gelişim Geriliği', sortOrder: 6),
    ForumDisease(id: 'duyu-butunleme', label: 'Duyu Bütünleme', shortLabel: 'Duyu Bütünleme', sortOrder: 7),
    ForumDisease(id: 'iletisim-bozukluklari', label: 'İletişim Bozuklukları', shortLabel: 'İletişim Bozuklukları', sortOrder: 8),
    ForumDisease(id: 'nadir-hastaliklar', label: 'Nadir Hastalıklar', shortLabel: 'Nadir Hastalıklar', sortOrder: 9),
  ];
}
