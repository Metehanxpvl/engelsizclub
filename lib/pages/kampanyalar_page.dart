import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_config.dart';
import '../data/turkish_cities_data.dart';
import '../gezi_kampanya_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../widgets/gezi_kampanya_admin_sheet.dart';
import '../widgets/gezi_kampanya_feed_card.dart';

enum _KampanyaFilter { all, nationwide, city }

/// Kampanyalar — story benzeri dikey liste (görsel + açıklama).
/// Filtre: Tümü | Tüm ülkede geçerli | il ara (Gezi ile aynı 81 il).
class KampanyalarPage extends StatefulWidget {
  const KampanyalarPage({
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
        builder: (_) => KampanyalarPage(userEmail: userEmail),
      ),
    );
  }

  @override
  State<KampanyalarPage> createState() => _KampanyalarPageState();
}

class _KampanyalarPageState extends State<KampanyalarPage> {
  final _search = TextEditingController();
  List<KampanyaItem> _items = const [];
  bool _loading = true;
  _KampanyaFilter _filter = _KampanyaFilter.all;
  String? _city;

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  @override
  void initState() {
    super.initState();
    final cached = cachedKampanyaItems;
    if (cached != null) {
      _items = List<KampanyaItem>.from(cached);
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
    final list = await loadKampanyaItems(
      forceRefresh: !hasFreshKampanyaCache,
      viewerEmail: widget.userEmail,
    );
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  List<KampanyaItem> get _activeBase {
    final list = (_isAdmin ? _items : _items.where((k) => k.isActive)).toList();
    list.sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Map<String, int> get _cityCounts {
    final map = <String, int>{};
    for (final k in _activeBase) {
      if (k.isNationwide) continue;
      final key = foldTurkish(k.city);
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

  List<KampanyaItem> get _visible {
    final list = _activeBase;
    switch (_filter) {
      case _KampanyaFilter.all:
        return list;
      case _KampanyaFilter.nationwide:
        return list.where((k) => k.isNationwide).toList();
      case _KampanyaFilter.city:
        final city = _city;
        if (city == null) return const [];
        final folded = foldTurkish(city);
        return list
            .where((k) => !k.isNationwide && foldTurkish(k.city) == folded)
            .toList();
    }
  }

  void _selectAll() {
    setState(() {
      _filter = _KampanyaFilter.all;
      _city = null;
      _search.clear();
    });
  }

  void _selectNationwide() {
    setState(() {
      _filter = _KampanyaFilter.nationwide;
      _city = null;
      _search.clear();
    });
  }

  void _selectCity(String city) {
    setState(() {
      _filter = _KampanyaFilter.city;
      _city = city;
      _search.text = city;
    });
  }

  void _clearCity() {
    setState(() {
      _filter = _KampanyaFilter.all;
      _city = null;
      _search.clear();
    });
  }

  Future<void> _openAdd({String? city}) async {
    final preset = city ?? _city;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GeziKampanyaAdminSheet(
        adminEmail: widget.userEmail,
        kind: GeziKampanyaKind.kampanya,
        presetCity: preset,
      ),
    );
    if (ok == true && mounted) await _reload();
  }

  Future<void> _openEdit(KampanyaItem item) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GeziKampanyaAdminSheet(
        adminEmail: widget.userEmail,
        kind: GeziKampanyaKind.kampanya,
        presetCity: item.isNationwide ? null : item.city,
        editKampanya: item,
      ),
    );
    if (ok == true && mounted) await _reload();
  }

  Future<void> _delete(KampanyaItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Kampanyayı sil?'),
        content: const L10nText('Bu kampanya kalıcı olarak silinecek.'),
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
      await deleteKampanyaItem(item.id);
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
    switch (_filter) {
      case _KampanyaFilter.nationwide:
        return 'Tüm ülkede geçerli kampanya yok.';
      case _KampanyaFilter.city:
        return _city == null
            ? 'İl seçin.'
            : 'Bu il için henüz kampanya yok.';
      case _KampanyaFilter.all:
        return 'Henüz kampanya yok.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visible;
    final pickingCity = _showCityPicker;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: L10nText(
          'Kampanyalar',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: S.auto('Kampanya ekle'),
              onPressed: () => _openAdd(),
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
                  selected: _filter == _KampanyaFilter.all,
                  onTap: _selectAll,
                ),
                _chip(
                  label: 'Tüm ülkede geçerli',
                  selected: _filter == _KampanyaFilter.nationwide,
                  onTap: _selectNationwide,
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
                  _filter = foldTurkish(v).isEmpty
                      ? _KampanyaFilter.all
                      : _KampanyaFilter.city;
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
                                  title: item.title,
                                  description: item.description,
                                  locationLabel: item.locationLabel,
                                  isAdmin: _isAdmin,
                                  onDelete:
                                      _isAdmin ? () => _delete(item) : null,
                                  onEdit:
                                      _isAdmin ? () => _openEdit(item) : null,
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
                label: const L10nText('Kampanya ekle'),
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
