import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../admin_config.dart';
import '../data/duyuru_data.dart';
import '../duyuru_store.dart';
import '../meto_theme.dart';
import 'story_marquee.dart';

/// Ana sayfa: disclaimer altı / hastalıklar üstü — story tarzı duyurular.
class DuyurularSection extends StatefulWidget {
  const DuyurularSection({
    super.key,
    required this.userEmail,
  });

  final String userEmail;

  @override
  State<DuyurularSection> createState() => _DuyurularSectionState();
}

class _DuyurularSectionState extends State<DuyurularSection> {
  List<DuyuruItem> _items = const [];
  Set<int> _seen = {};
  bool _loading = true;

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  List<DuyuruItem> get _sorted => sortDuyurular(_items, _seen);

  @override
  void initState() {
    super.initState();
    // Önbellek varsa anında göster; arka planda sessiz yenile.
    final cached = cachedDuyurular;
    if (cached != null) {
      _items = cached;
      _loading = false;
      // Okundu bilgisi prefs'ten gelsin (sıralama doğru kalsın)
      loadSeenDuyuruIds(widget.userEmail).then((seen) {
        if (!mounted) return;
        setState(() => _seen = seen);
      });
    }
    _reload(silent: cached != null);
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final items = await loadDuyurular(
      forceRefresh: !hasFreshDuyuruCache,
      viewerEmail: widget.userEmail,
    );
    final seen = await loadSeenDuyuruIds(widget.userEmail);
    if (!mounted) return;
    setState(() {
      _items = items;
      _seen = seen;
      _loading = false;
    });
  }

  List<DuyuruItem> get _visibleForStrip {
    final sorted = _sorted;
    if (_isAdmin) return sorted.where((d) => d.isActive).toList();
    return sorted;
  }

  Future<void> _openAdminForm({DuyuruItem? edit}) async {
    final result = await showModalBottomSheet<DuyuruItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminDuyuruSheet(
        adminEmail: widget.userEmail,
        edit: edit,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final rest = _items.where((d) => d.id != result.id).toList();
      _items = [result, ...rest];
      if (edit == null) {
        _seen = {..._seen}..remove(result.id);
      }
    });
  }

  Future<void> _openAdminManage() async {
    // Yönetim paneli için pasifler dahil taze liste
    final all = await loadDuyurular(
      forceRefresh: true,
      viewerEmail: widget.userEmail,
    );
    if (!mounted) return;
    setState(() => _items = all);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminManageSheet(
        items: List<DuyuruItem>.from(_items),
        onChanged: (next) {
          if (!mounted) return;
          setState(() => _items = next);
        },
        onAdd: () async {
          Navigator.pop(ctx);
          await _openAdminForm();
        },
        onEdit: (item) async {
          Navigator.pop(ctx);
          await _openAdminForm(edit: item);
        },
        onDelete: (item) async {
          await deleteDuyuru(item.id);
          if (!mounted) return;
          setState(() {
            _items = _items.where((d) => d.id != item.id).toList();
          });
        },
        onToggleActive: (item) async {
          final updated = await updateDuyuru(
            id: item.id,
            title: item.title,
            body: item.body,
            imageUrl: item.imageUrl,
            sourceUrl: item.sourceUrl,
            isActive: !item.isActive,
          );
          if (!mounted) return;
          setState(() {
            _items = [
              for (final d in _items)
                if (d.id == updated.id) updated else d,
            ];
          });
        },
      ),
    );
    // Manage sheet içindeki sil/toggle local state'i güncelledi; yeniden yükle
    await _reload(silent: true);
  }

  Future<void> _confirmDelete(DuyuruItem item) async {
    if (!_isAdmin) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Duyuruyu sil?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '"${item.title}" kalıcı olarak silinecek.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await deleteDuyuru(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((d) => d.id != item.id).toList();
        _seen = {..._seen}..remove(item.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Duyuru silindi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e')),
      );
    }
  }

  Future<void> _openViewer(DuyuruItem item) async {
    await markDuyuruSeen(email: widget.userEmail, id: item.id);
    if (!mounted) return;
    setState(() => _seen = {..._seen, item.id});

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim, secondary) {
        return _DuyuruFullscreen(
          item: item,
          isAdmin: _isAdmin,
          onClose: () => Navigator.of(ctx).pop(),
          onDelete: () async {
            Navigator.of(ctx).pop();
            await _confirmDelete(item);
          },
        );
      },
      transitionBuilder: (ctx, anim, secondary, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Güncel Duyurular & Haberler',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                if (_isAdmin) ...[
                  IconButton(
                    tooltip: 'Story yönetimi',
                    onPressed: _openAdminManage,
                    style: IconButton.styleFrom(
                      backgroundColor: MetoColors.primary.withValues(alpha: 0.1),
                      foregroundColor: MetoColors.primary,
                    ),
                    icon: const Icon(Icons.tune, size: 20),
                  ),
                  IconButton(
                    tooltip: 'Duyuru ekle',
                    onPressed: () => _openAdminForm(),
                    style: IconButton.styleFrom(
                      backgroundColor: MetoColors.primary.withValues(alpha: 0.1),
                      foregroundColor: MetoColors.primary,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                  ),
                ],
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              height: 108,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_visibleForStrip.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MetoColors.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: MetoColors.border),
                ),
                child: Text(
                  _isAdmin
                      ? 'Henüz aktif story yok. + veya Yönet ile ekleyin.'
                      : 'Şu an görüntülenecek duyuru yok.',
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ),
            )
          else
            StoryMarquee(
              height: 112,
              itemWidth: 90,
              pixelsPerSecond: 30,
              itemCount: _visibleForStrip.length,
              itemBuilder: (context, i) {
                final item = _visibleForStrip[i];
                final seen = _seen.contains(item.id);
                return _StoryCircle(
                  item: item,
                  seen: seen,
                  isAdmin: false,
                  onTap: () => _openViewer(item),
                  onLongPress:
                      _isAdmin ? () => _openAdminForm(edit: item) : null,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.item,
    required this.seen,
    required this.onTap,
    this.isAdmin = false,
    this.onLongPress,
  });

  final DuyuruItem item;
  final bool seen;
  final bool isAdmin;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 78,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: seen
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                MetoColors.primary,
                                Color(0xFF2F9B6A),
                                MetoColors.accentGold,
                              ],
                            ),
                      color: seen ? const Color(0xFFCBD5E1) : null,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: const BoxDecoration(
                        color: MetoColors.background,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: _DuyuruImage(
                          source: item.imageUrl,
                          width: 58,
                          height: 58,
                        ),
                      ),
                    ),
                  ),
                  if (isAdmin)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Material(
                        color: const Color(0xFFDC2626),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onLongPress,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: seen
                      ? MetoColors.mutedFg
                      : MetoColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DuyuruImage extends StatelessWidget {
  const _DuyuruImage({
    required this.source,
    this.width,
    this.height,
  });

  final String source;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final src = source.trim();
    Widget fallback() => ColoredBox(
          color: MetoColors.muted,
          child: SizedBox(
            width: width,
            height: height,
            child: const Icon(
              Icons.campaign_outlined,
              color: MetoColors.primary,
            ),
          ),
        );

    if (src.isEmpty) return fallback();

    if (src.startsWith('data:image')) {
      try {
        final b64 = src.contains(',') ? src.split(',').last : src;
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback(),
        );
      } catch (_) {
        return fallback();
      }
    }

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback(),
      );
    }

    return Image.asset(
      src,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback(),
    );
  }
}

