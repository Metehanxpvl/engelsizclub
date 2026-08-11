import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../admin_config.dart';
import '../../meto_theme.dart';
import '../info_library_repository.dart';
import '../models/info_content.dart';
import '../widgets/info_youtube_player.dart';

/// Kategori sayfası: başlık → uygulama içi video → açıklama blokları.
/// Admin istediği kadar blok ekler; DB’de yalnızca metin + YouTube linki tutulur.
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
  bool _savingOrder = false;

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
        nextSortOrder: _items.isEmpty
            ? 0
            : _items.map((e) => e.sortOrder).reduce((a, b) => a > b ? a : b) + 1,
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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (!_isAdmin || _savingOrder) return;
    if (oldIndex == newIndex) return;
    setState(() {
      final next = List<InfoContent>.from(_items);
      final item = next.removeAt(oldIndex);
      next.insert(newIndex, item);
      _items = next;
      _savingOrder = true;
    });
    try {
      await InfoLibraryRepository.instance.reorder(_items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sıra kaydedilemedi: $e')),
      );
      await _reload();
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: MetoColors.foreground,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Videolar uygulamada açılır; YouTube’a yönlendirilmezsiniz.',
          style: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MetoColors.mutedFg,
          ),
        ),
        if (_isAdmin && _items.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _savingOrder
                ? 'Sıra kaydediliyor…'
                : 'Basılı tutup sürükleyerek video sırasını değiştirin.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.primary,
            ),
          ),
        ],
        const SizedBox(height: 18),
      ],
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
              label: const Text('Blok ekle'),
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
                          'Supabase’te info_library.sql dosyasını çalıştırın.',
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
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      children: [
                        _header(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: Text(
                              _isAdmin
                                  ? 'Henüz blok yok.\nSağ alttan “Blok ekle” ile başlık, YouTube linki ve açıklama ekleyin.'
                                  : 'Bu kategoride henüz içerik yok.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                color: MetoColors.mutedFg,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : _isAdmin
                      ? ReorderableListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          buildDefaultDragHandles: false,
                          header: _header(),
                          footer: Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: Text(
                              'Bu içerikler bilgilendirme amaçlıdır; tıbbi tavsiye değildir.',
                              style: GoogleFonts.nunito(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                          ),
                          itemCount: _items.length,
                          onReorderItem: _onReorder,
                          proxyDecorator: (child, index, animation) {
                            return Material(
                              elevation: 6,
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.transparent,
                              child: child,
                            );
                          },
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return Padding(
                              key: ValueKey(item.id),
                              padding: EdgeInsets.only(
                                bottom: i == _items.length - 1 ? 0 : 22,
                              ),
                              child: ReorderableDelayedDragStartListener(
                                index: i,
                                child: _InfoContentBlock(
                                  item: item,
                                  isAdmin: true,
                                  showDragHint: true,
                                  onEdit: () => _openForm(edit: item),
                                  onDelete: () => _delete(item),
                                ),
                              ),
                            );
                          },
                        )
                      : RefreshIndicator(
                          onRefresh: _reload,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 100),
                            itemCount: _items.length + 2,
                            itemBuilder: (context, i) {
                              if (i == 0) return _header();
                              if (i == _items.length + 1) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 24),
                                  child: Text(
                                    'Bu içerikler bilgilendirme amaçlıdır; tıbbi tavsiye değildir.',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: MetoColors.mutedFg,
                                    ),
                                  ),
                                );
                              }
                              final item = _items[i - 1];
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom:
                                      i - 1 == _items.length - 1 ? 0 : 22,
                                ),
                                child: _InfoContentBlock(
                                  item: item,
                                  isAdmin: false,
                                  onEdit: () {},
                                  onDelete: () {},
                                ),
                              );
                            },
                          ),
                        ),
    );
  }
}

/// Tek içerik bloğu: başlık → sayfa içi video → açıklama.
class _InfoContentBlock extends StatefulWidget {
  const _InfoContentBlock({
    required this.item,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
    this.showDragHint = false,
  });

  final InfoContent item;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool showDragHint;

