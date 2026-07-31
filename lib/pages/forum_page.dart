import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../data/forum_data.dart';
import '../forum_follow_store.dart';
import '../forum_store.dart';
import '../meto_theme.dart';
import '../services/catalog_adapters.dart';
import '../sohbet_store.dart';
import '../widgets/photo_gallery_lightbox.dart';
import '../widgets/user_avatar.dart';

/// Figma Make `ForumTab` — Flutter portu.
class ForumPage extends StatefulWidget {
  const ForumPage({
    super.key,
    this.userName = 'Siz',
    this.userEmail = '',
    this.userType = 'aile',
    this.profilFoto,
  });

  final String userName;
  final String userEmail;
  final String userType;
  /// data:image… profil fotoğrafı (varsa paylaşımlarda kullanılır).
  final String? profilFoto;

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  static const _pageSize = 10;

  ForumPost? _selectedPost;
  bool _newPost = false;
  ForumPost? _editingPost;
  String _searchQuery = '';
  String _activeCategory = 'Tümü';
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
  bool _pickingPhoto = false;
  final List<String> _formPhotos = [];
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
    setState(() {
      _newPost = false;
      _editingPost = null;
      _formPhotos.clear();
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
    _loadPosts();
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
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
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
    if (cat == 'Tümü' || widget.userEmail.trim().isEmpty || _followBusy) return;
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
    return _cloudPosts.where((p) {
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
          [p.title, p.content, p.author, p.category, p.meslek]
              .any((f) => f.toLowerCase().contains(q));
      return matchesCat && matchesQ;
    }).toList();
  }

  Future<void> _openPost(ForumPost post) async {
    setState(() {
      _selectedPost = post;
      _commentsLoading = true;
      _postComments = const [];
      _replyingTo = null;
    });
    final comments = await loadForumComments(post.id);
    final enriched = await _enrichComments(comments);
    if (!mounted) return;
    setState(() {
      _postComments = enriched;
      _commentsLoading = false;
    });
  }

  List<ForumComment> get _rootComments =>
      _postComments.where((c) => !c.isReply).toList();

  List<ForumComment> _repliesOf(int parentId) =>
      _postComments.where((c) => c.parentId == parentId).toList();

  void _startReply(ForumComment c) {
    setState(() => _replyingTo = c);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  Future<void> _toggleCommentLike(ForumComment c) async {
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
        const SnackBar(content: Text('Bu gönderi silinemez')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isAdmin ? 'Gönderiyi sil (Admin)' : 'Gönderiyi sil'),
        content: Text('"${post.title}" kalıcı silinecek. Emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Sil'),
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
        const SnackBar(content: Text('Gönderi silindi')),
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
        content: const Text('Bu yorum kalıcı silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Sil'),
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
        const SnackBar(content: Text('Yorum silindi')),
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
    final post = _selectedPost;
    final text = _commentController.text.trim();
    if (post == null || text.isEmpty || _commentSending) return;
    final parent = _replyingTo;
    // Yanıtlar yalnızca kök yoruma bağlanır (tek seviye)
    final parentId = parent == null
        ? null
        : (parent.isReply ? parent.parentId : parent.id);
    setState(() => _commentSending = true);
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
      _commentController.clear();
      final updated = post.copyWith(comments: post.comments + 1);
      setState(() {
        _postComments = [..._postComments, c];
        _selectedPost = updated;
        _replyingTo = null;
        _commentAnon = false;
        _cloudPosts = [
          for (final p in _cloudPosts)
            if (p.id == post.id) updated else p,
        ];
        _commentSending = false;
      });
    } catch (e) {
      if (!mounted) return;
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

  Uint8List? _decodeForumPhoto(String dataUrl) {
    try {
      var raw = dataUrl;
      if (raw.contains(',')) raw = raw.split(',').last;
      return Uint8List.fromList(base64Decode(raw));
    } catch (_) {
      return null;
    }
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
                child: Text(
                  'Fotoğraf ekle',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: MetoColors.primary),
                title: const Text('Galeriden seç'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: MetoColors.primary),
                title: const Text('Kamerayla çek'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç'),
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
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 75,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Boş görsel seçildi.');
      }
      const mime = 'image/jpeg';
      final encoded = base64Encode(bytes);
      if (encoded.length > 500000) {
        throw StateError(
          'Fotoğraf çok büyük. Daha küçük bir fotoğraf seçin.',
        );
      }
      final dataUrl = 'data:$mime;base64,$encoded';
      if (!mounted) return;
      setState(() => _formPhotos.add(dataUrl));
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      final friendly = msg.contains('büyük') || msg.contains('boş')
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
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    final eksik = <String>[];
    if (title.isEmpty) eksik.add('Başlık');
    if (content.isEmpty) eksik.add('İçerik');
    if (eksik.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lütfen doldurun: ${eksik.join(', ')}')),
      );
      return;
    }
    if (_publishing) return;
    setState(() => _publishing = true);

    final isExpert = _newPostCategory == 'Uzman' || _koseYazisi;
    final category = isExpert ? 'Uzman' : _newPostCategory;
    final meslek = isExpert ? _uzmanMeslek : '';

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
          avatarPhoto: (isExpert || !_anon) ? widget.profilFoto : null,
        );
        unawaited(ForumFollowStore.notifyFollowersOfPost(
          category: isExpert ? 'Köşe Yazısı' : category,
          title: title,
          actorName: widget.userName,
          actorEmail: widget.userEmail,
        ));
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
      setState(() {
        if (isEdit) {
          _cloudPosts = [
            for (final p in _cloudPosts) p.id == post.id ? post : p,
          ];
        } else {
          _cloudPosts = [post, ..._cloudPosts];
        }
        _formPhotos.clear();
        _newPost = false;
        _editingPost = null;
        _anon = false;
        _koseYazisi = _isProfUser;
        _activeCategory = isExpert ? 'Köşe Yazısı' : 'Tümü';
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
                        Text(
                          'Topluluk',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.foreground,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
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
                    onPressed: () => setState(() => _newPost = true),
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
                    child: const Text(
                      '+ Paylaş',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.search,
                        size: 15, color: MetoColors.mutedFg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: const TextStyle(
                          fontSize: 14,
                          color: MetoColors.foreground,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Konularda ara...',
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
                  child:
                      CircularProgressIndicator(color: MetoColors.primary),
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
                    onTap: () => _openPost(post),
                    onLike: () => _toggleLike(post),
                    onEdit: _isPostOwner(post)
                        ? () => _startEditPost(post)
                        : null,
                    onDelete: _canModeratePost(post)
                        ? () => _deletePost(post)
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
      return Text(
        '$total gönderi',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, color: MetoColors.mutedFg),
      );
    }
    final pageCount = (total / _pageSize).ceil();
    final page = _listPage.clamp(0, pageCount - 1);
    return Column(
      children: [
        Text(
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
                      child: Text(
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
            const Text(
              'Sonuç bulunamadı',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MetoColors.foreground,
              ),
            ),
            const SizedBox(height: 4),
            Text(
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

    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
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
            label: const Text(
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
                fallbackName: post.author,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.author,
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
          const SizedBox(height: 8),
          Text(
            post.title,
            style: TextStyle(
              fontSize: post.expert ? 22 : 18,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
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
                      Text(
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
              Text('${post.comments}', style: _metaStyle),
              const Spacer(),
              if (_isPostOwner(post))
                IconButton(
                  tooltip: 'Düzenle',
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
          const Text(
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
              child: Text(
                'Henüz yorum yok. İlk yorumu siz yazın.',
                style: TextStyle(fontSize: 13, color: MetoColors.mutedFg),
              ),
            )
          else
            ..._rootComments.expand((c) {
              final replies = _repliesOf(c.id);
              return [
                _CommentBubble(
                  c,
                  onDelete:
                      _canModerateComment(c) ? () => _deleteComment(c) : null,
                  onReply: () => _startReply(c),
                  onLike: () => _toggleCommentLike(c),
                ),
                for (final r in replies)
                  _CommentBubble(
                    r,
                    indented: true,
                    onDelete: _canModerateComment(r)
                        ? () => _deleteComment(r)
                        : null,
                    onReply: () => _startReply(c),
                    onLike: () => _toggleCommentLike(r),
                  ),
              ];
            }),
          const SizedBox(height: 8),
          if (_replyingTo != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: MetoColors.muted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: MetoColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.reply, size: 16, color: MetoColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_replyingTo!.name} adlı üyeye yanıt',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: MetoColors.foreground,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'İptal',
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
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
                  decoration: InputDecoration(
                    hintText: _replyingTo == null
                        ? (_commentAnon
                            ? 'Anonim yorum yaz...'
                            : 'Yorum yaz...')
                        : (_commentAnon ? 'Anonim yanıt yaz...' : 'Yanıt yaz...'),
                    filled: true,
                    fillColor: MetoColors.card,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: MetoColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: MetoColors.border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _commentSending ? null : _sendComment,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      MetoColors.primary.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
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
          const SizedBox(height: 8),
          InkWell(
            onTap: _commentSending
                ? null
                : () => setState(() => _commentAnon = !_commentAnon),
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
                          : (v) => setState(() => _commentAnon = v ?? false),
                      activeColor: MetoColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
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
              child: const Text(
                'Köşe yazısı: Meslektaş olarak deneyim, rehberlik veya bilgilendirici yazı paylaşın. Tıbbi teşhis/tedavi önerisi vermeyin.',
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
              title: const Text(
                'Köşe yazısı olarak paylaş',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
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
                  const Text(
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
                final bytes = _decodeForumPhoto(e.value);
                return Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: MetoColors.muted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MetoColors.border),
                        image: bytes == null
                            ? null
                            : DecorationImage(
                                image: MemoryImage(bytes),
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: bytes == null
                          ? const Center(
                              child: Icon(
                                Icons.image_outlined,
                                color: MetoColors.mutedFg,
                              ),
                            )
                          : null,
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
            child: const Text(
              'Topluluk Kuralları: Tıbbi tavsiye vermekten kaçının, diğer üyelere saygılı olun, mahremiyet haklarına dikkat edin.',
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
    required this.onTap,
    required this.onLike,
    this.onEdit,
    this.onDelete,
  });

  final ForumPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
                      Text(
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
                    fallbackName: post.author,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                post.author,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: MetoColors.foreground,
                                ),
                              ),
                            ),
                            if (post.expert) ...[
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
                                child: Text(
                                  post.meslek.isNotEmpty ? post.meslek : 'Uzman',
                                  style: const TextStyle(
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: forumCategoryColor(chipLabel),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      chipLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: MetoColors.mutedFg,
                  height: 1.4,
                ),
              ),
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
                          Text(
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
                  Text('${post.comments}', style: _ForumPageState._metaStyle),
                  if (onEdit != null || onDelete != null) ...[
                    const Spacer(),
                    if (onEdit != null)
                      IconButton(
                        tooltip: 'Düzenle',
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
                        tooltip: 'Sil',
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

Uint8List? _forumPhotoBytes(String dataUrl) {
  try {
    var raw = dataUrl;
    if (raw.contains(',')) raw = raw.split(',').last;
    return Uint8List.fromList(base64Decode(raw));
  } catch (_) {
    return null;
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

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();

    if (photos.length == 1) {
      final bytes = _forumPhotoBytes(photos.first);
      return GestureDetector(
        onTap: () => _open(context, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 10 : 12),
          child: ColoredBox(
            color: MetoColors.muted,
            child: bytes == null
                ? SizedBox(
                    height: height,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: MetoColors.mutedFg),
                    ),
                  )
                : SizedBox(
                    height: height,
                    width: double.infinity,
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: height,
                    ),
                  ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < photos.length && i < 2; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => _open(context, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(compact ? 10 : 12),
                  child: ColoredBox(
                    color: MetoColors.muted,
                    child: Builder(
                      builder: (context) {
                        final bytes = _forumPhotoBytes(photos[i]);
                        if (bytes == null) {
                          return SizedBox(
                            height: height,
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: MetoColors.mutedFg),
                            ),
                          );
                        }
                        return Image.memory(
                          bytes,
                          height: height,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentBubble extends StatelessWidget {
  const _CommentBubble(
    this.comment, {
    this.onDelete,
    this.onReply,
    this.onLike,
    this.indented = false,
  });

  final ForumComment comment;
  final VoidCallback? onDelete;
  final VoidCallback? onReply;
  final VoidCallback? onLike;
  final bool indented;

  @override
  Widget build(BuildContext context) {
    final isAnon = comment.name.toLowerCase() == 'anonim';

    return Padding(
      padding: EdgeInsets.only(left: indented ? 28 : 0, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            avatar: isAnon ? '?' : comment.avatar,
            color: isAnon ? const Color(0xFF94A3B8) : comment.color,
            radius: indented ? 13 : 16,
            fallbackName: comment.name,
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
                          comment.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: MetoColors.foreground,
                          ),
                        ),
                      ),
                      if (onDelete != null)
                        IconButton(
                          tooltip: 'Yorumu sil',
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
                              Text(
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
                              Text(
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
