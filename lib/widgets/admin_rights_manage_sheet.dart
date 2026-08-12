import 'package:flutter/material.dart';

import '../data/rights_data.dart';
import '../meto_theme.dart';
import '../rights_catalog_store.dart';
import '../services/catalog_adapters.dart';
import 'admin_right_edit_sheet.dart';

/// Admin: hak içerikleri + kategoriler yönetimi.
class AdminRightsManageSheet extends StatefulWidget {
  const AdminRightsManageSheet({super.key});

  @override
  State<AdminRightsManageSheet> createState() => _AdminRightsManageSheetState();
}

class _AdminRightsManageSheetState extends State<AdminRightsManageSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<Map<String, dynamic>> _rights = const [];
  List<Map<String, dynamic>> _categories = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rights = await loadRightsForAdmin();
      final cats = await loadRightsCategoriesForAdmin();
      if (!mounted) return;
      setState(() {
        _rights = rights;
        _categories = cats;
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

  RightItem _fromRow(Map<String, dynamic> r) {
    return CatalogAdapters.rightsItems().firstWhere(
      (e) => e.id == (r['id']?.toString() ?? ''),
      orElse: () => RightItem(
        id: r['id']?.toString() ?? '',
        title: r['title']?.toString() ?? '',
        amount: r['amount']?.toString() ?? '',
        category: r['category']?.toString() ?? 'maddi',
        icon: r['icon']?.toString() ?? '📋',
        color: Color((r['color'] as num?)?.toInt() ?? 0xFF1A6B4A),
        bg: Color((r['bg'] as num?)?.toInt() ?? 0xFFE8F5EE),
        minRate: (r['min_rate'] as num?)?.toInt() ?? 0,
        maxAge: (r['max_age'] as num?)?.toInt() ?? 99,
        incomeLimit: r['income_limit'] == true,
        desc: r['description']?.toString() ?? '',
        steps: [
          if (r['steps'] is List)
            for (final s in (r['steps'] as List))
              if ('$s'.trim().isNotEmpty) '$s'.trim(),
        ],
        where: r['where_text']?.toString() ?? '',
      ),
    );
  }

  Future<void> _editRight(Map<String, dynamic>? row, {bool isNew = false}) async {
    final item = isNew || row == null
        ? emptyRightItem()
        : _fromRow(row);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AdminRightEditSheet(item: item, isNew: isNew),
    );
    if (ok == true) await _reload();
  }

  Future<void> _toggleRight(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final active = row['active'] != false;
    try {
      if (active) {
        await deleteAppRight(id);
      } else {
        final item = _fromRow(row);
        await upsertAppRight(item, active: true);
      }
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _deleteRight(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    final title = row['title']?.toString() ?? id;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: Text('"$title" kalıcı olarak silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await deleteAppRight(id, hard: true);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _editCategory(Map<String, dynamic>? row) async {
    final isNew = row == null;
    final idCtrl = TextEditingController(text: row?['id']?.toString() ?? '');
    final labelCtrl =
        TextEditingController(text: row?['label']?.toString() ?? '');
    final iconCtrl =
        TextEditingController(text: row?['icon']?.toString() ?? '📁');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isNew ? 'Yeni kategori' : 'Kategori düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isNew)
              TextField(
                controller: idCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kimlik (örn. egitim)',
                  hintText: 'küçük harf, tire',
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Kimlik: ${row['id']}'),
              ),
            TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            TextField(
              controller: iconCtrl,
              decoration: const InputDecoration(labelText: 'İkon (emoji)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final id = isNew
          ? rightsSlugFromTitle(idCtrl.text.trim().isEmpty
              ? labelCtrl.text
              : idCtrl.text)
          : (row['id']?.toString() ?? '');
      await upsertRightsCategory(
        id: id,
        label: labelCtrl.text,
        icon: iconCtrl.text,
        active: row?['active'] != false,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id == 'tümü') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('"Tümü" silinemez.')),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategori silinsin mi?'),
        content: Text('"${row['label']}" silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await deleteRightsCategory(id, hard: true);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.98,
      builder: (context, scroll) {
        return Material(
          color: MetoColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MetoColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Haklar yönetimi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Yenile',
                      onPressed: _loading ? null : _reload,
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabs,
                labelColor: MetoColors.primary,
                unselectedLabelColor: MetoColors.mutedFg,
                indicatorColor: MetoColors.primary,
                tabs: const [
                  Tab(text: 'İçerikler'),
                  Tab(text: 'Kategoriler'),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _rightsTab(scroll),
                          _categoriesTab(scroll),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rightsTab(ScrollController scroll) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: FilledButton.icon(
            onPressed: () => _editRight(null, isNew: true),
            icon: const Icon(Icons.add),
            label: const Text('Yeni hak ekle'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: MetoColors.primary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _rights.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final r = _rights[i];
              final active = r['active'] != false;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: MetoColors.border),
                ),
                tileColor: MetoColors.card,
                leading: Text(
                  r['icon']?.toString() ?? '📋',
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(
                  r['title']?.toString() ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: active ? null : MetoColors.mutedFg,
                    decoration: active ? null : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(
                  '${r['category'] ?? ''} · ${r['amount'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        _editRight(r);
                      case 'toggle':
                        _toggleRight(r);
                      case 'delete':
                        _deleteRight(r);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(active ? 'Pasifleştir' : 'Aktifleştir'),
                    ),
                    const PopupMenuItem(value: 'delete', child: Text('Sil')),
                  ],
                ),
                onTap: () => _editRight(r),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoriesTab(ScrollController scroll) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: FilledButton.icon(
            onPressed: () => _editCategory(null),
            icon: const Icon(Icons.add),
            label: const Text('Yeni kategori'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: MetoColors.primary,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            itemCount: _categories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = _categories[i];
              final id = c['id']?.toString() ?? '';
              final active = c['active'] != false;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: MetoColors.border),
                ),
                tileColor: MetoColors.card,
                leading: Text(
                  c['icon']?.toString() ?? '📁',
                  style: const TextStyle(fontSize: 22),
                ),
                title: Text(
                  c['label']?.toString() ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: active ? null : TextDecoration.lineThrough,
                  ),
                ),
                subtitle: Text(id),
                trailing: id == 'tümü'
                    ? const Chip(label: Text('Sistem'))
                    : PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _editCategory(c);
                          if (v == 'delete') _deleteCategory(c);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                          PopupMenuItem(value: 'delete', child: Text('Sil')),
                        ],
                      ),
                onTap: id == 'tümü' ? null : () => _editCategory(c),
              );
            },
          ),
        ),
      ],
    );
  }
}
