import 'package:flutter/material.dart';

import '../data/more_menu_data.dart';
import '../meto_theme.dart';
import '../more_menu_store.dart';
import 'admin_gelisim_etkinlik_sheet.dart';

/// Admin: Daha Fazlası menü — aktif/pasif, isim, link ekle/düzenle.
class AdminMoreMenuSheet extends StatefulWidget {
  const AdminMoreMenuSheet({super.key});

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
      setState(() {
        _items = list;
        _loading = false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Önce Supabase’de daha_fazlasi_menu.sql çalıştırın.',
          ),
        ),
      );
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

  Future<void> _edit(MoreMenuItem? existing) async {
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
    if (item.isBuiltin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yerleşik öğe silinmez; pasife alabilirsiniz.'),
        ),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link silinsin mi?'),
        content: Text('"${item.title}" kalıcı silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await deleteMoreMenuItem(item.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: MetoColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Daha Fazlası — Menü Yönetimi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Yenile',
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                ),
                FilledButton.icon(
                  onPressed: () => _edit(null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni Link'),
                  style: FilledButton.styleFrom(
                    backgroundColor: MetoColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: MetoColors.card,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => SizedBox(
                    height: MediaQuery.sizeOf(ctx).height * 0.9,
                    child: const AdminGelisimEtkinlikSheet(),
                  ),
                );
              },
              icon: const Icon(Icons.ondemand_video_outlined),
              label: const Text('Gelişim — Video & Kaynak'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Duyurulardaki gibi aktif/pasif yapın. Pasif öğeler kullanıcıda görünmez.',
              style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = _items[i];
                    final busy = _busyId == item.id;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${item.isUrl ? item.link : 'Uygulama: ${item.link}'}'
                        '${item.isBuiltin ? ' · yerleşik' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: item.isActive
                                  ? const Color(0xFFE8F5EE)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.isActive ? 'Aktif' : 'Pasif',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: item.isActive
                                    ? MetoColors.primary
                                    : const Color(0xFFDC2626),
                              ),
                            ),
                          ),
                          if (busy)
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else ...[
                            IconButton(
                              tooltip: item.isActive ? 'Pasif et' : 'Aktif et',
                              onPressed: () => _toggle(item),
                              icon: Icon(
                                item.isActive
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: item.isActive
                                    ? MetoColors.muted
                                    : MetoColors.primary,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Düzenle',
                              onPressed: () => _edit(item),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            if (!item.isBuiltin)
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
                    );
                  },
                ),
              ),
          ],
        ),
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
    final lockRoute = widget.item?.isBuiltin == true;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isNew ? 'Yeni link ekle' : 'Menü öğesini düzenle',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
            if (!lockRoute)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'url', label: Text('Web linki')),
                  ButtonSegment(value: 'route', label: Text('Uygulama')),
                ],
                selected: {_linkType},
                onSelectionChanged: (s) => setState(() => _linkType = s.first),
              ),
            if (!lockRoute) const SizedBox(height: 10),
            TextField(
              controller: _link,
              enabled: !lockRoute || _linkType == 'url',
              decoration: InputDecoration(
                labelText: _linkType == 'url'
                    ? 'Link (https://… veya /bilgi-kutuphanesi/…)'
                    : 'Route (aile_kocu, haklar, kartlar, mchat, cvi, gelisim)',
                border: const OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Aktif',
                style: TextStyle(fontWeight: FontWeight.w700),
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
