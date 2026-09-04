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
  bool _savingOrder = false;
  String? _error;
  int? _busyId;

  List<MoreMenuTreeNode> get _tree => flattenMoreMenuTree(_items);

  List<MoreMenuItem> get _folders =>
      _items.where((e) => e.isFolder).toList()..sort(compareMoreMenuOrder);

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

  void _sqlNeeded({bool nest = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nest
              ? 'Önce Supabase’de daha_fazlasi_menu_nest.sql çalıştırın.'
              : 'Önce Supabase’de daha_fazlasi_menu.sql çalıştırın.',
        ),
      ),
    );
  }

  Future<void> _edit(MoreMenuItem? existing) async {
    if (existing != null && existing.id <= 0) {
      _sqlNeeded();
      return;
    }
    var maxSort = 0;
    for (final e in _items) {
      if (e.sortOrder > maxSort) maxSort = e.sortOrder;
    }
    final result = await showModalBottomSheet<MoreMenuItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MoreMenuEditSheet(
        item: existing,
        nextSort: maxSort + 10,
        folders: _folders,
        allItems: _items,
      ),
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

  Future<void> _createGroup() async {
    final created = await showDialog<MoreMenuItem>(
      context: context,
      builder: (ctx) => const _CreateGroupDialog(),
    );
    if (created == null) return;
    var maxSort = 0;
    for (final e in _items) {
      if (e.sortOrder > maxSort) maxSort = e.sortOrder;
    }
    try {
      await createMoreMenuGroup(
        title: created.title,
        subtitle: created.subtitle,
        icon: created.icon,
        sortOrder: maxSort + 10,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Grup eklenemedi: $e')),
      );
    }
  }

  List<MoreMenuItem> _siblingsOf(MoreMenuItem item) {
    return _items.where((e) => e.parentId == item.parentId).toList()
      ..sort(compareMoreMenuOrder);
  }

  Future<void> _moveSibling(MoreMenuItem item, int delta) async {
    if (_savingOrder) return;
    final siblings = _siblingsOf(item);
    final from = siblings.indexWhere((e) => e.id == item.id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= siblings.length) return;
    final next = List<MoreMenuItem>.from(siblings);
    final moved = next.removeAt(from);
    next.insert(to, moved);
    setState(() {
      final others = _items.where((e) => e.parentId != item.parentId);
      _items = [...others, ...next];
    });
    await _persistOrder(next);
  }

  Future<void> _persistOrder(List<MoreMenuItem> siblings) async {
    if (siblings.any((e) => e.id <= 0)) {
      _sqlNeeded();
      return;
    }
    setState(() => _savingOrder = true);
    try {
      await reorderMoreMenuItems(siblings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sıra kaydedildi.'),
          duration: Duration(seconds: 1),
        ),
      );
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

  Future<void> _moveToGroup(MoreMenuItem item, int? parentId) async {
    if (item.id <= 0) {
      _sqlNeeded(nest: true);
      return;
    }
    if (item.parentId == parentId) return;
    if (wouldCreateMoreMenuCycle(_items, item.id, parentId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bir grubu kendi içine taşıyamazsınız.')),
      );
      return;
    }
    setState(() => _busyId = item.id);
    try {
      final siblings = _items.where((e) => e.parentId == parentId).toList();
      await moveMoreMenuItem(
        id: item.id,
        parentId: parentId,
        siblingsHint: siblings,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(MoreMenuItem item) async {
    if (item.id <= 0) {
      _sqlNeeded();
      return;
    }
    final kids = moreMenuChildren(_items, item.id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          item.isFolder ? 'Grup silinsin mi?' : 'Uygulama silinsin mi?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text(
          kids.isEmpty
              ? '"${item.title}" Daha Fazlası menüsünden kaldırılacak.'
              : '"${item.title}" silinince içindeki ${kids.length} öğe üst seviyeye çıkar.',
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
      case 'place':
        icon = Icons.place_outlined;
      case 'extension':
        icon = Icons.extension_outlined;
      case 'barcode':
        icon = Icons.qr_code_scanner;
      case 'apps':
      case 'folder':
        icon = Icons.folder_outlined;
      case 'games':
        icon = Icons.extension_outlined;
      case 'palette':
      case '🎨':
        return CircleAvatar(
          radius: 24,
          backgroundColor: MetoColors.primary.withValues(alpha: 0.12),
          child: const Text('🎨', style: TextStyle(fontSize: 22)),
        );
      default:
        if (item.link == 'boyama') {
          return CircleAvatar(
            radius: 24,
            backgroundColor: MetoColors.primary.withValues(alpha: 0.12),
            child: const Text('🎨', style: TextStyle(fontSize: 22)),
          );
        }
        icon = item.isFolder ? Icons.folder_outlined : Icons.link;
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: MetoColors.primary.withValues(alpha: 0.12),
      child: Icon(icon, color: MetoColors.primary),
    );
  }

  List<DropdownMenuItem<int?>> _parentItemsFor(MoreMenuItem item) {
    final out = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Üst seviye'),
      ),
    ];
    for (final f in _folders) {
      if (f.id == item.id) continue;
      if (wouldCreateMoreMenuCycle(_items, item.id, f.id)) continue;
      out.add(
        DropdownMenuItem<int?>(
          value: f.id,
          child: Text(f.title, overflow: TextOverflow.ellipsis),
        ),
      );
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.78;
    final tree = _tree;
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
            padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
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
                  onPressed: _createGroup,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('Grup'),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sıra: oklar (aynı grup içinde). Taşı: açılır listeden grup seçin.',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                ),
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
              child: tree.isEmpty
                  ? Center(
                      child: Text(
                        'Henüz uygulama yok. + Ekle veya Grup ile ekleyin.',
                        style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: tree.length,
                      itemBuilder: (context, i) {
                        final node = tree[i];
                        final item = node.item;
                        final siblings = _siblingsOf(item);
                        final sibIndex =
                            siblings.indexWhere((e) => e.id == item.id);
                        final busy = _busyId == item.id || _savingOrder;
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            4.0 + node.depth * 18,
                            0,
                            0,
                            8,
                          ),
                          child: Material(
                            color: MetoColors.background,
                            borderRadius: BorderRadius.circular(14),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      _leading(item),
                                      const SizedBox(width: 8),
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
                                                item.isFolder
                                                    ? 'Grup'
                                                    : item.isUrl
                                                        ? 'Link'
                                                        : 'Uygulama',
                                                item.isActive
                                                    ? 'Aktif'
                                                    : 'Pasif',
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
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              tooltip: 'Yukarı',
                                              onPressed: sibIndex <= 0
                                                  ? null
                                                  : () =>
                                                      _moveSibling(item, -1),
                                              icon: const Icon(
                                                Icons.keyboard_arrow_up,
                                                size: 22,
                                              ),
                                            ),
                                            IconButton(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              tooltip: 'Aşağı',
                                              onPressed: sibIndex < 0 ||
                                                      sibIndex >=
                                                          siblings.length - 1
                                                  ? null
                                                  : () =>
                                                      _moveSibling(item, 1),
                                              icon: const Icon(
                                                Icons.keyboard_arrow_down,
                                                size: 22,
                                              ),
                                            ),
                                          ],
                                        ),
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
                                  if (!busy)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          left: 4,
                                          top: 2,
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<int?>(
                                            isDense: true,
                                            value: _folders.any(
                                              (f) => f.id == item.parentId,
                                            )
                                                ? item.parentId
                                                : null,
                                            hint: Text(
                                              'Üst seviye',
                                              style: GoogleFonts.nunito(
                                                fontSize: 12,
                                              ),
                                            ),
                                            items: _parentItemsFor(item),
                                            onChanged: (v) =>
                                                _moveToGroup(item, v),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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

class _CreateGroupDialog extends StatefulWidget {
  const _CreateGroupDialog();

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _title = TextEditingController();
  final _subtitle = TextEditingController();
  final _icon = TextEditingController(text: 'folder');

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _icon.dispose();
    super.dispose();
  }

  void _ok() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Grup adı gerekli.')),
      );
      return;
    }
    Navigator.pop(
      context,
      MoreMenuItem(
        id: 0,
        title: title,
        subtitle: _subtitle.text.trim(),
        linkType: 'folder',
        link: 'folder',
        icon: _icon.text.trim().isEmpty ? 'folder' : _icon.text.trim(),
        sortOrder: 80,
        isActive: true,
        isBuiltin: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Yeni grup',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Grup adı',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _subtitle,
            decoration: const InputDecoration(
              labelText: 'Alt yazı (isteğe bağlı)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _icon,
            decoration: const InputDecoration(
              labelText: 'İkon (folder, apps, 🎨 …)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _ok,
          style: FilledButton.styleFrom(backgroundColor: MetoColors.primary),
          child: const Text('Oluştur'),
        ),
      ],
    );
  }
}

class _MoreMenuEditSheet extends StatefulWidget {
  const _MoreMenuEditSheet({
    this.item,
    required this.nextSort,
    required this.folders,
    required this.allItems,
  });

  final MoreMenuItem? item;
  final int nextSort;
  final List<MoreMenuItem> folders;
  final List<MoreMenuItem> allItems;

  @override
  State<_MoreMenuEditSheet> createState() => _MoreMenuEditSheetState();
}

class _MoreMenuEditSheetState extends State<_MoreMenuEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _link;
  late final TextEditingController _icon;
  late String _linkType;
  late bool _isActive;
  late int _sortOrder;
  int? _parentId;

  @override
  void initState() {
    super.initState();
    final e = widget.item;
    _title = TextEditingController(text: e?.title ?? '');
    _subtitle = TextEditingController(text: e?.subtitle ?? '');
    _link = TextEditingController(text: e?.link ?? '');
    _icon = TextEditingController(text: e?.icon ?? 'link');
    _linkType = e?.linkType ?? 'url';
    _isActive = e?.isActive ?? true;
    _sortOrder = e?.sortOrder ?? widget.nextSort;
    _parentId = e?.parentId;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _link.dispose();
    _icon.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final isFolder = _linkType == 'folder' || widget.item?.isFolder == true;
    var link = _link.text.trim();
    if (isFolder) {
      if (title.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İsim gerekli.')),
        );
        return;
      }
      link = link.isEmpty ? 'folder' : link;
    } else if (title.isEmpty || link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İsim ve link gerekli.')),
      );
      return;
    }
    var linkType = isFolder ? 'folder' : _linkType;
    if (!isFolder &&
        (link.startsWith('http://') ||
            link.startsWith('https://') ||
            link.startsWith('/'))) {
      linkType = 'url';
    }
    final base = widget.item;
    Navigator.pop(
      context,
      MoreMenuItem(
        id: base?.id ?? 0,
        title: title,
        subtitle: _subtitle.text.trim(),
        linkType: linkType,
        link: link,
        icon: _icon.text.trim().isEmpty
            ? (isFolder ? 'folder' : 'link')
            : _icon.text.trim(),
        sortOrder: _sortOrder,
        isActive: _isActive,
        isBuiltin: base?.isBuiltin ?? false,
        parentId: _parentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final isNew = widget.item == null;
    final isFolder = _linkType == 'folder' || widget.item?.isFolder == true;
    final parentItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Üst seviye'),
      ),
      for (final f in widget.folders)
        if (widget.item == null ||
            (f.id != widget.item!.id &&
                !wouldCreateMoreMenuCycle(
                  widget.allItems,
                  widget.item!.id,
                  f.id,
                )))
          DropdownMenuItem<int?>(
            value: f.id,
            child: Text(f.title, overflow: TextOverflow.ellipsis),
          ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + inset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isNew
                  ? 'Yeni uygulama / link'
                  : isFolder
                      ? 'Grubu düzenle'
                      : 'Düzenle',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Web linkini yapıştırıp kaydet. Play Store ve iOS uygulamasında Daha Fazlası’nda görünür; dokununca uygulama içinde açılır.',
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                height: 1.4,
                color: MetoColors.mutedFg,
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
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Grup',
                border: OutlineInputBorder(),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: widget.folders.any((f) => f.id == _parentId)
                      ? _parentId
                      : null,
                  items: parentItems,
                  onChanged: (v) => setState(() => _parentId = v),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _icon,
              decoration: const InputDecoration(
                labelText: 'İkon (folder, apps, 🎨, family …)',
                border: OutlineInputBorder(),
              ),
            ),
            if (!isFolder) ...[
              const SizedBox(height: 10),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'url', label: Text('Web linki')),
                  ButtonSegment(value: 'route', label: Text('Uygulama')),
                ],
                selected: {_linkType == 'folder' ? 'route' : _linkType},
                onSelectionChanged: (s) => setState(() => _linkType = s.first),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _link,
                decoration: InputDecoration(
                  labelText: _linkType == 'url'
                      ? 'Link (https://… veya /bilgi-kutuphanesi/…)'
                      : 'Route (harita, taramalar, aile_kocu, haklar, kartlar, mchat, cvi, cvi2, gelisim, barkod, puzzle, boyama)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
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
