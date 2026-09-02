import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/turkish_cities_data.dart';
import '../gezi_kampanya_store.dart';
import '../section_editors.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../widgets/gezi_kampanya_admin_sheet.dart';
import '../widgets/gezi_kampanya_feed_card.dart';

/// Tüm gezi yerleri tek akış; isteğe bağlı 81 il filtresi.
class GeziRehberiPage extends StatefulWidget {
  const GeziRehberiPage({
    super.key,
    required this.userEmail,
  });

  final String userEmail;

  static Future<void> open(
    BuildContext context, {
    required String userEmail,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GeziRehberiPage(userEmail: userEmail),
      ),
    );
  }

  @override
  State<GeziRehberiPage> createState() => _GeziRehberiPageState();
}

class _GeziRehberiPageState extends State<GeziRehberiPage> {
  final _search = TextEditingController();
  List<GeziItem> _all = const [];
  bool _loading = true;
  String? _city;

  bool get _isAdmin => canEditSection(widget.userEmail, SectionKey.gezi);

  @override
  void initState() {
    super.initState();
    final cached = cachedGeziItems;
    if (cached != null) {
      _all = List<GeziItem>.from(cached);
      _loading = false;
    }
    _reload(silent: cached != null);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final list = await loadGeziItems(
      forceRefresh: !hasFreshGeziCache,
      viewerEmail: widget.userEmail,
    );
    if (!mounted) return;
    setState(() {
      _all = list;
      _loading = false;
    });
  }

  List<GeziItem> get _activeBase {
    return (_isAdmin ? _all : _all.where((g) => g.isActive)).toList();
  }

  int _cityItemCompare(GeziItem a, GeziItem b) {
    final i = a.cityOrder.compareTo(b.cityOrder);
    if (i != 0) return i;
    final o = a.sortOrder.compareTo(b.sortOrder);
    if (o != 0) return o;
    final t = a.createdAt.compareTo(b.createdAt);
    if (t != 0) return t;
    return a.id.compareTo(b.id);
  }

  /// İl içi 1, 2, 3… (filtrelenmiş ve Tümü görünümünde aynı numara).
  Map<int, int> get _cityNumbers {
    final byCity = <String, List<GeziItem>>{};
    for (final g in _activeBase) {
      final key = foldTurkish(g.cityName);
      (byCity[key] ??= []).add(g);
    }
    final map = <int, int>{};
    for (final list in byCity.values) {
      list.sort(_cityItemCompare);
      for (var i = 0; i < list.length; i++) {
        map[list[i].id] = i + 1;
      }
    }
    return map;
  }

  Map<String, int> get _cityCounts {
    final map = <String, int>{};
    for (final g in _activeBase) {
      final key = foldTurkish(g.cityName);
      if (key.isEmpty) continue;
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }

  List<String> get _cityOptions {
    final q = foldTurkish(_search.text);
    final list = kCityNames
        .where((c) => q.isEmpty || foldTurkish(c).contains(q))
        .toList()
      ..sort((a, b) => foldTurkish(a).compareTo(foldTurkish(b)));
    return list;
  }

  bool get _showCityPicker {
    if (_city != null) return false;
    return foldTurkish(_search.text).isNotEmpty;
  }

  List<GeziItem> get _visible {
    final city = _city;
    if (city != null) {
      final folded = foldTurkish(city);
      final slug = turkishCitySlug(city);
      final list = _activeBase.where((g) {
        return foldTurkish(g.cityName) == folded || g.citySlug == slug;
      }).toList()
        ..sort(_cityItemCompare);
      return list;
    }
    final list = List<GeziItem>.from(_activeBase)
      ..sort((a, b) {
        final t = b.createdAt.compareTo(a.createdAt);
        if (t != 0) return t;
        return _cityItemCompare(a, b);
      });
    return list;
  }

  void _selectAll() {
    setState(() {
      _city = null;
      _search.clear();
    });
  }

  void _selectCity(String city) {
    setState(() {
      _city = city;
      _search.text = city;
    });
  }

  void _clearCity() {
    setState(() {
      _city = null;
      _search.clear();
    });
  }

  String _cardTitle(GeziItem item) {
    final n = _cityNumbers[item.id] ?? 0;
    final heading = item.title.trim();
    final numbered =
        n > 0 ? (heading.isEmpty ? '$n.' : '$n. $heading') : heading;
    if (_city != null) return numbered;
    final city = item.cityName.trim();
    if (city.isEmpty) return numbered;
    return '$city · $numbered';
  }

  Future<void> _openAdd({String? city}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GeziKampanyaAdminSheet(
        adminEmail: widget.userEmail,
        kind: GeziKampanyaKind.gezi,
        presetCity: city ?? _city,
      ),
    );
    if (ok == true && mounted) await _reload();
  }

