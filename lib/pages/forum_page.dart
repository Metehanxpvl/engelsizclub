import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../data/forum_data.dart';
import '../forum_store.dart';
import '../meto_theme.dart';
import '../sohbet_store.dart';

/// Figma Make `ForumTab` — Flutter portu.
class ForumPage extends StatefulWidget {
  const ForumPage({
    super.key,
    this.userName = 'Siz',
    this.userEmail = '',
    this.userType = 'aile',
  });

  final String userName;
  final String userEmail;
  final String userType;

  @override
  State<ForumPage> createState() => _ForumPageState();
}

class _ForumPageState extends State<ForumPage> {
  ForumPost? _selectedPost;
  bool _newPost = false;
  String _searchQuery = '';
  String _activeCategory = 'Tümü';
  bool _anon = false;
  String _newPostCategory = newPostCategories.first;
  String _uzmanMeslek = uzmanMeslekler.first;
  bool _koseYazisi = false;
  bool _loading = true;
  bool _publishing = false;
  bool _commentSending = false;
  bool _likeBusy = false;
  List<ForumPost> _cloudPosts = const [];
  List<ForumComment> _postComments = const [];
  bool _commentsLoading = false;
  RealtimeChannel? _forumChannel;

  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _commentController = TextEditingController();

  bool get _isProfUser =>
      widget.userType == 'uzman' || widget.userType == 'bakici';

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  bool _canModeratePost(ForumPost post) =>
      _isAdmin ||
      (post.ownerEmail.isNotEmpty &&
          post.ownerEmail == widget.userEmail.trim().toLowerCase());

  bool _canModerateComment(ForumComment c) =>
      _isAdmin ||
      (c.ownerEmail.isNotEmpty &&
          c.ownerEmail == widget.userEmail.trim().toLowerCase());

  @override
  void initState() {
    super.initState();
    if (_isProfUser) {
      _newPostCategory = 'Uzman';
      _koseYazisi = true;
    } else {
      // Aileler köşe yazısında "Aile" olarak paylaşır
      _uzmanMeslek = 'Aile';
    }
    _loadPosts();
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
    if (!mounted) return;
    setState(() {
      _cloudPosts = posts;
      _loading = false;
      if (_selectedPost != null) {
        final updated = posts.where((p) => p.id == _selectedPost!.id).firstOrNull;
        if (updated != null) _selectedPost = updated;
      }
    });
  }

  List<ForumPost> get _filteredPosts {
    final q = _searchQuery.trim().toLowerCase();
    // Yalnızca buluttaki gerçek gönderiler (örnek/bot yok)
    return _cloudPosts.where((p) {
      final matchesCat = switch (_activeCategory) {
        'Tümü' => true,
        'Uzman' => p.expert || p.category == 'Uzman' || isUzmanMeslek(p.category),
        'Köşe Yazısı' => p.expert,
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
    });
    final comments = await loadForumComments(post.id);
    if (!mounted) return;
    setState(() {
      _postComments = comments;
      _commentsLoading = false;
    });
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
      final updated = post.copyWith(
        comments: (post.comments - 1).clamp(0, 999999),
      );
      setState(() {
        _postComments = _postComments.where((x) => x.id != c.id).toList();
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
    setState(() => _commentSending = true);
    try {
      final c = await addForumComment(
        postId: post.id,
        body: text,
        authorName: widget.userName,
        authorEmail: widget.userEmail,
      );
      if (!mounted) return;
      _commentController.clear();
      final updated = post.copyWith(comments: post.comments + 1);
      setState(() {
        _postComments = [..._postComments, c];
        _selectedPost = updated;
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
                    e.toString().contains('PGRST') ||
                    e.toString().contains('schema cache')
                ? 'Yorum tablosu yok. Supabase’de forum_interact.sql çalıştırın.'
                : 'Yorum gönderilemedi: $e',
          ),
        ),
      );
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
      final post = await publishForumPost(
        title: title,
        content: content,
        category: category,
        authorName: widget.userName,
        authorEmail: widget.userEmail,
        anon: isExpert ? false : _anon,
        expert: isExpert,
        meslek: meslek,
      );
      if (!mounted) return;
      _titleController.clear();
      _contentController.clear();
      setState(() {
        _cloudPosts = [post, ..._cloudPosts];
        _newPost = false;
        _anon = false;
        _koseYazisi = _isProfUser;
        _activeCategory = isExpert ? 'Köşe Yazısı' : 'Tümü';
        _publishing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isExpert
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
                : 'Paylaşılamadı: $e',
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
                itemCount: forumCategories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = forumCategories[i];
                  final active = cat == _activeCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _activeCategory = cat),
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
            else
              ...filtered.map(
                (post) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _PostCard(
                    post: post,
                    onTap: () => _openPost(post),
                    onLike: () => _toggleLike(post),
                    onDelete: _canModeratePost(post)
                        ? () => _deletePost(post)
                        : null,
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
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
              CircleAvatar(
                radius: 20,
                backgroundColor: post.avatarColor,
                child: Text(
                  post.avatar,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          else if (_postComments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Henüz yorum yok. İlk yorumu siz yazın.',
                style: TextStyle(fontSize: 13, color: MetoColors.mutedFg),
              ),
            )
          else
            ..._postComments.map(
              (c) => _CommentBubble(
                c,
                onDelete: _canModerateComment(c) ? () => _deleteComment(c) : null,
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendComment(),
                  decoration: InputDecoration(
                    hintText: 'Yorum yaz...',
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
                    : const Text(
                        'Gönder',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewPost() {
    final expertMode = _newPostCategory == 'Uzman' || _koseYazisi;

    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _newPost = false),
                icon: const Icon(Icons.chevron_left, color: MetoColors.primary),
              ),
              Text(
                expertMode ? 'Köşe Yazısı' : 'Yeni Gönderi',
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
            value: _newPostCategory,
            decoration: _inputDecoration(),
            items: newPostCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _newPostCategory = v;
                if (v == 'Uzman') {
                  _koseYazisi = true;
                  _anon = false;
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
              value: _uzmanMeslek,
              decoration: _inputDecoration(),
              items: uzmanMeslekler
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _uzmanMeslek = v);
              },
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
                      expertMode ? 'Köşe Yazısını Yayınla' : 'Paylaş',
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
    this.onDelete,
  });

  final ForumPost post;
  final VoidCallback onTap;
  final VoidCallback onLike;
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
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: post.avatarColor,
                    child: Text(
                      post.avatar,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
                  if (onDelete != null) ...[
                    const Spacer(),
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

class _CommentBubble extends StatelessWidget {
  const _CommentBubble(this.comment, {this.onDelete});

  final ForumComment comment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final initials = comment.name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .join();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: comment.color,
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MetoColors.muted,
                borderRadius: BorderRadius.circular(16),
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
                  const SizedBox(height: 4),
                  Text(
                    comment.time,
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
}
