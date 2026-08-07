import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../home_hero_store.dart';
import '../meto_theme.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';

enum _AddMode { gallery, url }

/// Admin: ana sayfa geçiş görsellerini yönet.
class HomeHeroAdminSheet extends StatefulWidget {
  const HomeHeroAdminSheet({
    super.key,
    required this.adminEmail,
    required this.slides,
  });

  final String adminEmail;
  final List<HomeHeroSlide> slides;

  @override
  State<HomeHeroAdminSheet> createState() => _HomeHeroAdminSheetState();
}

class _HomeHeroAdminSheetState extends State<HomeHeroAdminSheet> {
  late List<HomeHeroSlide> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = List<HomeHeroSlide>.from(widget.slides)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> _add() async {
    if (_busy) return;
    final mode = await showModalBottomSheet<_AddMode>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const L10nText('Galeriden yükle'),
              onTap: () => Navigator.pop(ctx, _AddMode.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const L10nText('Görsel URL ekle'),
              onTap: () => Navigator.pop(ctx, _AddMode.url),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const L10nText('Vazgeç'),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;

    if (mode == _AddMode.gallery) {
      setState(() => _busy = true);
      try {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 88,
        );
        if (file == null || !mounted) return;
        final raw = await file.readAsBytes();
        final opt = await ImageOptimizeService.forListing(raw);
        final url = await R2StorageService.uploadBytes(
          bytes: opt.bytes,
          fileName: opt.fileName,
          contentType: opt.contentType,
        );
        final alt = await _askAlt(initial: '');
        if (!mounted) return;
        final item = await addHomeHeroSlide(
          imageUrl: url,
          altText: alt ?? '',
          adminEmail: widget.adminEmail,
        );
        setState(() => _items = [..._items, item]);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('r2-upload') ||
                      e.toString().contains('function')
                  ? 'Yükleme için R2 fonksiyonu gerekli. URL ile eklemeyi deneyin.'
                  : e.toString().replaceFirst('Bad state: ', ''),
            ),
          ),
        );
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final urlCtrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Görsel URL'),
        content: TextField(
          controller: urlCtrl,
          decoration: InputDecoration(
            hintText: 'https://...',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const L10nText('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
            child: const L10nText('Devam'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || !mounted) return;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Geçerli bir https URL girin.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final alt = await _askAlt(initial: '');
      if (!mounted) return;
      final item = await addHomeHeroSlide(
        imageUrl: url,
        altText: alt ?? '',
        adminEmail: widget.adminEmail,
      );
      setState(() => _items = [..._items, item]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Eklenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askAlt({required String initial}) async {
    final c = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Açıklama (alt metin)'),
        content: TextField(
          controller: c,
          decoration: InputDecoration(
            hintText: S.auto('Görsel kısa açıklaması'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, initial),
            child: const L10nText('Atla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const L10nText('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(HomeHeroSlide item) async {
    if (item.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Varsayılan görsel. Önce home_hero_slides.sql çalıştırın.',
          ),
        ),
      );
      return;
    }
    final alt = await _askAlt(initial: item.altText);
    if (alt == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await updateHomeHeroSlide(id: item.id, altText: alt);
      setState(() {
        _items = [
          for (final s in _items)
            if (s.id == updated.id) updated else s,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Güncellenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(HomeHeroSlide item) async {
    if (item.id <= 0) return;
    setState(() => _busy = true);
    try {
      final updated = await updateHomeHeroSlide(
        id: item.id,
        isActive: !item.isActive,
      );
      setState(() {
        _items = [
          for (final s in _items)
            if (s.id == updated.id) updated else s,
        ];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Durum değiştirilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(HomeHeroSlide item) async {
    if (item.id <= 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Görseli sil?'),
        content: const L10nText('Bu geçiş görseli kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const L10nText('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await deleteHomeHeroSlide(item.id);
      setState(() => _items = _items.where((s) => s.id != item.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Silinemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _move(int index, int delta) async {
    final j = index + delta;
    if (j < 0 || j >= _items.length) return;
    final a = _items[index];
    final b = _items[j];
    if (a.id <= 0 || b.id <= 0) return;
    setState(() => _busy = true);
    try {
      final ua = await updateHomeHeroSlide(id: a.id, sortOrder: b.sortOrder);
      final ub = await updateHomeHeroSlide(id: b.id, sortOrder: a.sortOrder);
      setState(() {
        _items = [
          for (final s in _items)
            if (s.id == ua.id)
              ua
            else if (s.id == ub.id)
              ub
            else
              s,
        ]..sort((x, y) => x.sortOrder.compareTo(y.sortOrder));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Sıra değiştirilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _items);
      },
      child: Container(
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
                    child: L10nText(
                      'Geçiş görselleri',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _busy ? null : _add,
                    icon: const Icon(Icons.add, size: 18),
                    label: const L10nText('Ekle'),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, _items),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            const Divider(height: 1),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: L10nText('Henüz görsel yok.'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = _items[i];
                        return Material(
                          color: MetoColors.background,
                          borderRadius: BorderRadius.circular(14),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(8),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 64,
                                height: 48,
                                child: _thumb(item),
                              ),
                            ),
                            title: Text(
                              item.altText.isEmpty
                                  ? 'Görsel #${item.id}'
                                  : item.altText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              item.isActive ? 'Aktif' : 'Pasif',
                              style: TextStyle(
                                fontSize: 12,
                                color: item.isActive
                                    ? MetoColors.primary
                                    : MetoColors.mutedFg,
                              ),
                            ),
                            trailing: Wrap(
                              children: [
                                IconButton(
                                  tooltip: S.auto('Yukarı'),
                                  onPressed:
                                      _busy ? null : () => _move(i, -1),
                                  icon: const Icon(Icons.arrow_upward, size: 18),
                                ),
                                IconButton(
                                  tooltip: S.auto('Aşağı'),
                                  onPressed: _busy ? null : () => _move(i, 1),
                                  icon:
                                      const Icon(Icons.arrow_downward, size: 18),
                                ),
                                IconButton(
                                  tooltip: S.auto('Düzenle'),
                                  onPressed: _busy ? null : () => _edit(item),
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                ),
                                IconButton(
                                  tooltip: item.isActive
                                      ? 'Pasifleştir'
                                      : 'Aktifleştir',
                                  onPressed: _busy ? null : () => _toggle(item),
                                  icon: Icon(
                                    item.isActive
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    size: 18,
                                  ),
                                ),
                                IconButton(
                                  tooltip: S.auto('Sil'),
                                  onPressed: _busy ? null : () => _delete(item),
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumb(HomeHeroSlide item) {
    if (item.isNetwork) {
      return Image.network(
        item.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: MetoColors.muted,
          child: Icon(Icons.broken_image_outlined),
        ),
      );
    }
    if (item.isAsset) {
      return Image.asset(
        item.assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: MetoColors.muted,
          child: Icon(Icons.image_outlined),
        ),
      );
    }
    return const ColoredBox(
      color: MetoColors.muted,
      child: Icon(Icons.image_outlined),
    );
  }
}
