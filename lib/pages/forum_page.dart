import 'package:flutter/material.dart';

import '../data/forum_data.dart';
import '../meto_theme.dart';

/// Figma Make `ForumTab` — Flutter portu.
class ForumPage extends StatefulWidget {
  const ForumPage({super.key});

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

  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  List<ForumPost> get _filteredPosts {
    final q = _searchQuery.trim().toLowerCase();
    return forumPosts.where((p) {
      final matchesCat =
          _activeCategory == 'Tümü' || p.category == _activeCategory;
      final matchesQ = q.isEmpty ||
          [p.title, p.content, p.author, p.category]
              .any((f) => f.toLowerCase().contains(q));
      return matchesCat && matchesQ;
    }).toList();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _PostCard(post: filtered[i], onTap: () {
                      setState(() => _selectedPost = filtered[i]);
                    }),
                  ),
          ),
        ],
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
    return ColoredBox(
      color: MetoColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _selectedPost = null),
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
                        Text(
                          post.author,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: MetoColors.foreground,
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
                            child: const Text(
                              'Uzman',
                              style: TextStyle(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: forumCategoryColor(post.category),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              post.category,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            post.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: MetoColors.foreground,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: TextStyle(
              fontSize: 14,
              color: MetoColors.foreground.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.thumb_up_outlined, size: 16, color: MetoColors.mutedFg),
              const SizedBox(width: 6),
              Text('${post.likes}', style: _metaStyle),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline, size: 16, color: MetoColors.mutedFg),
              const SizedBox(width: 6),
              Text('${post.comments}', style: _metaStyle),
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
          ...sampleComments.map(_CommentBubble.new),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
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
                onPressed: () {},
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Gönder',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNewPost() {
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
              const Text(
                'Yeni Gönderi',
                style: TextStyle(
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
              if (v != null) setState(() => _newPostCategory = v);
            },
          ),
          const SizedBox(height: 16),
          _fieldLabel('Başlık'),
          const SizedBox(height: 4),
          TextField(
            controller: _titleController,
            decoration: _inputDecoration(
              hint: 'Paylaşmak istediğiniz konuyu yazın...',
            ),
          ),
          const SizedBox(height: 16),
          _fieldLabel('İçerik'),
          const SizedBox(height: 4),
          TextField(
            controller: _contentController,
            maxLines: 5,
            decoration: _inputDecoration(
              hint: 'Deneyimlerinizi veya sorunuzu paylaşın...',
            ),
          ),
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
              onPressed: () => setState(() => _newPost = false),
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Paylaş',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
  const _PostCard({required this.post, required this.onTap});

  final ForumPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                            Text(
                              post.author,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MetoColors.foreground,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: forumCategoryColor(post.category),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      post.category,
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
                  const Icon(Icons.thumb_up_outlined, size: 12, color: MetoColors.mutedFg),
                  const SizedBox(width: 4),
                  Text('${post.likes}', style: _ForumPageState._metaStyle),
                  const SizedBox(width: 16),
                  const Icon(Icons.chat_bubble_outline, size: 12, color: MetoColors.mutedFg),
                  const SizedBox(width: 4),
                  Text('${post.comments}', style: _ForumPageState._metaStyle),
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
  const _CommentBubble(this.comment);

  final ForumComment comment;

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
                  Text(
                    comment.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MetoColors.foreground,
                    ),
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