  @override
  State<_InfoContentBlock> createState() => _InfoContentBlockState();
}

class _InfoContentBlockState extends State<_InfoContentBlock>
    with AutomaticKeepAliveClientMixin {
  bool _play = false;

  @override
  bool get wantKeepAlive => _play;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final item = widget.item;
    final videoId = item.youtubeVideoId;

    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MetoColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showDragHint) ...[
                  const Padding(
                    padding: EdgeInsets.only(right: 8, top: 2),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 22,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ],
                Expanded(
                  child: Text(
                    item.title,
                    style: GoogleFonts.nunito(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                      height: 1.25,
                    ),
                  ),
                ),
                if (widget.isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') widget.onEdit();
                      if (v == 'delete') widget.onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
              ],
            ),
            if (!item.isActive)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Pasif (yalnızca admin görür)',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (videoId == null)
              Container(
                height: 160,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MetoColors.muted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Video linki yok veya geçersiz',
                  style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                ),
              )
            else if (_play)
              InfoYoutubePlayer(youtubeUrlOrId: item.youtubeUrl)
            else
              Material(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _play = true),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black87,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.ondemand_video,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                        ),
                        Container(color: Colors.black38),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                        Positioned(
                          left: 12,
                          bottom: 10,
                          right: 12,
                          child: Text(
                            'İzlemek için dokunun · YouTube’a çıkılmaz',
                            style: GoogleFonts.nunito(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (item.source.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Kaynak: ${item.source.trim()}',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                item.description.trim(),
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoContentFormSheet extends StatefulWidget {
  const _InfoContentFormSheet({
    required this.category,
    required this.adminEmail,
    required this.nextSortOrder,
    this.edit,
  });

  final String category;
  final String adminEmail;
  final int nextSortOrder;
  final InfoContent? edit;

  @override
  State<_InfoContentFormSheet> createState() => _InfoContentFormSheetState();
}

class _InfoContentFormSheetState extends State<_InfoContentFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _youtube;
  late final TextEditingController _source;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _youtube = TextEditingController(text: e?.youtubeUrl ?? '');
    _source = TextEditingController(text: e?.source ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _youtube.dispose();
    _source.dispose();
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
    final yt = _youtube.text.trim();
    if (yt.isNotEmpty && extractYoutubeVideoId(yt) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir YouTube linki girin.')),
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
          youtubeUrl: yt,
          source: _source.text,
          category: widget.category,
          isActive: widget.edit!.isActive,
          sortOrder: widget.edit!.sortOrder,
        );
      } else {
        item = await InfoLibraryRepository.instance.create(
          title: title,
          description: _description.text,
          youtubeUrl: yt,
          source: _source.text,
          category: widget.category,
          adminEmail: widget.adminEmail,
          sortOrder: widget.nextSortOrder,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = e.toString();
      final missing = msg.contains('schema cache') ||
          msg.contains('does not exist') ||
          msg.contains('PGRST204') ||
          msg.contains('PGRST205') ||
          (msg.contains('column') && msg.contains('source'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 8),
          content: Text(
            missing
                ? 'Tablo/sütun yok veya şema eski. Supabase SQL Editor’de info_library.sql çalıştırıp notify pgrst yapın.\n\nDetay: $msg'
                : 'Kaydedilemedi: $msg',
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
                _isEdit ? 'Bloğu düzenle' : 'Yeni içerik bloğu',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sıra: başlık → YouTube linki → kaynak → açıklama. Video dosyası yüklenmez; yalnızca link kaydedilir.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '1. Başlık',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _youtube,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '2. YouTube linki',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  border: OutlineInputBorder(),
                  helperText: 'Kullanıcı videoyu uygulamada izler',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _source,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '3. Kaynak (kimin videosu)',
                  hintText: 'örn. Pathways.org, Dr. Ayşe Yılmaz',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                minLines: 4,
                maxLines: 10,
                decoration: const InputDecoration(
                  labelText: '4. Açıklama',
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
                    : Text(_isEdit ? 'Kaydet' : 'Bloğu ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
