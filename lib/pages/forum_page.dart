import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../data/forum_data.dart';
import '../data/forum_tags.dart';
import '../data/ilanlar_data.dart' show maskPersonDisplayName;
import '../content_moderation.dart';
import '../forum_follow_store.dart';
import '../forum_post_follow_store.dart';
import '../forum_store.dart';
import '../content_view_store.dart';
import '../meto_theme.dart';
import '../services/catalog_adapters.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import '../sohbet_store.dart';
import '../widgets/photo_gallery_lightbox.dart';
import '../widgets/user_avatar.dart';
import '../widgets/user_safety_sheet.dart';
import '../user_safety_store.dart';
import '../widgets/guest_gate.dart';
import '../widgets/ugc_terms_gate.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../services/broadcast_push_service.dart';

enum _ForumSort {
  newest,
  oldest,
  mostComments,
  leastComments,
}

extension on _ForumSort {
  String get label => switch (this) {
        _ForumSort.newest => 'En yeni',
        _ForumSort.oldest => 'En eski',
        _ForumSort.mostComments => 'En çok yorum',
        _ForumSort.leastComments => 'En az yorum',
      };
}

/// Figma Make `ForumTab` — Flutter portu.
class ForumPage extends StatefulWidget {
  const ForumPage({
    super.key,
    this.userName = 'Siz',
    this.userEmail = '',
    this.userType = 'aile',
    this.profilFoto,
    this.isGuest = false,
    this.onRequireLogin,
    this.openPostId,
    this.openCommentId,
    this.openPostToken = 0,
  });

  final String userName;
  final String userEmail;
  final String userType;
  /// data:image… profil fotoğrafı (varsa paylaşımlarda kullanılır).
  final String? profilFoto;
  final bool isGuest;
  final VoidCallback? onRequireLogin;
  /// Bildirimden açılacak gönderi / yorum.
  final int? openPostId;
  final int? openCommentId;
  final int openPostToken;

  @override
  State<ForumPage> createState() => ForumPageState();
}

class ForumPageState extends State<ForumPage> {
  /// Sistem geri: açık detayı kapatır. true = işlendi.
  bool consumeBack() {
    if (_selectedPost != null) {
      setState(() => _selectedPost = null);
      return true;
    }
    return false;
  }
  static const _pageSize = 10;

  ForumPost? _selectedPost;
  bool _newPost = false;
  ForumPost? _editingPost;
  String _searchQuery = '';
  String _activeCategory = 'Tümü';
  String? _filterTag;
  _ForumSort _sort = _ForumSort.newest;
  int _listPage = 0;
  bool _anon = false;
  String _newPostCategory = 'Genel Konular';
  String _uzmanMeslek = uzmanMeslekler.first;
  bool _koseYazisi = false;
  bool _loading = true;
  bool _publishing = false;
  bool _commentSending = false;
  bool _commentAnon = false;
  bool _likeBusy = false;
  bool _commentLikeBusy = false;
  Set<String> _followedCats = {};
  bool _followBusy = false;
  bool _followingPost = false;
  bool _postFollowBusy = false;
  bool _pickingPhoto = false;
  final List<String> _formPhotos = [];
  final List<String> _formTags = [];
  final _tagInputController = TextEditingController();
  List<ForumPost> _cloudPosts = const [];
  List<ForumComment> _postComments = const [];
  bool _commentsLoading = false;
  ForumComment? _replyingTo;
  RealtimeChannel? _forumChannel;

  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _commentController = TextEditingController();

  bool get _isProfUser =>
      widget.userType == 'uzman' || widget.userType == 'bakici';

  List<String> get _feedCategories => CatalogAdapters.forumFeedCategories();
  List<String> get _postCategories => CatalogAdapters.forumPostCategories();

  String get _composeCategoryKey {
    if (_newPostCategory == 'Uzman' || _koseYazisi) return 'Köşe Yazısı';
    return _newPostCategory;
  }

  List<String> get _suggestedFormTags =>
      suggestedTagsForCategory(_composeCategoryKey);

  /// Aktif kategoriye ait öneriler + o kategorideki paylaşılmış etiketler.
  List<String> get _filterTagOptions {
    final suggested = _activeCategory == 'Tümü'
        ? <String>[]
        : suggestedTagsForCategory(_activeCategory);
    final fromPosts = <String>{};
    for (final p in _cloudPosts) {
      final matchesCat = switch (_activeCategory) {
        'Tümü' => true,
        'Köşe Yazısı' => p.expert || p.category == 'Köşe Yazısı',
        'Doktor' =>
          p.expert &&
              (p.meslek == 'Doktor' ||
                  p.category.toLowerCase().contains('doktor')),
        'Genel Konular' =>
          p.category == 'Genel Konular' || p.category == 'Genel',
        'Uzman' =>
          p.expert || p.category == 'Uzman' || isUzmanMeslek(p.category),
        _ => p.category == _activeCategory || p.meslek == _activeCategory,
      };
      if (!matchesCat) continue;
      fromPosts.addAll(normalizeForumTags(p.tags));
    }
    return normalizeForumTags([...suggested, ...fromPosts]);
  }

  void _toggleFormTag(String raw) {
    final tag = normalizeForumTag(raw);
    if (tag.isEmpty) return;
    setState(() {
      final i = _formTags.indexWhere((t) => t.toLowerCase() == tag.toLowerCase());
      if (i >= 0) {
        _formTags.removeAt(i);
      } else {
        _formTags.add(tag);
      }
    });
  }

  void _addCustomFormTag() {
    final tag = normalizeForumTag(_tagInputController.text);
    if (tag.isEmpty) return;
    setState(() {
      if (!_formTags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
        _formTags.add(tag);
      }
      _tagInputController.clear();
    });
  }

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  bool _canModeratePost(ForumPost post) =>
      _isAdmin ||
      (post.ownerEmail.isNotEmpty &&
          post.ownerEmail == widget.userEmail.trim().toLowerCase());

  bool _isPostOwner(ForumPost post) =>
      post.ownerEmail.isNotEmpty &&
      post.ownerEmail == widget.userEmail.trim().toLowerCase();

  bool _canModerateComment(ForumComment c) =>
      _isAdmin ||
      (c.ownerEmail.isNotEmpty &&
          c.ownerEmail == widget.userEmail.trim().toLowerCase());

  bool get _isGuest => widget.isGuest;

  /// Misafir: ad açık, soyad ****.
  String _displayName(String name) {
    final n = name.trim();
    if (n.isEmpty || n.toLowerCase() == 'anonim') return n;
    if (!_isGuest) return n;
    return maskPersonDisplayName(n);
  }

  Future<bool> _requireMember([String? msg]) async {
    return ensureMemberAccess(
      context,
      isGuest: _isGuest,
      onRequireLogin: widget.onRequireLogin ?? () {},
      message: msg ??
          'Forum etkileşimi için giriş yapmanız veya üye olmanız gerekiyor.',
    );
  }

