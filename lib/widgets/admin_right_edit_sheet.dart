import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/rights_data.dart';
import '../meto_theme.dart';
import '../rights_catalog_store.dart';
import '../services/catalog_adapters.dart';

/// Admin: hak kartı ekle / düzenle (sihirbaz alanları dahil).
class AdminRightEditSheet extends StatefulWidget {
  const AdminRightEditSheet({
    super.key,
    required this.item,
    this.isNew = false,
  });

  final RightItem item;
  final bool isNew;

  @override
  State<AdminRightEditSheet> createState() => _AdminRightEditSheetState();
}

class _AdminRightEditSheetState extends State<AdminRightEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _amount;
  late final TextEditingController _icon;
  late final TextEditingController _desc;
  late final TextEditingController _steps;
  late final TextEditingController _where;
  late final TextEditingController _minRate;
  late final TextEditingController _maxAge;
  late String _category;
  late bool _incomeLimit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.item;
    _title = TextEditingController(text: r.title);
    _amount = TextEditingController(text: r.amount);
    _icon = TextEditingController(text: r.icon);
    _desc = TextEditingController(text: r.desc);
    _steps = TextEditingController(text: r.steps.join('\n'));
    _where = TextEditingController(text: r.where);
    _minRate = TextEditingController(text: '${r.minRate}');
    _maxAge = TextEditingController(text: '${r.maxAge}');
    _category = r.category.isEmpty ? 'maddi' : r.category;
    _incomeLimit = r.incomeLimit;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _icon.dispose();
    _desc.dispose();
    _steps.dispose();
    _where.dispose();
    _minRate.dispose();
    _maxAge.dispose();
    super.dispose();
  }

  List<String> _lines(String raw) => raw
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<({String id, String label})> get _categoryOptions {
    final cats = CatalogAdapters.rightsCategories()
        .where((c) => c.id != 'tümü')
        .toList();
    if (cats.isEmpty) {
      return [
        for (final c in rightsCategories.where((e) => e.id != 'tümü'))
          (id: c.id, label: '${c.icon} ${c.label}'),
      ];
    }
    final ids = {for (final c in cats) c.id};
    if (!ids.contains(_category)) {
      cats.add(RightsCategory(id: _category, label: _category, icon: '📁'));
    }
    return [
      for (final c in cats) (id: c.id, label: '${c.icon} ${c.label}'),
    ];
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
      final id = widget.isNew || widget.item.id.isEmpty
          ? rightsSlugFromTitle(title)
          : widget.item.id;
      final updated = RightItem(
        id: id,
        title: title,
        amount: _amount.text.trim(),
        category: _category,
        icon: _icon.text.trim().isEmpty ? '📋' : _icon.text.trim(),
        color: widget.item.color,
        bg: widget.item.bg,
        minRate: int.tryParse(_minRate.text.trim()) ?? 0,
        maxAge: int.tryParse(_maxAge.text.trim()) ?? 99,
        incomeLimit: _incomeLimit,
        desc: _desc.text.trim(),
        steps: _lines(_steps.text),
        where: _where.text.trim(),
      );
      await upsertAppRight(updated);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
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
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.isNew ? 'Yeni hak ekle' : 'Hakkı düzenle',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      _field(_title, 'Başlık'),
                      _field(_amount, 'Özet / tutar (ör. Aylık 12 saat)'),
                      _field(_icon, 'İkon (emoji)'),
                      const SizedBox(height: 8),
                      const Text(
                        'Kategori',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownMenu<String>(
                        initialSelection: _categoryOptions.any((e) => e.id == _category)
                            ? _category
                            : _categoryOptions.first.id,
                        dropdownMenuEntries: [
                          for (final c in _categoryOptions)
                            DropdownMenuEntry(value: c.id, label: c.label),
                        ],
                        onSelected: (v) {
                          if (v != null) setState(() => _category = v);
                        },
                        expandedInsets: EdgeInsets.zero,
                        inputDecorationTheme: InputDecorationTheme(
                          filled: true,
                          fillColor: MetoColors.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _field(
                        _desc,
                        'Açıklama',
                        maxLines: 4,
                      ),
                      _field(
                        _steps,
                        'Başvuru adımları (her satır bir adım)',
                        maxLines: 6,
                      ),
                      _field(_where, 'Nereye başvurulur'),
                      const SizedBox(height: 8),
                      const Text(
                        'Sihirbaz filtreleri',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              _minRate,
                              'Min. engel %',
                              keyboard: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(
                              _maxAge,
                              'Max. yaş',
                              keyboard: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Gelir şartı var'),
                        subtitle: const Text(
                          'Açıksa sihirbazda gelir sınırı sorusuyla eşleşir',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: _incomeLimit,
                        onChanged: (v) => setState(() => _incomeLimit = v),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: MetoColors.primary,
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
                            : Text(widget.isNew ? 'Ekle' : 'Kaydet'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  InputDecoration _dec([String? hint]) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: MetoColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _field(
    TextEditingController c,
    String label, {
    int maxLines = 1,
    TextInputType? keyboard,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            maxLines: maxLines,
            keyboardType: keyboard,
            inputFormatters: inputFormatters,
            decoration: _dec(),
          ),
        ],
      ),
    );
  }
}