  Future<void> _openEdit(GeziItem item) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GeziKampanyaAdminSheet(
        adminEmail: widget.userEmail,
        kind: GeziKampanyaKind.gezi,
        presetCity: item.cityName,
        editGezi: item,
      ),
    );
    if (ok == true && mounted) await _reload();
  }

  Future<void> _move(GeziItem item, int delta) async {
    if (_city == null) return;
    final items = _visible;
    final i = items.indexWhere((g) => g.id == item.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= items.length) return;
    try {
      final next = List<GeziItem>.from(items);
      final tmp = next[i];
      next[i] = next[j];
      next[j] = tmp;
      await persistGeziCityOrder(next);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sıra değiştirilemedi: $e')),
      );
    }
  }

  Future<void> _delete(GeziItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Yeri sil?'),
        content: const L10nText('Bu yer kalıcı olarak silinecek.'),
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
    try {
      await deleteGeziItem(item.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Silinemedi: $e')),
      );
    }
  }

  InputDecoration _searchDecoration() {
    return InputDecoration(
      hintText: S.auto('İl ara (Ankara, İzmir…)'),
      prefixIcon: const Icon(Icons.search, color: MetoColors.mutedFg),
      suffixIcon: (_search.text.isNotEmpty || _city != null)
          ? IconButton(
              tooltip: S.auto('Temizle'),
              onPressed: () {
                if (_city != null) {
                  _clearCity();
                } else {
                  setState(() => _search.clear());
                }
              },
              icon: const Icon(Icons.close, color: MetoColors.mutedFg),
            )
          : null,
      filled: true,
      fillColor: MetoColors.card,
      hintStyle: GoogleFonts.nunito(color: MetoColors.mutedFg),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MetoColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MetoColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MetoColors.primary),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? MetoColors.primary : MetoColors.muted,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: L10nText(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : MetoColors.mutedFg,
            ),
          ),
        ),
      ),
    );
  }

  String get _emptyMessage {
    if (_city == null) return 'Henüz yer yok.';
    return 'Bu il için henüz yer yok.';
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    final pickingCity = _showCityPicker;
    final filtered = _city != null;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: L10nText(
          'Gezi Rehberi',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: S.auto('Yer ekle'),
              onPressed: () => _openAdd(city: _city),
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  label: 'Tümü',
                  selected: !filtered,
                  onTap: _selectAll,
                ),
                if (_city != null)
                  Material(
                    color: MetoColors.primary,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 5, 4, 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _city!,
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            tooltip: S.auto('Temizle'),
                            onPressed: _clearCity,
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() {
                if (_city != null && foldTurkish(v) != foldTurkish(_city!)) {
                  _city = null;
                }
              }),
              style: GoogleFonts.nunito(),
              decoration: _searchDecoration(),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: MetoColors.primary,
            ),
          Expanded(
            child: pickingCity
                ? _buildCityList()
                : _loading && items.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: MetoColors.primary,
                        ),
                      )
                    : items.isEmpty
                        ? _buildEmpty()
                        : RefreshIndicator(
                            color: MetoColors.primary,
                            onRefresh: () => _reload(),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) {
                                final item = items[i];
                                return GeziKampanyaFeedCard(
                                  imageUrl: item.imageUrl,
                                  title: _cardTitle(item),
                                  description: item.description,
                                  isAdmin: _isAdmin,
                                  onDelete:
                                      _isAdmin ? () => _delete(item) : null,
                                  onEdit:
                                      _isAdmin ? () => _openEdit(item) : null,
                                  onMoveUp: _isAdmin && filtered && i > 0
                                      ? () => _move(item, -1)
                                      : null,
                                  onMoveDown: _isAdmin &&
                                          filtered &&
                                          i < items.length - 1
                                      ? () => _move(item, 1)
                                      : null,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            L10nText(
              _emptyMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w700,
                color: MetoColors.mutedFg,
              ),
            ),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openAdd(city: _city),
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                ),
                icon: const Icon(Icons.add),
                label: const L10nText('Yer ekle'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCityList() {
    final cities = _cityOptions;
    final counts = _cityCounts;
    if (cities.isEmpty) {
      return Center(
        child: L10nText(
          'İl bulunamadı.',
          style: GoogleFonts.nunito(color: MetoColors.mutedFg),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: cities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final city = cities[i];
        final n = counts[foldTurkish(city)] ?? 0;
        return Material(
          color: MetoColors.card,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _selectCity(city),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MetoColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: MetoColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.location_city_outlined,
                      size: 18,
                      color: MetoColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      city,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: MetoColors.foreground,
                      ),
                    ),
                  ),
                  if (n > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: MetoColors.selectedBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$n',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: MetoColors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
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
    );
  }
}