  void _startEditPost(ForumPost post) {
    _titleController.text = post.title;
    _contentController.text = post.content;
    setState(() {
      _editingPost = post;
      _selectedPost = null;
      _newPost = true;
      _formPhotos
        ..clear()
        ..addAll(post.photos.take(2));
      _formTags
        ..clear()
        ..addAll(normalizeForumTags(post.tags));
      _anon = false;
      if (post.expert) {
        _newPostCategory = 'Uzman';
        _koseYazisi = true;
        if (post.meslek.isNotEmpty && uzmanMeslekler.contains(post.meslek)) {
          _uzmanMeslek = post.meslek;
        }
      } else {
        _koseYazisi = false;
        _newPostCategory = _postCategories.contains(post.category)
            ? post.category
            : _postCategories.first;
      }
    });
  }

  void _closePostForm() {
    _titleController.clear();
    _contentController.clear();
    _tagInputController.clear();
    setState(() {
      _newPost = false;
      _editingPost = null;
      _formPhotos.clear();
      _formTags.clear();
      _anon = false;
      _koseYazisi = _isProfUser;
      if (_isProfUser) {
        _newPostCategory = 'Uzman';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (_isProfUser) {
      _newPostCategory = 'Uzman';
      _koseYazisi = true;
      _uzmanMeslek = 'Doktor';
    } else {
      // Aileler köşe yazısında "Aile" olarak paylaşır
      _uzmanMeslek = 'Aile';
    }
    _loadPosts().then((_) {
      if (mounted) unawaited(_tryOpenPostFromShell());
    });
    unawaited(_loadFollows());
    _forumChannel = Supabase.instance.client.channel('forum-feed');
    _forumChannel!
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_posts',
        callback: (_) {
          if (mounted) unawaited(_loadPosts());
        },
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'forum_comments',
        callback: (_) {
          if (!mounted) return;
          // Gönderim sırasında lokal ekleme + realtime çift liste yapmasın
          if (_commentSending) return;
          if (_selectedPost != null) {
            unawaited(_openPost(_selectedPost!));
          } else {
            unawaited(_loadPosts());
          }
        },
      )
      ..subscribe();
  }

  @override
  void dispose() {
    unawaited(unsubscribeRealtime(_forumChannel));
    _forumChannel = null;
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _commentController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    unawaited(loadBlockedEmails());
    final posts = await loadForumPosts();
    final photos = await loadUserPhotosByEmail(
      posts.where((p) => !p.isAnonymous).map((p) => p.ownerEmail),
    );
    final enriched = [
      for (final p in posts)
        p.copyWith(
          avatar: resolveAvatar(
            storedAvatar: p.avatar,
            ownerEmail: p.ownerEmail,
            photosByEmail: photos,
            ownPhoto: widget.profilFoto,
            ownEmail: widget.userEmail,
            anonymous: p.isAnonymous,
          ),
        ),
    ];
    if (!mounted) return;
    setState(() {
      _cloudPosts = enriched;
      _loading = false;
      if (_selectedPost != null) {
        final updated =
            enriched.where((p) => p.id == _selectedPost!.id).firstOrNull;
        if (updated != null) _selectedPost = updated;
      }
    });
  }

  Future<List<ForumComment>> _enrichComments(List<ForumComment> comments) async {
    final photos = await loadUserPhotosByEmail(
      comments
          .where((c) => c.name.trim().toLowerCase() != 'anonim')
          .map((c) => c.ownerEmail),
    );
    return [
      for (final c in comments)
        ForumComment(
          id: c.id,
          name: c.name,
          text: c.text,
          time: c.time,
          color: c.color,
          avatar: resolveAvatar(
            storedAvatar: c.avatar,
            ownerEmail: c.ownerEmail,
            photosByEmail: photos,
            ownPhoto: widget.profilFoto,
            ownEmail: widget.userEmail,
            anonymous: c.name.trim().toLowerCase() == 'anonim',
          ),
          ownerEmail: c.ownerEmail,
          parentId: c.parentId,
          likes: c.likes,
          likedByMe: c.likedByMe,
        ),
    ];
  }

  Future<void> _loadFollows() async {
    if (widget.userEmail.trim().isEmpty) return;
    final set = await ForumFollowStore.loadFollowed(widget.userEmail);
    if (!mounted) return;
    setState(() => _followedCats = set);
  }

  Future<void> _toggleFollowActiveCategory() async {
    final cat = _activeCategory;
    if (cat == 'Tümü' || _followBusy) return;
    if (!await _requireMember(
        'Konu takibi için giriş yapmanız veya üye olmanız gerekiyor.')) {
      return;
    }
    if (widget.userEmail.trim().isEmpty) return;
    setState(() => _followBusy = true);
    final next = !_followedCats.contains(cat);
    await ForumFollowStore.setFollowing(
      widget.userEmail,
      cat,
      follow: next,
    );
    if (!mounted) return;
    setState(() {
      if (next) {
        _followedCats = {..._followedCats, cat};
      } else {
        _followedCats = {..._followedCats}..remove(cat);
      }
      _followBusy = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          next
              ? '"$cat" konusundan bildirim alacaksın'
              : '"$cat" bildirimleri kapatıldı',
        ),
      ),
    );
  }

  List<ForumPost> get _filteredPosts {
    final q = _searchQuery.trim().toLowerCase();
    // Yalnızca buluttaki gerçek gönderiler (örnek/bot yok)
    final list = _cloudPosts.where((p) {
      final owner = p.ownerEmail.trim().toLowerCase();
      if (owner.isNotEmpty && isBlockedEmail(owner)) return false;
      final matchesCat = switch (_activeCategory) {
        'Tümü' => true,
        'Köşe Yazısı' =>
          p.expert || p.category == 'Köşe Yazısı',
        'Doktor' =>
          p.expert &&
              (p.meslek == 'Doktor' ||
                  p.category.toLowerCase().contains('doktor')),
        'Genel Konular' =>
          p.category == 'Genel Konular' || p.category == 'Genel',
        'Uzman' =>
          p.expert || p.category == 'Uzman' || isUzmanMeslek(p.category),
        _ => p.category == _activeCategory || p.meslek == _activeCategory,
      };
      final matchesQ = q.isEmpty ||
          [p.title, p.content, p.author, p.category, p.meslek, ...p.tags]
              .any((f) => f.toLowerCase().contains(q));
      final ft = (_filterTag ?? '').trim().toLowerCase();
      final matchesTag = ft.isEmpty ||
          p.tags.any((t) => t.toLowerCase() == ft || t.toLowerCase() == '#$ft');
      return matchesCat && matchesQ && matchesTag;
    }).toList();

    int cmpDate(ForumPost a, ForumPost b, {required bool ascending}) {
      final da = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(a.id);
      final db = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(b.id);
      final c = da.compareTo(db);
      return ascending ? c : -c;
    }

    list.sort((a, b) {
      // Sabitlenmişler üstte kalsın
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      switch (_sort) {
        case _ForumSort.newest:
          return cmpDate(a, b, ascending: false);
        case _ForumSort.oldest:
          return cmpDate(a, b, ascending: true);
        case _ForumSort.mostComments:
          final c = b.comments.compareTo(a.comments);
          return c != 0 ? c : cmpDate(a, b, ascending: false);
        case _ForumSort.leastComments:
          final c = a.comments.compareTo(b.comments);
          return c != 0 ? c : cmpDate(a, b, ascending: false);
      }
    });
    return list;
  }

  @override
  void didUpdateWidget(covariant ForumPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openPostToken != oldWidget.openPostToken) {
      unawaited(_tryOpenPostFromShell());
    }
  }

