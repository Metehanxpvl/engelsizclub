import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/more_menu_data.dart';
import '../meto_theme.dart';
import '../more_menu_store.dart';
import '../pages/gelisim_etkinlikleri_page.dart';

/// Story yönetimi ile aynı kalıp: Aktif/Pasif · Düzenle · Sil · Ekle
class AdminMoreMenuSheet extends StatefulWidget {
  const AdminMoreMenuSheet({super.key, required this.adminEmail});

  final String adminEmail;

  @override
  State<AdminMoreMenuSheet> createState() => _AdminMoreMenuSheetState();
}

class _AdminMoreMenuSheetState extends State<AdminMoreMenuSheet> {
  List<MoreMenuItem> _items = const [];
  bool _loading = true;
  String? _error;
  int? _busyId;

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
      final list = await loadMoreMenu(includeInactive: true, forceRefresh: true);
      if (!mounted) return;
      final onlyFallback = list.isNotEmpty && list.every((e) => e.id <= 0);
      setState(() {
        _items = list;
        _loading = false;
        if (onlyFallback) {
          _error =
              'Supabase’de daha_fazlasi_menu.sql henüz çalıştırılmamış. SQL Editor’de çalıştırın; sonra yenileyin.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(MoreMenuItem item) async {
    if (item.id <= 0) {
      _sqlNeeded();
      return;
    }
    setState(() => _busyId = item.id);
    try {
      await setMoreMenuActive(id: item.id, isActive: !item.isActive);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Güncellenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _sqlNeeded() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Önce Supabase’de daha_fazlasi_menu.sql çalıştırın.'),
      ),
    );
  }

  Future<void> _edit(MoreMenuItem? existing) async {
    if (existing != null && existing.id <= 0) {
      _sqlNeeded();
      return;
    }
    final result = await showModalBottomSheet<MoreMenuItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MoreMenuEditSheet(item: existing),
    );
    if (result == null) return;
    try {
      await upsertMoreMenuItem(result);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    }
  }

  Future<void> _delete(MoreMenuItem item) async {
    if (item.id <= 0) {
      _sqlNeeded();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Uygulama silinsin mi?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          '"${item.title}" Daha Fazlası menüsünden kaldırılacak.',
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
    if (ok != true) return;
    setState(() => _busyId = item.id);
    try {
      await deleteMoreMenuItem(item.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _leading(MoreMenuItem item) {
    IconData icon;
    switch (item.icon) {
      case 'family':
        icon = Icons.family_restroom;
      case 'balance':
        icon = Icons.balance_outlined;
      case 'grid':
        icon = Icons.grid_view_outlined;
      case 'search':
        icon = Icons.search;
      case 'eye':
        icon = Icons.visibility_outlined;
      case 'extension':
        icon = Icons.extension_outlined;
      default:
        icon = Icons.link;
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: MetoColors.primary.withValues(alpha: 0.12),
      child: Icon(icon, color: MetoColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.78;
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
                    'Daha Fazlası yönetimi',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _edit(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ekle'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  final email = widget.adminEmail;
                  Navigator.pop(context);
                  GelisimEtkinlikleriPage.open(
                    context,
                    adminEmail: email,
                  );
                },
                icon: const Icon(Icons.ondemand_video_outlined, size: 18),
                label: const Text('Gelişim etkinliklerini aç'),
              ),
            ),
          ),
          const Divider(height: 1),
          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _items.every((e) => e.id <= 0))
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        'Henüz uygulama yok. + Ekle ile ekleyin.',
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
                                _leading(item),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        [
                                          item.isUrl ? 'Link' : 'Uygulama',
                                          item.isActive ? 'Aktif' : 'Pasif',
                                          if (item.isBuiltin) 'Yerleşik',
                                        ].join(' · '),
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: item.isActive
                                              ? MetoColors.primary
                                              : MetoColors.mutedFg,
                                        ),
                                      ),
                                      if (item.subtitle.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.nunito(
                                            fontSize: 11,
                                            color: MetoColors.mutedFg,
                                          ),
                                        ),
                                      ],
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
                                    onPressed: () => _edit(item),
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

class _MoreMenuEditSheet extends StatefulWidget {
  const _MoreMenuEditSheet({this.item});

  final MoreMenuItem? item;

  @override
  State<_MoreMenuEditSheet> createState() => _MoreMenuEditSheetState();
}

class _MoreMenuEditSheetState extends State<_MoreMenuEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _link;
  late String _linkType;
  late bool _isActive;
  late int _sortOrder;

  @override
  void initState() {
    super.initState();
    final e = widget.item;
    _title = TextEditingController(text: e?.title ?? '');
    _subtitle = TextEditingController(text: e?.subtitle ?? '');
    _link = TextEditingController(text: e?.link ?? '');
    _linkType = e?.linkType ?? 'url';
    _isActive = e?.isActive ?? true;
    _sortOrder = e?.sortOrder ?? 100;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _link.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final link = _link.text.trim();
    if (title.isEmpty || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İsim ve link gerekli.')),
      );
      return;
    }
    final base = widget.item;
    Navigator.pop(
      context,
      MoreMenuItem(
        id: base?.id ?? 0,
        title: title,
        subtitle: _subtitle.text.trim(),
        linkType: _linkType,
        link: link,
        icon: base?.icon ?? 'link',
        sortOrder: _sortOrder,
        isActive: _isActive,
        isBuiltin: base?.isBuiltin ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final isNew = widget.item == null;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isNew ? 'Yeni uygulama / link' : 'Düzenle',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'İsim',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subtitle,
              decoration: const InputDecoration(
                labelText: 'Alt yazı',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'url', label: Text('Web linki')),
                ButtonSegment(value: 'route', label: Text('Uygulama')),
              ],
              selected: {_linkType},
              onSelectionChanged: (s) => setState(() => _linkType = s.first),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _link,
              decoration: InputDecoration(
                labelText: _linkType == 'url'
                    ? 'Link (https://… veya /bilgi-kutuphanesi/…)'
                    : 'Route (aile_kocu, haklar, kartlar, mchat, cvi, gelisim)',
                border: const OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Aktif',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text('Pasifse Daha Fazlası’nda görünmez'),
              value: _isActive,
              activeThumbColor: MetoColors.primary,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
