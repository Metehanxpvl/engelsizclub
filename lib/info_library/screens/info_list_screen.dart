import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_config.dart';
import '../../meto_theme.dart';
import '../info_library_repository.dart';
import '../models/info_content.dart';
import 'info_detail_screen.dart';

/// Kategoriye göre dinamik içerik listesi + admin ekleme.
class InfoListScreen extends StatefulWidget {
  const InfoListScreen({
    super.key,
    required this.category,
    this.title = 'Bilgi Kütüphanesi',
    this.adminEmail = '',
  });

  final String category;
  final String title;
  final String adminEmail;

  @override
  State<InfoListScreen> createState() => _InfoListScreenState();
}

class _InfoListScreenState extends State<InfoListScreen> {
  bool _loading = true;
  String? _error;
  List<InfoContent> _items = const [];

  bool get _isAdmin => isAppAdmin(widget.adminEmail);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await InfoLibraryRepository.instance.fetchByCategory(
        widget.category,
        viewerEmail: widget.adminEmail,
        includeInactive: _isAdmin,
      );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openForm({InfoContent? edit}) async {
    final result = await showModalBottomSheet<InfoContent>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _InfoContentFormSheet(
        category: widget.category,
        adminEmail: widget.adminEmail,
        edit: edit,
      ),
    );
    if (result == null || !mounted) return;
    await _reload();
  }

  Future<void> _delete(InfoContent item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sil'),
        content: Text('"${item.title}" silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await InfoLibraryRepository.instance.delete(item.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e')),
      );
    }
  }

  void _openDetail(InfoContent item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InfoDetailScreen(content: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          widget.title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              backgroundColor: MetoColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('İçerik ekle'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'İçerikler yüklenemedi.\n'
                          'Supabase’te info_library.sql çalıştırıldığından emin olun.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            color: MetoColors.mutedFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _reload,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? Center(
                      child: Text(
                        _isAdmin
                            ? 'Henüz içerik yok. + ile ekleyin.'
                            : 'Bu kategoride henüz içerik yok.',
                        style: GoogleFonts.nunito(
                          color: MetoColors.mutedFg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          return Material(
                            color: MetoColors.card,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openDetail(item),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: MetoColors.selectedBg,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        item.youtubeVideoId == null
                                            ? Icons.article_outlined
                                            : Icons.play_circle_fill,
                                        color: MetoColors.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.title,
                                            style: GoogleFonts.nunito(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: MetoColors.foreground,
                                            ),
                                          ),
                                          if (item.description
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              item.description.trim(),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.nunito(
                                                fontSize: 13,
                                                color: MetoColors.mutedFg,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          if (!item.isActive)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: Text(
                                                'Pasif',
                                                style: GoogleFonts.nunito(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.orange.shade800,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (_isAdmin)
                                      PopupMenuButton<String>(
                                        onSelected: (v) {
                                          if (v == 'edit') {
                                            _openForm(edit: item);
                                          } else if (v == 'delete') {
                                            _delete(item);
                                          }
                                        },
                                        itemBuilder: (_) => const [
                                          PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Düzenle'),
                                          ),
                                          PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Sil'),
                                          ),
                                        ],
                                      )
                                    else
                                      const Icon(
                                        Icons.chevron_right,
                                        color: MetoColors.mutedFg,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _InfoContentFormSheet extends StatefulWidget {
  const _InfoContentFormSheet({
    required this.category,
    required this.adminEmail,
    this.edit,
  });

  final String category;
  final String adminEmail;
  final InfoContent? edit;

  @override
  State<_InfoContentFormSheet> createState() => _InfoContentFormSheetState();
}

class _InfoContentFormSheetState extends State<_InfoContentFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _youtube;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _youtube = TextEditingController(text: e?.youtubeUrl ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _youtube.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık gerekli.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final InfoContent item;
      if (_isEdit) {
        item = await InfoLibraryRepository.instance.update(
          id: widget.edit!.id,
          title: title,
          description: _description.text,
          youtubeUrl: _youtube.text,
          category: widget.category,
          isActive: widget.edit!.isActive,
          sortOrder: widget.edit!.sortOrder,
        );
      } else {
        item = await InfoLibraryRepository.instance.create(
          title: title,
          description: _description.text,
          youtubeUrl: _youtube.text,
          category: widget.category,
          adminEmail: widget.adminEmail,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('info_library') ||
                    e.toString().contains('PGRST') ||
                    e.toString().contains('schema')
                ? 'Tablo yok. Supabase’te info_library.sql çalıştırın.'
                : 'Kaydedilemedi: $e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetoColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isEdit ? 'İçeriği düzenle' : 'Yeni içerik',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Başlık',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _youtube,
                decoration: const InputDecoration(
                  labelText: 'YouTube URL veya video ID',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEdit ? 'Kaydet' : 'Ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