class _DuyuruFullscreen extends StatelessWidget {
  const _DuyuruFullscreen({
    required this.item,
    required this.onClose,
    this.isAdmin = false,
    this.onDelete,
  });

  final DuyuruItem item;
  final VoidCallback onClose;
  final bool isAdmin;
  final VoidCallback? onDelete;

  Future<void> _openSource(BuildContext context) async {
    final raw = item.sourceUrl?.trim() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bağlantı açılamadı.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Dismissible(
          key: ValueKey('duyuru_fs_${item.id}'),
          direction: DismissDirection.down,
          onDismissed: (_) => onClose(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: MetoColors.card,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 11,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _DuyuruImage(source: item.imageUrl),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isAdmin && onDelete != null) ...[
                                  Material(
                                    color: const Color(0xCCDC2626),
                                    shape: const CircleBorder(),
                                    child: IconButton(
                                      tooltip: 'Sil',
                                      onPressed: onDelete,
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: IconButton(
                                    tooltip: 'Kapat',
                                    onPressed: onClose,
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 12,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Aşağı kaydırarak kapat',
                                style: GoogleFonts.nunito(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: GoogleFonts.nunito(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: MetoColors.foreground,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              item.body.isEmpty
                                  ? 'Detay metni eklenmemiş.'
                                  : item.body,
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                height: 1.5,
                                color: MetoColors.mutedFg,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (item.hasSource)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _openSource(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: MetoColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(
                              'Haberin Kaynağına Git / Detaylı Bilgi',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDuyuruSheet extends StatefulWidget {
  const _AdminDuyuruSheet({
    required this.adminEmail,
    this.edit,
  });

  final String adminEmail;
  final DuyuruItem? edit;

  @override
  State<_AdminDuyuruSheet> createState() => _AdminDuyuruSheetState();
}

class _AdminDuyuruSheetState extends State<_AdminDuyuruSheet> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _imageUrl;
  late final TextEditingController _sourceUrl;
  Uint8List? _pickedBytes;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _imageUrl = TextEditingController(text: e?.imageUrl ?? '');
    _sourceUrl = TextEditingController(text: e?.sourceUrl ?? '');
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _imageUrl.dispose();
    _sourceUrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _imageUrl.clear();
    });
  }

  String _resolveImagePayload() {
    if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
      final b64 = base64Encode(_pickedBytes!);
      return 'data:image/jpeg;base64,$b64';
    }
    return _imageUrl.text.trim();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    final image = _resolveImagePayload();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kısa başlık gerekli.')),
      );
      return;
    }
    if (image.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görsel yükleyin veya URL girin.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final src =
          _sourceUrl.text.trim().isEmpty ? null : _sourceUrl.text.trim();
      final DuyuruItem item;
      if (_isEdit) {
        item = await updateDuyuru(
          id: widget.edit!.id,
          title: title,
          body: body,
          imageUrl: image,
          sourceUrl: src,
          isActive: _isActive,
        );
      } else {
        item = await addDuyuru(
          title: title,
          body: body,
          imageUrl: image,
          sourceUrl: src,
          adminEmail: widget.adminEmail,
          isActive: _isActive,
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
            e.toString().contains('duyurular') ||
                    e.toString().contains('PGRST') ||
                    e.toString().contains('schema')
                ? 'Tablo yok. duyurular.sql / duyurular_is_active.sql çalıştırın.'
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                _isEdit ? 'Story düzenle' : 'Yeni Story / Duyuru',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Dairesel görsel',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.mutedFg,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: _pickedBytes != null
                          ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
                          : _DuyuruImage(
                              source: _imageUrl.text,
                              width: 64,
                              height: 64,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickImage,
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: const Text('Galeriden yükle'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _imageUrl,
                enabled: !_saving && _pickedBytes == null,
                decoration: const InputDecoration(
                  hintText: 'veya görsel URL (https://...)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                enabled: !_saving,
                maxLength: 40,
                decoration: const InputDecoration(
                  labelText: 'Kısa liste başlığı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _body,
                enabled: !_saving,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Tam ekran detay metni',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sourceUrl,
                enabled: !_saving,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Hedef link / kaynak (target_link)',
                  hintText: 'https://...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Aktif (is_active)',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  'Kapalıysa normal kullanıcılar görmez.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
                value: _isActive,
                activeThumbColor: MetoColors.primary,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _isActive = v),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEdit ? 'Güncelle' : 'Kaydet',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminManageSheet extends StatefulWidget {
  const _AdminManageSheet({
    required this.items,
    required this.onChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final List<DuyuruItem> items;
  final ValueChanged<List<DuyuruItem>> onChanged;
  final VoidCallback onAdd;
  final ValueChanged<DuyuruItem> onEdit;
  final Future<void> Function(DuyuruItem item) onDelete;
  final Future<void> Function(DuyuruItem item) onToggleActive;

  @override
  State<_AdminManageSheet> createState() => _AdminManageSheetState();
}

class _AdminManageSheetState extends State<_AdminManageSheet> {
  late List<DuyuruItem> _items;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _items = List<DuyuruItem>.from(widget.items);
  }

  void _emit(List<DuyuruItem> next) {
    setState(() => _items = next);
    widget.onChanged(next);
  }

  Future<void> _toggle(DuyuruItem item) async {
    setState(() => _busyId = item.id);
    try {
      await widget.onToggleActive(item);
      _emit([
        for (final d in _items)
          if (d.id == item.id) d.copyWith(isActive: !d.isActive) else d,
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(DuyuruItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Story sil?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '"${item.title}" kalıcı olarak silinecek.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = item.id);
    try {
      await widget.onDelete(item);
      _emit(_items.where((d) => d.id != item.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MetoColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Story yönetimi',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ekle'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Text(
                      'Henüz story yok.',
                      style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final busy = _busyId == item.id;
                      return Material(
                        color: MetoColors.background,
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
                          child: Row(
                            children: [
                              ClipOval(
                                child: _DuyuruImage(
                                  source: item.imageUrl,
                                  width: 48,
                                  height: 48,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.nunito(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.isActive ? 'Aktif' : 'Pasif',
                                      style: GoogleFonts.nunito(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: item.isActive
                                            ? MetoColors.primary
                                            : MetoColors.mutedFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (busy)
                                const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else ...[
                                IconButton(
                                  tooltip: item.isActive
                                      ? 'Pasife al'
                                      : 'Aktif et',
                                  onPressed: () => _toggle(item),
                                  icon: Icon(
                                    item.isActive
                                        ? Icons.visibility
                                        : Icons.visibility_off_outlined,
                                    color: item.isActive
                                        ? MetoColors.primary
                                        : MetoColors.mutedFg,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Düzenle',
                                  onPressed: () => widget.onEdit(item),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: 'Sil',
                                  onPressed: () => _delete(item),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