  Future<void> _tryOpenPostFromShell() async {
    final id = widget.openPostId;
    if (id == null || id <= 0) return;
    ForumPost? found;
    for (final p in _cloudPosts) {
      if (p.id == id) {
        found = p;
        break;
      }
    }
    if (found == null) {
      // Liste henüz boşsa / eski — yenile
      await _loadPosts();
      if (!mounted) return;
      for (final p in _cloudPosts) {
        if (p.id == id) {
          found = p;
          break;
        }
      }
    }
    if (found == null || !mounted) return;
    await _openPost(found);
    final commentId = widget.openCommentId;
    if (commentId != null && commentId > 0 && mounted) {
      // Yanıt hedefi olarak işaretle (kullanıcı görsün)
      ForumComment? target;
      for (final c in _postComments) {
        if (c.id == commentId) {
          target = c;
          break;
        }
      }
      if (target != null) {
        setState(() => _replyingTo = target);
      }
    }
  }

  Future<void> _togglePostFollow(ForumPost post) async {
    if (!await _requireMember(
        'Gönderi bildirimi için giriş yapmanız veya üye olmanız gerekiyor.')) {
      return;
    }
    if (_postFollowBusy || post.id <= 0) return;
    final next = !_followingPost;
    setState(() {
      _postFollowBusy = true;
      _followingPost = next;
    });
    try {
      await ForumPostFollowStore.setFollowing(
        email: widget.userEmail,
        postId: post.id,
        follow: next,
      );
      if (!mounted) return;
      setState(() => _postFollowBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'Bu gönderi hakkında bildirim alacaksınız'
                : 'Gönderi bildirimleri kapatıldı',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _followingPost = !next;
        _postFollowBusy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('forum_post_follows') ||
                    e.toString().contains('42P01')
                ? 'Takip için forum_post_follows.sql çalıştırın.'
                : 'Kaydedilemedi: $e',
          ),
        ),
      );
    }
  }

  Future<void> _openPost(ForumPost post) async {
    setState(() {
      _selectedPost = post;
      _commentsLoading = true;
      _followingPost = false;
      // Gönderim sonrası yenilemede listeyi boşaltma — çift flaş / kayıp önle
      if (!_commentSending) {
        _postComments = const [];
        _replyingTo = null;
      }
    });
    unawaited(() async {
      final n = await recordForumView(post.id);
      if (!mounted || n < 0 || _selectedPost?.id != post.id) return;
      setState(() {
        _selectedPost = _selectedPost!.copyWith(views: n);
        _cloudPosts = [
          for (final p in _cloudPosts)
            if (p.id == post.id) p.copyWith(views: n) else p,
        ];
      });
    }());
    if (!_isGuest && widget.userEmail.trim().isNotEmpty && post.id > 0) {
      unawaited(() async {
        final on = await ForumPostFollowStore.isFollowing(
          email: widget.userEmail,
          postId: post.id,
        );
        if (mounted && _selectedPost?.id == post.id) {
          setState(() => _followingPost = on);
        }
      }());
    }
    final comments = await loadForumComments(post.id);
    final enriched = await _enrichComments(comments);
    if (!mounted) return;
    // Aynı id'yi tek tut
    final deduped = <ForumComment>[];
    final seen = <int>{};
    for (final c in enriched) {
      if (c.id > 0 && !seen.add(c.id)) continue;
      deduped.add(c);
    }
    setState(() {
      _postComments = deduped;
      _commentsLoading = false;
    });
  }

  List<ForumComment> get _rootComments =>
      _postComments.where((c) => !c.isReply).toList();

  List<ForumComment> _repliesOf(int parentId) =>
      _postComments.where((c) => c.parentId == parentId).toList();

  void _startReply(ForumComment c) {
    if (_isGuest) {
      unawaited(_requireMember('Yanıt yazmak için üye olmanız gerekiyor.'));
      return;
    }
    setState(() => _replyingTo = c);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _toggleCommentLike(ForumComment c) async {
    if (!await _requireMember('Yorum beğenmek için üye olmanız gerekiyor.')) {
      return;
    }
    if (_commentLikeBusy || c.id <= 0) return;
    setState(() => _commentLikeBusy = true);
    try {
      final result = await toggleForumCommentLike(c.id);
      if (!mounted) return;
      setState(() {
        _postComments = [
          for (final x in _postComments)
            if (x.id == c.id)
              x.copyWith(likedByMe: result.liked, likes: result.likes)
            else
              x,
        ];
        _commentLikeBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _commentLikeBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('forum_comment_likes') ||
                    e.toString().contains('PGRST') ||
                    e.toString().contains('42P01')
                ? 'Yorum beğenisi için forum_comment_replies_likes.sql çalıştırın.'
                : 'Beğenilemedi: $e',
          ),
        ),
      );
    }
  }

  Future<void> _toggleLike(ForumPost post) async {
    if (!await _requireMember('Beğenmek için üye olmanız gerekiyor.')) {
      return;
    }
    if (_likeBusy) return;
    setState(() => _likeBusy = true);
    try {
      final result = await toggleForumLike(post.id);
      if (!mounted) return;
      final updated = post.copyWith(likedByMe: result.liked, likes: result.likes);
      setState(() {
        _cloudPosts = [
          for (final p in _cloudPosts)
            if (p.id == post.id) updated else p,
        ];
        if (_selectedPost?.id == post.id) _selectedPost = updated;
        _likeBusy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _likeBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('forum_likes') ||
                    e.toString().contains('PGRST')
                ? 'Beğeni tablosu yok. forum_interact.sql çalıştırın.'
                : 'Beğenilemedi: $e',
          ),
        ),
      );
    }
  }

  Future<void> _deletePost(ForumPost post) async {
    if (!_canModeratePost(post)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Bu gönderi silinemez')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isAdmin ? 'Gönderiyi sil (Admin)' : 'Gönderiyi sil'),
        content: L10nText('"${post.title}" kalıcı silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const L10nText('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await deleteForumPost(post.id);
      if (!mounted) return;
      setState(() {
        _cloudPosts = _cloudPosts.where((p) => p.id != post.id).toList();
        if (_selectedPost?.id == post.id) {
          _selectedPost = null;
          _postComments = const [];
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Gönderi silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e is StateError ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raw.contains('admin_moderation') ||
                    raw.contains('policy') ||
                    raw.contains('42501')
                ? raw
                : 'Silinemedi: $raw',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _deleteComment(ForumComment c) async {
    final post = _selectedPost;
    if (post == null || !_canModerateComment(c) || c.id <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isAdmin ? 'Yorumu sil (Admin)' : 'Yorumu sil'),
        content: const L10nText('Bu yorum kalıcı silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const L10nText('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await deleteForumComment(commentId: c.id, postId: post.id);
      if (!mounted) return;
      final removeIds = <int>{
        c.id,
        ..._postComments
            .where((x) => x.parentId == c.id)
            .map((x) => x.id),
      };
      final updated = post.copyWith(
        comments: (post.comments - removeIds.length).clamp(0, 999999),
      );
      setState(() {
        _postComments =
            _postComments.where((x) => !removeIds.contains(x.id)).toList();
        if (_replyingTo != null && removeIds.contains(_replyingTo!.id)) {
          _replyingTo = null;
        }
        _selectedPost = updated;
        _cloudPosts = [
          for (final p in _cloudPosts)
            if (p.id == post.id) updated else p,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Yorum silindi')),
      );
    } catch (e) {
      if (!mounted) return;
      final raw = e is StateError ? e.message : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raw.contains('admin_moderation') ||
                    raw.contains('policy') ||
                    raw.contains('42501')
                ? raw
                : 'Silinemedi: $raw',
          ),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _sendComment() async {
    if (!await _requireMember('Yorum yazmak için üye olmanız gerekiyor.')) {
      return;
    }
    final post = _selectedPost;
    final text = _commentController.text.trim();
    // Senkron kilit: setState gelmeden ikinci çağrı (Enter+buton) girmesin
    if (post == null || text.isEmpty || _commentSending) return;
    _commentSending = true;

    final parent = _replyingTo;
    final parentId = parent == null
        ? null
        : (parent.isReply ? parent.parentId : parent.id);

    _commentController.clear();
    if (mounted) {
      setState(() {});
      FocusScope.of(context).unfocus();
    }

    try {
      final c = await addForumComment(
        postId: post.id,
        body: text,
        authorName: widget.userName,
        authorEmail: widget.userEmail,
        parentId: parentId,
        anon: _commentAnon,
        avatarPhoto: _commentAnon ? null : widget.profilFoto,
      );
      if (!mounted) return;
      final following = await ForumPostFollowStore.isFollowing(
        email: widget.userEmail,
        postId: post.id,
      );
      if (!mounted) return;
      final updated = post.copyWith(comments: post.comments + 1);
      setState(() {
        final already = _postComments.any((x) => x.id == c.id && c.id > 0);
        if (!already) {
          final sameText = _postComments.any((x) =>
              x.text.trim() == c.text.trim() &&
              x.ownerEmail == c.ownerEmail &&
              x.parentId == c.parentId &&
              x.id != c.id);
          if (!sameText) {
            _postComments = [..._postComments, c];
          }
        }
        _selectedPost = updated;
        _replyingTo = null;
        _commentAnon = false;
        _followingPost = following;
        _cloudPosts = [
          for (final p in _cloudPosts)
            if (p.id == post.id) updated else p,
        ];
      });
      // Hâlâ kilitliyken yenile (realtime çakışmasın), sonra kilidi aç
      await _reloadCommentsOnly(updated);
      if (!mounted) return;
      setState(() => _commentSending = false);
    } catch (e) {
      if (!mounted) return;
      _commentController.text = text;
      setState(() => _commentSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('forum_comments') ||
                    e.toString().contains('PGRST')
                ? 'Yorum tablosu yok. forum_interact.sql çalıştırın.'
                : 'Yorum gönderilemedi: $e',
          ),
        ),
      );
    }
  }

  /// Gönderim sonrası yorumları yenile; yanıt durumunu bozma.
  Future<void> _reloadCommentsOnly(ForumPost post) async {
    final comments = await loadForumComments(post.id);
    final enriched = await _enrichComments(comments);
    if (!mounted) return;
    final deduped = <ForumComment>[];
    final seen = <int>{};
    for (final c in enriched) {
      if (c.id > 0 && !seen.add(c.id)) continue;
      deduped.add(c);
    }
    setState(() {
      _selectedPost = post;
      _postComments = deduped;
      _commentsLoading = false;
    });
  }

  Future<void> _pickForumPhoto() async {
    if (_formPhotos.length >= 2 || _pickingPhoto) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MetoColors.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: L10nText(
                  'Fotoğraf ekle',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: MetoColors.primary),
                title: const L10nText('Galeriden seç'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: MetoColors.primary),
                title: const L10nText('Kamerayla çek'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const L10nText('Vazgeç'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;

    setState(() => _pickingPhoto = true);
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      final raw = await file.readAsBytes();
      if (raw.isEmpty) {
        throw StateError('Boş görsel seçildi.');
      }
      final optimized = await ImageOptimizeService.forForum(raw);
      final url = await R2StorageService.uploadBytes(
        bytes: optimized.bytes,
        fileName: optimized.fileName,
        contentType: optimized.contentType,
      );
      if (!mounted) return;
      setState(() => _formPhotos.add(url));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final friendly = msg.contains('büyük') ||
              msg.contains('boş') ||
              msg.contains('okunamadı') ||
              msg.contains('sıkıştır')
          ? e.toString().replaceFirst('Bad state: ', '')
          : (msg.contains('quota') ||
                  msg.contains('ön bellek') ||
                  msg.contains('localstorage') ||
                  msg.contains('exceeded'))
              ? 'Tarayıcı önbelleği dolu. Daha küçük fotoğraf deneyin.'
              : 'Fotoğraf eklenemedi. Galeri/kamera iznini kontrol edin.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendly)),
      );
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _publishPost() async {
    if (!await _requireMember('Gönderi paylaşmak için üye olmanız gerekiyor.')) {
      return;
    }
    if (!mounted) return;
    if (!await ensureUgcTermsAccepted(context)) return;
    if (!mounted) return;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    final eksik = <String>[];
    if (title.isEmpty) eksik.add('Başlık');
    if (content.isEmpty) eksik.add('İçerik');
    if (eksik.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Lütfen doldurun: ${eksik.join(', ')}')),
      );
      return;
    }
    if (containsBlockedContent('$title\n$content')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText(blockedContentMessage())),
      );
      return;
    }
    if (_publishing) return;
    setState(() => _publishing = true);

    final isExpert = _newPostCategory == 'Uzman' || _koseYazisi;
    final category = isExpert ? 'Uzman' : _newPostCategory;
    final meslek = isExpert ? _uzmanMeslek : '';
    final tags = normalizeForumTags([
      ..._formTags,
      ...extractHashTagsFromText('$title\n$content'),
    ]);

    try {
      final isEdit = _editingPost != null;
      final ForumPost post;
      if (isEdit) {
        post = await updateForumPost(
          postId: _editingPost!.id,
          title: title,
          content: content,
          category: category,
          expert: isExpert,
          meslek: meslek,
          photos: _formPhotos,
          tags: tags,
        );
      } else {
        post = await publishForumPost(
          title: title,
          content: content,
          category: category,
          authorName: widget.userName,
          authorEmail: widget.userEmail,
          anon: isExpert ? false : _anon,
          expert: isExpert,
          meslek: meslek,
          photos: _formPhotos,
          tags: tags,
          avatarPhoto: (isExpert || !_anon) ? widget.profilFoto : null,
        );
        unawaited(ForumFollowStore.notifyFollowersOfPost(
          category: isExpert ? 'Köşe Yazısı' : category,
          title: title,
          actorName: widget.userName,
          actorEmail: widget.userEmail,
        ));
        unawaited(
          BroadcastPushService.instance.forumPost(
            title: title,
            postId: '${post.id}',
          ),
        );
        if (isExpert && meslek.isNotEmpty) {
          unawaited(ForumFollowStore.notifyFollowersOfPost(
            category: meslek,
            title: title,
            actorName: widget.userName,
            actorEmail: widget.userEmail,
          ));
        }
      }
      if (!mounted) return;
      _titleController.clear();
      _contentController.clear();
      _tagInputController.clear();
      setState(() {
        if (isEdit) {
          _cloudPosts = [
            for (final p in _cloudPosts) p.id == post.id ? post : p,
          ];
        } else {
          _cloudPosts = [post, ..._cloudPosts];
        }
        _formPhotos.clear();
        _formTags.clear();
        _newPost = false;
        _editingPost = null;
        _anon = false;
        _koseYazisi = _isProfUser;
        _activeCategory = isExpert ? 'Köşe Yazısı' : 'Tümü';
        _filterTag = null;
        _publishing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Gönderi güncellendi ✅'
                : isExpert
                    ? 'Köşe yazınız paylaşıldı — herkes görebilir ✅'
                    : 'Gönderiniz paylaşıldı — herkes görebilir ✅',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('forum_posts') ||
                    e.toString().contains('schema cache') ||
                    e.toString().contains('PGRST')
                ? 'Forum tablosu yok. Supabase’de forum_posts.sql çalıştırın.'
                : (_editingPost != null
                    ? 'Güncellenemedi: $e'
                    : 'Paylaşılamadı: $e'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_newPost) return _buildNewPost();
    if (_selectedPost != null) return _buildPostDetail(_selectedPost!);
    return _buildList();
  }

  Widget _buildList() {
    final filtered = _filteredPosts;

    return ColoredBox(
      color: MetoColors.background,
      child: RefreshIndicator(
        color: MetoColors.primary,
        onRefresh: _loadPosts,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        L10nText(
                          'Topluluk',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                        SizedBox(height: 2),
                        L10nText(
                          'Aileler birbirini destekliyor',
                          style: TextStyle(
                            fontSize: 14,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (!await _requireMember(
                          'Gönderi paylaşmak için üye olmanız gerekiyor.')) {
                        return;
                      }
                      if (!mounted) return;
                      setState(() => _newPost = true);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: MetoColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const L10nText(
                      '+ Paylaş',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: MetoColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MetoColors.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 15, color: MetoColors.mutedFg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(
                          fontSize: 14,
                          color: MetoColors.foreground,
                        ),
                        decoration: InputDecoration(
                          hintText: S.auto('Konu veya #etiket ara...'),
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: MetoColors.mutedFg,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        color: MetoColors.mutedFg,
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 18, color: MetoColors.mutedFg),
                  const SizedBox(width: 8),
                  const L10nText(
                    'Sırala',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: MetoColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MetoColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<_ForumSort>(
                          value: _sort,
                          isExpanded: true,
                          borderRadius: BorderRadius.circular(12),
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: MetoColors.primary),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: MetoColors.foreground,
                          ),
                          items: [
                            for (final s in _ForumSort.values)
                              DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() {
                              _sort = v;
                              _listPage = 0;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _feedCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _feedCategories[i];
                  final active = cat == _activeCategory;
                  return GestureDetector(
                    onTap: () => setState(() {
                      _activeCategory = cat;
                      _filterTag = null;
                      _listPage = 0;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active ? MetoColors.primary : MetoColors.muted,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : MetoColors.mutedFg,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (_filterTagOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const L10nText(
                          'Etiketler',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                        if (_filterTag != null) ...[
                          const Spacer(),
                          TextButton(
                            onPressed: () => setState(() {
                              _filterTag = null;
                              _listPage = 0;
                            }),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: MetoColors.primary,
                            ),
                            child: const L10nText('Filtreyi temizle',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filterTagOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final tag = _filterTagOptions[i];
                          final active = (_filterTag ?? '').toLowerCase() ==
                              tag.toLowerCase();
                          return GestureDetector(
                            onTap: () => setState(() {
                              _filterTag = active ? null : tag;
                              _listPage = 0;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? const Color(0xFFECFDF5)
                                    : MetoColors.card,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: active
                                      ? MetoColors.primary
                                      : MetoColors.border,
                                  width: active ? 1.5 : 1,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? MetoColors.primary
                                      : MetoColors.mutedFg,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            if (_activeCategory != 'Tümü')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: _followBusy ? null : _toggleFollowActiveCategory,
                  icon: Icon(
                    _followedCats.contains(_activeCategory)
                        ? Icons.notifications_active
                        : Icons.notifications_none,
                    size: 18,
                  ),
                  label: Text(
                    _followedCats.contains(_activeCategory)
                        ? 'Bu konudan bildirim alınıyor'
                        : 'Bu konudan bildirim al',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MetoColors.primary,
                    side: const BorderSide(color: MetoColors.border),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_loading && filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(
                  child: CircularProgressIndicator(color: MetoColors.primary),
                ),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: _buildEmptyState(),
              )
            else ...[
              ..._pageSlice(filtered).map(
                (post) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _PostCard(
                    post: post,
                    authorLabel:
                        post.isAnonymous ? 'Anonim' : _displayName(post.author),
                    onTap: () => _openPost(post),
                    onLike: () => _toggleLike(post),
                    onEdit:
                        _isPostOwner(post) ? () => _startEditPost(post) : null,
                    onDelete:
                        _canModeratePost(post) ? () => _deletePost(post) : null,
                    onReport: !_isPostOwner(post)
                        ? () async {
                            if (!await _requireMember(
                              'Şikayet için giriş yapmanız veya üye olmanız gerekiyor.',
                            )) {
                              return;
                            }
                            if (!mounted) return;
                            showUserSafetySheet(
                              context,
                              targetEmail: post.ownerEmail,
                              targetDisplayName: post.author,
                              contextLabel: 'forum_post',
                              contentType: 'forum_post',
                              contentId: '${post.id}',
                            );
                          }
                        : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: _buildForumPager(filtered.length),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  List<ForumPost> _pageSlice(List<ForumPost> items) {
    if (items.isEmpty) return const [];
    final pageCount = (items.length / _pageSize).ceil().clamp(1, 9999);
    final page = _listPage.clamp(0, pageCount - 1);
    final start = page * _pageSize;
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  Widget _buildForumPager(int total) {
    if (total <= _pageSize) {
      return L10nText(
        '$total gönderi',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: MetoColors.mutedFg),
      );
    }
    final pageCount = (total / _pageSize).ceil();
    final page = _listPage.clamp(0, pageCount - 1);
    return Column(
      children: [
        L10nText(
          'Sayfa ${page + 1} / $pageCount · $total gönderi',
          style: const TextStyle(fontSize: 11, color: MetoColors.mutedFg),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < pageCount; i++)
              Material(
                color: i == page ? MetoColors.primary : MetoColors.muted,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => setState(() => _listPage = i),
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: L10nText(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color:
                              i == page ? Colors.white : MetoColors.mutedFg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: MetoColors.muted,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search, size: 24, color: MetoColors.mutedFg),
            ),
            const SizedBox(height: 16),
            const L10nText(
              'Sonuç bulunamadı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MetoColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            L10nText(
              '"$_searchQuery" için eşleşen konu yok.\nFarklı bir kelime deneyin.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: MetoColors.mutedFg,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostDetail(ForumPost post) {
    final categoryLabel = post.expert && post.meslek.isNotEmpty
        ? '${post.meslek} · Köşe Yazısı'
        : post.category;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return ColoredBox(
      color: MetoColors.background,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              children: [
          TextButton.icon(
            onPressed: () => setState(() {
              _selectedPost = null;
              _postComments = const [];
              _replyingTo = null;
              _commentAnon = false;
            }),
            style: TextButton.styleFrom(
              foregroundColor: MetoColors.primary,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.chevron_left, size: 16),
            label: const L10nText(
              'Geri',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              UserAvatar(
                avatar: post.isAnonymous ? 'A' : post.avatar,
                color: post.isAnonymous
                    ? const Color(0xFF94A3B8)
                    : post.avatarColor,
                radius: 20,
                fallbackName: _displayName(post.author),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _displayName(post.author),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: MetoColors.foreground,
                            ),
                          ),
                        ),
                        if (post.expert) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: MetoColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              post.meslek.isNotEmpty ? post.meslek : 'Uzman',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      post.time,
                      style: const TextStyle(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
              _ForumReadBadge(count: post.views),
              PopupMenuButton<String>(
                tooltip: S.auto('Seçenekler'),
                onSelected: (v) async {
                  if (v == 'follow') unawaited(_togglePostFollow(post));
                  if (v == 'report') {
                    if (!await _requireMember(
                      'Şikayet için giriş yapmanız veya üye olmanız gerekiyor.',
                    )) {
                      return;
                    }
                    if (!mounted) return;
                    showUserSafetySheet(
                      context,
                      targetEmail: post.ownerEmail,
                      targetDisplayName: post.author,
                      contextLabel: 'forum_post',
                      contentType: 'forum_post',
                      contentId: '${post.id}',
                      onBlocked: () {
                        setState(() {
                          _selectedPost = null;
                          _cloudPosts = [
                            for (final p in _cloudPosts)
                              if (p.ownerEmail.trim().toLowerCase() !=
                                  post.ownerEmail.trim().toLowerCase())
                                p,
                          ];
                        });
                      },
                    );
                  }
                },
                itemBuilder: (ctx) => [
                  if (!_isPostOwner(post))
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 20, color: Color(0xFFEF4444)),
                          SizedBox(width: 10),
                          Expanded(child: Text('Şikayet et / Engelle', style: TextStyle(fontSize: 13))),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'follow',
                    enabled: !_postFollowBusy,
                    child: Row(
                      children: [
                        Icon(
                          _followingPost
                              ? Icons.notifications_active
                              : Icons.notifications_none,
                          size: 20,
                          color: MetoColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _followingPost
                                ? 'Gönderi bildirimlerini kapat'
                                : 'Gönderi hakkında bildirim al',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                icon: const Icon(Icons.more_vert, color: MetoColors.mutedFg),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: forumCategoryColor(
                  post.meslek.isNotEmpty ? post.meslek : post.category,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                categoryLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (post.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in post.tags)
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedPost = null;
                      _filterTag = tag;
                      _listPage = 0;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          L10nText(
            post.title,
            style: TextStyle(
              fontSize: post.expert ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          L10nText(
            post.content,
            style: TextStyle(
              fontSize: 15,
              color: MetoColors.foreground.withValues(alpha: 0.85),
              height: post.expert ? 1.7 : 1.5,
            ),
          ),
          if (post.photos.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ForumPhotoStrip(photos: post.photos, height: 280),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              InkWell(
                onTap: _likeBusy ? null : () => _toggleLike(post),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        post.likedByMe
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        size: 18,
                        color: post.likedByMe
                            ? MetoColors.primary
                            : MetoColors.mutedFg,
                      ),
                      const SizedBox(width: 6),
                      L10nText(
                        '${post.likes}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: post.likedByMe
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: post.likedByMe
                              ? MetoColors.primary
                              : MetoColors.mutedFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline, size: 16, color: MetoColors.mutedFg),
              const SizedBox(width: 6),
              L10nText('${post.comments}', style: _metaStyle),
              const Spacer(),
              if (!_isPostOwner(post))
                IconButton(
                  tooltip: S.auto('Şikayet Et / Raporla'),
                  onPressed: () async {
                    if (!await _requireMember(
                      'Şikayet için giriş yapmanız veya üye olmanız gerekiyor.',
                    )) {
                      return;
                    }
                    if (!mounted) return;
                    showUserSafetySheet(
                      context,
                      targetEmail: post.ownerEmail,
                      targetDisplayName: post.author,
                      contextLabel: 'forum_post',
                      contentType: 'forum_post',
                      contentId: '${post.id}',
                      onBlocked: () {
                        setState(() {
                          _selectedPost = null;
                          _cloudPosts = [
                            for (final p in _cloudPosts)
                              if (p.ownerEmail.trim().toLowerCase() !=
                                  post.ownerEmail.trim().toLowerCase())
                                p,
                          ];
                        });
                      },
                    );
                  },
                  icon: const Icon(
                    Icons.flag_outlined,
                    color: MetoColors.mutedFg,
                    size: 20,
                  ),
                ),
              if (_isPostOwner(post))
                IconButton(
                  tooltip: S.auto('Düzenle'),
                  onPressed: () => _startEditPost(post),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: MetoColors.primary,
                    size: 20,
                  ),
                ),
              if (_canModeratePost(post))
                IconButton(
                  tooltip: _isAdmin ? 'Admin: sil' : 'Sil',
                  onPressed: () => _deletePost(post),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
            ],
          ),
          const Divider(color: MetoColors.border, height: 32),
          const L10nText(
            'Yorumlar',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          if (_commentsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_rootComments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: L10nText(
                'Henüz yorum yok. İlk yorumu siz yazın.',
                style: TextStyle(fontSize: 13, color: MetoColors.mutedFg),
              ),
            )
          else
            ..._rootComments.expand((c) {
              final replies = _repliesOf(c.id);
              VoidCallback? reportFor(ForumComment x) {
                if (_isGuest) {
                  return () {
                    unawaited(_requireMember(
                      'Şikayet için giriş yapmanız veya üye olmanız gerekiyor.',
                    ));
                  };
                }
                final me = widget.userEmail.trim().toLowerCase();
                final owner = x.ownerEmail.trim().toLowerCase();
                if (owner.isNotEmpty && owner == me) return null;
                return () {
                  showUserSafetySheet(
                    context,
                    targetEmail: owner,
                    targetDisplayName: x.name,
                    contextLabel: 'forum_comment',
                    contentType: 'forum_comment',
                    contentId: '${x.id}',
                  );
                };
              }

              return [
                _CommentBubble(
                  c,
                  displayName: _displayName(c.name),
                  onDelete:
                      _canModerateComment(c) ? () => _deleteComment(c) : null,
                  onReply: () => _startReply(c),
                  onLike: () => _toggleCommentLike(c),
                  onReport: reportFor(c),
                ),
                for (final r in replies)
                  _CommentBubble(
                    r,
                    displayName: _displayName(r.name),
                    indented: true,
                    onDelete: _canModerateComment(r)
                        ? () => _deleteComment(r)
                        : null,
                    onReply: () => _startReply(c),
                    onLike: () => _toggleCommentLike(r),
                    onReport: reportFor(r),
                  ),
              ];
            }),
          ],
            ),
          ),
          Material(
            elevation: 6,
            color: MetoColors.card,
            child: SafeArea(
              top: false,
              bottom: !keyboardOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_replyingTo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: MetoColors.muted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: MetoColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.reply,
                                size: 16,
                                color: MetoColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: L10nText(
                                  '${_displayName(_replyingTo!.name)} adlı üyeye yanıt',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: MetoColors.foreground,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: S.auto('İptal'),
                                onPressed: _cancelReply,
                                icon: const Icon(Icons.close, size: 16),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 28,
                                  minHeight: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            enabled: !_commentSending,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              hintText: _replyingTo == null
                                  ? (_commentAnon
                                      ? 'Anonim yorum yaz...'
                                      : 'Yorum yaz...')
                                  : (_commentAnon
                                      ? 'Anonim yanıt yaz...'
                                      : 'Yanıt yaz...'),
                              filled: true,
                              fillColor: MetoColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: MetoColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: MetoColors.border),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _commentSending
                              ? null
                              : () => unawaited(_sendComment()),
                          style: FilledButton.styleFrom(
                            backgroundColor: MetoColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                MetoColors.primary.withValues(alpha: 0.4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _commentSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _replyingTo == null ? 'Gönder' : 'Yanıtla',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _commentSending
                          ? null
                          : () =>
                              setState(() => _commentAnon = !_commentAnon),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _commentAnon,
                                onChanged: _commentSending
                                    ? null
                                    : (v) => setState(
                                          () => _commentAnon = v ?? false,
                                        ),
                                activeColor: MetoColors.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const L10nText(
                              'Anonim yorum',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: MetoColors.foreground,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _commentAnon
                                  ? '(adın gizlenecek)'
                                  : '(isteğe bağlı)',
                              style: const TextStyle(
                                fontSize: 12,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPost() {
    final expertMode = _newPostCategory == 'Uzman' || _koseYazisi;
    final isEdit = _editingPost != null;

    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _closePostForm,
                icon: const Icon(Icons.chevron_left, color: MetoColors.primary),
              ),
              Text(
                isEdit
                    ? 'Gönderiyi Düzenle'
                    : (expertMode ? 'Köşe Yazısı' : 'Yeni Gönderi'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _fieldLabel('Kategori'),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _postCategories.contains(_newPostCategory)
                ? _newPostCategory
                : _postCategories.first,
            decoration: _inputDecoration(),
            items: _postCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _newPostCategory = v;
                if (v == 'Köşe Yazısı' || v == 'Uzman') {
                  _koseYazisi = true;
                  _anon = false;
                  // Köşe yazısında Doktor seçeneği varsayılan / görünür
                  if (_uzmanMeslek == 'Aile' ||
                      !uzmanMeslekler.contains(_uzmanMeslek)) {
                    _uzmanMeslek = _isProfUser ? 'Doktor' : 'Aile';
                  }
                } else {
                  _koseYazisi = false;
                }
                // Hazır alt tip seçimlerini kategoriye göre sıfırla;
                // özel (#custom) etiketler kalsın.
                final suggested =
                    suggestedTagsForCategory(v).map((e) => e.toLowerCase()).toSet();
                _formTags.removeWhere((t) => suggested.contains(t.toLowerCase()));
              });
            },
          ),
          if (_newPostCategory == 'Uzman' || _koseYazisi) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const L10nText(
                'Köşe yazısı: Meslektaş olarak deneyim, rehberlik veya bilgilendirici yazı paylaşın. Klinik tavsiye niteliğinde öneri vermeyin.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF065F46),
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _fieldLabel('Meslek'),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              value: uzmanMeslekler.contains(_uzmanMeslek)
                  ? _uzmanMeslek
                  : uzmanMeslekler.first,
              decoration: _inputDecoration(),
              items: uzmanMeslekler
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _uzmanMeslek = v);
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in uzmanMeslekler)
                  ChoiceChip(
                    label: Text(m),
                    selected: _uzmanMeslek == m,
                    onSelected: (_) => setState(() => _uzmanMeslek = m),
                    selectedColor: MetoColors.primary.withValues(alpha: 0.2),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _uzmanMeslek == m
                          ? MetoColors.primary
                          : MetoColors.mutedFg,
                    ),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const L10nText(
                'Köşe yazısı olarak paylaş',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const L10nText(
                'Doktor, fizyoterapist vb. uzman yazısı',
                style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
              ),
              value: _koseYazisi,
              activeThumbColor: MetoColors.primary,
              onChanged: (v) => setState(() {
                _koseYazisi = v;
                if (v) {
                  _newPostCategory = 'Uzman';
                  _anon = false;
                }
              }),
            ),
          ],
          const SizedBox(height: 16),
          _fieldLabel(expertMode ? 'Yazı başlığı' : 'Başlık'),
          const SizedBox(height: 4),
          TextField(
            controller: _titleController,
            decoration: _inputDecoration(
              hint: expertMode
                  ? 'Örn: Erken müdahalede aileye 5 pratik öneri'
                  : 'Paylaşmak istediğiniz konuyu yazın...',
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel(expertMode ? 'Köşe yazısı' : 'İçerik'),
          const SizedBox(height: 4),
          TextField(
            controller: _contentController,
            maxLines: expertMode ? 12 : 5,
            decoration: _inputDecoration(
              hint: expertMode
                  ? 'Uzman bakış açınızla bilgilendirici bir yazı yazın...'
                  : 'Deneyimlerinizi veya sorunuzu paylaşın...',
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('Etiketler'),
          const SizedBox(height: 4),
          L10nText(
            'Hazır alt tiplerden seçin veya # ile kendi etiketinizi ekleyin.',
            style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _suggestedFormTags)
                FilterChip(
                  label: Text(tag, style: const TextStyle(fontSize: 12)),
                  selected: _formTags
                      .any((t) => t.toLowerCase() == tag.toLowerCase()),
                  onSelected: (_) => _toggleFormTag(tag),
                  selectedColor: MetoColors.primary.withValues(alpha: 0.18),
                  checkmarkColor: MetoColors.primary,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _formTags.any((t) => t.toLowerCase() == tag.toLowerCase())
                        ? MetoColors.primary
                        : MetoColors.mutedFg,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagInputController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addCustomFormTag(),
                  decoration: _inputDecoration(
                    hint: '#OzelEtiketiniz',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _addCustomFormTag,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
                child: const L10nText('Ekle'),
              ),
            ],
          ),
          if (_formTags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in _formTags)
                  InputChip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => _toggleFormTag(tag),
                    backgroundColor: const Color(0xFFECFDF5),
                    side: const BorderSide(color: Color(0xFFA7F3D0)),
                    labelStyle: const TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ],
          if (!expertMode) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _anon,
                    onChanged: (v) => setState(() => _anon = v ?? false),
                    activeColor: MetoColors.primary,
                  ),
                  const L10nText(
                    'Anonim paylaş',
                    style: TextStyle(fontSize: 14, color: MetoColors.foreground),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _fieldLabel('Fotoğraflar (en fazla 2)'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._formPhotos.asMap().entries.map((e) {
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: FillPhoto(
                          source: e.value,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          placeholder: ColoredBox(
                            color: MetoColors.muted,
                            child: Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() => _formPhotos.removeAt(e.key)),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              if (_formPhotos.length < 2)
                InkWell(
                  onTap: _pickingPhoto ? null : _pickForumPhoto,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: MetoColors.muted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: MetoColors.border),
                    ),
                    child: _pickingPhoto
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(
                            Icons.add_a_photo_outlined,
                            color: MetoColors.mutedFg,
                          ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const L10nText(
              'Topluluk Kuralları: Kişisel tavsiye vermekten kaçının, diğer üyelere saygılı olun, mahremiyet haklarına dikkat edin.',
              style: TextStyle(fontSize: 12, color: Color(0xFFB45309), height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _publishing ? null : _publishPost,
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    MetoColors.primary.withValues(alpha: 0.4),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      isEdit
                          ? 'Kaydet'
                          : (expertMode ? 'Köşe Yazısını Yayınla' : 'Paylaş'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  static const _metaStyle = TextStyle(fontSize: 14, color: MetoColors.mutedFg);

  Widget _fieldLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: MetoColors.mutedFg,
          letterSpacing: 0.5,
        ),
      );

  InputDecoration _inputDecoration({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: MetoColors.mutedFg, fontSize: 14),
        filled: true,
        fillColor: MetoColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MetoColors.border),
        ),
      );
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.authorLabel,
    required this.onTap,
    required this.onLike,
    this.onEdit,
    this.onDelete,
    this.onReport,
  });

  final ForumPost post;
  final String authorLabel;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final chipLabel = post.expert && post.meslek.isNotEmpty
        ? post.meslek
        : post.category;

    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.pinned)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 11, color: MetoColors.primary),
                      SizedBox(width: 4),
                      L10nText(
                        'Öne Çıkan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: MetoColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  UserAvatar(
                    avatar: post.isAnonymous ? 'A' : post.avatar,
                    color: post.isAnonymous
                        ? const Color(0xFF94A3B8)
                        : post.avatarColor,
                    radius: 16,
                    fallbackName: authorLabel,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                authorLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: MetoColors.foreground,
                                ),
                              ),
                            ),
                            if (post.expert && post.meslek.isEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: MetoColors.primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Uzman',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: MetoColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          post.time,
                          style: const TextStyle(
                            fontSize: 12,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ForumReadBadge(count: post.views),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: forumCategoryColor(chipLabel),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chipLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              L10nText(
                post.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              L10nText(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: MetoColors.mutedFg,
                  height: 1.4,
                ),
              ),
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final tag in post.tags.take(6))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(999),
                          border:
                              Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF065F46),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (post.photos.isNotEmpty) ...[
                const SizedBox(height: 8),
                _ForumPhotoStrip(photos: post.photos, height: 200, compact: true),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            post.likedByMe
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            size: 14,
                            color: post.likedByMe
                                ? MetoColors.primary
                                : MetoColors.mutedFg,
                          ),
                          const SizedBox(width: 4),
                          L10nText(
                            '${post.likes}',
                            style: TextStyle(
                              fontSize: 14,
                              color: post.likedByMe
                                  ? MetoColors.primary
                                  : MetoColors.mutedFg,
                              fontWeight: post.likedByMe
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline,
                      size: 12, color: MetoColors.mutedFg),
                  const SizedBox(width: 4),
                  L10nText('${post.comments}', style: ForumPageState._metaStyle),
                  if (onReport != null || onEdit != null || onDelete != null) ...[
                    const Spacer(),
                    if (onReport != null)
                      IconButton(
                        tooltip: S.auto('Şikayet / Engelle'),
                        onPressed: onReport,
                        icon: const Icon(
                          Icons.flag_outlined,
                          size: 18,
                          color: MetoColors.mutedFg,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    if (onEdit != null)
                      IconButton(
                        tooltip: S.auto('Düzenle'),
                        onPressed: onEdit,
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: MetoColors.primary,
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: S.auto('Sil'),
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForumPhotoStrip extends StatelessWidget {
  const _ForumPhotoStrip({
    required this.photos,
    required this.height,
    this.compact = false,
  });

  final List<String> photos;
  final double height;
  final bool compact;

  void _open(BuildContext context, int index) {
    final images = galleryProvidersFromSources(photos);
    if (images.isEmpty) return;
    openPhotoGallery(
      context,
      images: images,
      initialIndex: index.clamp(0, images.length - 1),
    );
  }

  Widget _tile(BuildContext context, String source, int index) {
    return GestureDetector(
      onTap: () => _open(context, index),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 10 : 12),
        child: FillPhoto(
          source: source,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: ColoredBox(
            color: MetoColors.muted,
            child: Center(
              child: Icon(
                Icons.image_outlined,
                color: MetoColors.mutedFg,
                size: compact ? 28 : 36,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();

    if (photos.length == 1) {
      return _tile(context, photos.first, 0);
    }

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < photos.length && i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: _tile(context, photos[i], i)),
          ],
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble(
    this.comment, {
    this.displayName,
    this.onDelete,
    this.onReply,
    this.onLike,
    this.onReport,
    this.indented = false,
  });

  final ForumComment comment;
  final String? displayName;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final VoidCallback? onReport;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    final isAnon = comment.name.toLowerCase() == 'anonim';
    final nameLabel = displayName ?? comment.name;

    return Padding(
      padding: EdgeInsets.only(left: indented ? 28 : 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            avatar: isAnon ? '?' : comment.avatar,
            color: isAnon ? const Color(0xFF94A3B8) : comment.color,
            radius: indented ? 13 : 16,
            fallbackName: nameLabel,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(16),
                border: indented
                    ? Border.all(color: MetoColors.border)
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nameLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MetoColors.foreground,
                          ),
                        ),
                      ),
                      if (onReport != null)
                        IconButton(
                          tooltip: S.auto('Şikayet / Engelle'),
                          onPressed: onReport,
                          icon: const Icon(
                            Icons.flag_outlined,
                            size: 16,
                            color: MetoColors.mutedFg,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                      if (onDelete != null)
                        IconButton(
                          tooltip: S.auto('Yorumu sil'),
                          onPressed: onDelete,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.text,
                    style: TextStyle(
                      fontSize: 12,
                      color: MetoColors.foreground.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        comment.time,
                        style: const TextStyle(
                          fontSize: 11,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: onLike,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                comment.likedByMe
                                    ? Icons.thumb_up
                                    : Icons.thumb_up_outlined,
                                size: 14,
                                color: comment.likedByMe
                                    ? MetoColors.primary
                                    : MetoColors.mutedFg,
                              ),
                              const SizedBox(width: 4),
                              L10nText(
                                '${comment.likes}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: comment.likedByMe
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: comment.likedByMe
                                      ? MetoColors.primary
                                      : MetoColors.mutedFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onReply,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.reply,
                                size: 14,
                                color: MetoColors.mutedFg,
                              ),
                              SizedBox(width: 4),
                              L10nText(
                                'Yanıtla',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForumReadBadge extends StatelessWidget {
  const _ForumReadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MetoColors.muted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MetoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.visibility_outlined,
            size: 14,
            color: MetoColors.mutedFg,
          ),
          const SizedBox(width: 4),
          Text(
            forumReadLabel(count),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: MetoColors.mutedFg,
            ),
          ),
        ],
      ),
    );
  }
}
