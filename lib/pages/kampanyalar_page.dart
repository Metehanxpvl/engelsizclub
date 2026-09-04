import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/turkish_cities_data.dart';
import '../gezi_kampanya_store.dart';
import '../section_editors.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../data/avm_cover_lookup.dart';
import '../widgets/etkinlik_oneri_sheet.dart';
import '../widgets/etkinlik_pending_sheet.dart';
import '../widgets/gezi_kampanya_admin_sheet.dart';
import '../widgets/gezi_kampanya_feed_card.dart';
import '../widgets/guest_gate.dart';

enum _KampanyaFilter { all, nationwide, city }

enum CityFeedKind { kampanya, etkinlik }

/// Kampanyalar / Etkinlikler — story benzeri dikey liste (görsel + açıklama).
/// Kampanyalar: Tümü | Tüm ülkede geçerli | il ara (81 il).
/// Etkinlikler: Tümü (boş il → «Tüm ülke» üstte, sonra il başlıkları) | il ara.
class KampanyalarPage extends StatefulWidget {
  const KampanyalarPage({
    super.key,
    required this.userEmail,
    this.kind = CityFeedKind.kampanya,
    this.isGuest = false,
    this.openPending = false,
    this.onRequireLogin,
  });

  final String userEmail;
  final CityFeedKind kind;
  final bool isGuest;
  final bool openPending;
  final VoidCallback? onRequireLogin;

  static Future<void> open(
    BuildContext context, {
    required String userEmail,
    CityFeedKind kind = CityFeedKind.kampanya,
    bool isGuest = false,
    bool openPending = false,
    VoidCallback? onRequireLogin,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => KampanyalarPage(
          userEmail: userEmail,
          kind: kind,
          isGuest: isGuest,
          openPending: openPending,
          onRequireLogin: onRequireLogin,
        ),
      ),
    );
  }

  @override
  State<KampanyalarPage> createState() => _KampanyalarPageState();
}

class _KampanyalarPageState extends State<KampanyalarPage> {
  final _search = TextEditingController();
  List<KampanyaItem> _items = const [];
  AvmCoverIndex _avmCovers = AvmCoverIndex.empty;
  bool _loading = true;
  _KampanyaFilter _filter = _KampanyaFilter.all;
  String? _city;
  int? _joinBusyId;

  bool get _isAdmin => canEditSection(
        widget.userEmail,
        _isEtkinlik ? SectionKey.etkinlik : SectionKey.kampanya,
      );
  bool get _isEtkinlik => widget.kind == CityFeedKind.etkinlik;
  GeziKampanyaKind get _adminKind => _isEtkinlik
      ? GeziKampanyaKind.etkinlik
      : GeziKampanyaKind.kampanya;

  String get _pageTitle => _isEtkinlik ? 'Etkinlikler' : 'Kampanyalar';
  String get _addLabel => _isEtkinlik ? 'Etkinlik ekle' : 'Kampanya ekle';
  bool get _isGuest =>
      widget.isGuest || widget.userEmail.trim().isEmpty;

  Future<bool> _requireMember(String message) {
    return ensureMemberAccess(
      context,
      isGuest: _isGuest,
      onRequireLogin: widget.onRequireLogin ?? () {},
      message: message,
    );
  }

  @override
  void initState() {
    super.initState();
    final cached =
        _isEtkinlik ? cachedEtkinlikItems : cachedKampanyaItems;
    if (cached != null) {
      _items = List<KampanyaItem>.from(cached);
      _loading = false;
    }
    _reload(silent: cached != null).then((_) {
      if (!mounted || !widget.openPending || !_isAdmin) return;
      _openPending();
    });
    if (_isEtkinlik) {
      _loadAvmCovers();
    }
  }

  Future<void> _loadAvmCovers() async {
    final idx = await AvmCoverIndex.load();
    if (!mounted) return;
    setState(() => _avmCovers = idx);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final list = _isEtkinlik
          ? await loadEtkinlikItems(
              forceRefresh: !hasFreshEtkinlikCache,
              viewerEmail: widget.userEmail,
            )
          : await loadKampanyaItems(
              forceRefresh: !hasFreshKampanyaCache,
              viewerEmail: widget.userEmail,
            );
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<KampanyaItem> get _activeBase {
    final list = _items.where((k) {
      if (_isEtkinlik) {
        if (isEtkinlikPending(k) || isEtkinlikRejected(k)) return false;
        if (_isAdmin) return true;
        return isEtkinlikListed(k);
      }
      return _isAdmin ? true : k.isActive;
    }).toList();
    list.sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  List<KampanyaItem> get _moderationItems {
    if (!_isEtkinlik) return const [];
    return _items.where((k) => isEtkinlikPending(k) || isEtkinlikRejected(k)).toList();
  }

  int get _pendingCount =>
      _items.where(isEtkinlikPending).length;

  List<KampanyaItem> get _myPending {
    if (!_isEtkinlik || _isGuest) return const [];
    final email = widget.userEmail.trim().toLowerCase();
    if (email.isEmpty) return const [];
    return _items
        .where(
          (k) =>
              isEtkinlikPending(k) &&
              k.createdBy.trim().toLowerCase() == email,
        )
        .toList();
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

  static const _nationwideHeading = 'Tüm ülke';

  /// 81-il resmi adı; boş / ülke geneli → Tüm ülke; listede yoksa ham metin.
  String _etkinlikCityHeading(KampanyaItem k) {
    if (k.isNationwide) return _nationwideHeading;
    final raw = k.city.trim();
    if (raw.isEmpty) return _nationwideHeading;
    final folded = foldTurkish(raw);
    for (final name in kCityNames) {
      if (foldTurkish(name) == folded) return name;
    }
    return raw;
  }

  /// Tümü: boş / ülke geneli önce «Tüm ülke» (gizlenmesin), sonra iller, sonra bilinmeyen.
  List<MapEntry<String, List<KampanyaItem>>> get _etkinlikGroups {
    final buckets = <String, List<KampanyaItem>>{};
    for (final k in _visible) {
      final key = _etkinlikCityHeading(k);
      (buckets[key] ??= []).add(k);
    }
    final nationwide = buckets.remove(_nationwideHeading);
    final out = <MapEntry<String, List<KampanyaItem>>>[];
    if (nationwide != null && nationwide.isNotEmpty) {
      out.add(MapEntry(_nationwideHeading, nationwide));
    }
    for (final name in kCityNames) {
      final list = buckets.remove(name);
      if (list != null && list.isNotEmpty) {
        out.add(MapEntry(name, list));
      }
    }
    final unknown = buckets.entries.toList()
      ..sort((a, b) => foldTurkish(a.key).compareTo(foldTurkish(b.key)));
    out.addAll(unknown);
    return out;
  }

  bool _reorderEnabled(int i, int len, int delta) {
    if (!_isAdmin) return false;
    if (_isEtkinlik) {
      if (_filter != _KampanyaFilter.city) return false;
    } else if (_filter != _KampanyaFilter.all) {
      return false;
    }
    final j = i + delta;
    return j >= 0 && j < len;
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

  Future<void> _openPropose({String? city}) async {
    if (!await _requireMember(
      'Etkinlik önermek için giriş yapmanız veya üye olmanız gerekiyor.',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EtkinlikOneriSheet(presetCity: city ?? _city),
    );
    if (ok == true && mounted) {
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: L10nText('Öneriniz admin onayına gönderildi.'),
        ),
      );
    }
  }

  Future<void> _openPending() async {
    if (!_isAdmin) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.88,
        child: EtkinlikPendingSheet(
          items: _moderationItems,
          adminEmail: widget.userEmail,
          avmCovers: _avmCovers,
          onChanged: _reload,
        ),
      ),
    );
  }

  Future<void> _toggleJoin(KampanyaItem item) async {
    if (!isEtkinlikListed(item)) return;
    if (!await _requireMember(
      'Katılmak için giriş yapmanız veya üye olmanız gerekiyor.',
    )) {
      return;
    }
    if (!mounted || _joinBusyId == item.id) return;
    final nextJoined = !item.joinedByMe;
    final nextCount =
        (item.joinCount + (nextJoined ? 1 : -1)).clamp(0, 999999).toInt();
    setState(() {
      _joinBusyId = item.id;
      _items = [
        for (final k in _items)
          if (k.id == item.id)
            k.copyWith(joinedByMe: nextJoined, joinCount: nextCount)
          else
            k,
      ];
    });
    try {
      final result = await toggleEtkinlikKatilim(item.id);
      if (!mounted) return;
      setState(() {
        _items = [
          for (final k in _items)
            if (k.id == item.id)
              k.copyWith(joinedByMe: result.joined, joinCount: result.joinCount)
            else
              k,
        ];
        _joinBusyId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [
          for (final k in _items)
            if (k.id == item.id)
              k.copyWith(
                joinedByMe: item.joinedByMe,
                joinCount: item.joinCount,
              )
            else
              k,
        ];
        _joinBusyId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _openAdd({String? city}) async {
    final preset = city ?? _city;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GeziKampanyaAdminSheet(
        adminEmail: widget.userEmail,
        kind: _adminKind,
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
        kind: _adminKind,
        presetCity: item.isNationwide ? null : item.city,
        editKampanya: item,
      ),
    );
    if (ok == true && mounted) await _reload();
  }

  Future<void> _move(KampanyaItem item, int delta) async {
    if (_isEtkinlik) {
      if (_filter != _KampanyaFilter.city) return;
    } else if (_filter != _KampanyaFilter.all) {
      return;
    }
    final items = _visible;
    final i = items.indexWhere((g) => g.id == item.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= items.length) return;
    try {
      final next = List<KampanyaItem>.from(items);
      final tmp = next[i];
      next[i] = next[j];
      next[j] = tmp;
      await persistCityFeedOrder(kind: _adminKind, ordered: next);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sıra değiştirilemedi: $e')),
      );
    }
  }

  Future<void> _delete(KampanyaItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: L10nText(_isEtkinlik ? 'Etkinliği sil?' : 'Kampanyayı sil?'),
        content: L10nText(
          _isEtkinlik
              ? 'Bu etkinlik kalıcı olarak silinecek.'
              : 'Bu kampanya kalıcı olarak silinecek.',
        ),
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
      await (_isEtkinlik
          ? deleteEtkinlikItem(item.id)
          : deleteKampanyaItem(item.id));
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
        return _isEtkinlik
            ? 'Tüm ülkede geçerli etkinlik yok.'
            : 'Tüm ülkede geçerli kampanya yok.';
      case _KampanyaFilter.city:
        return _city == null
            ? 'İl seçin.'
            : _isEtkinlik
                ? 'Bu il için henüz etkinlik yok.'
                : 'Bu il için henüz kampanya yok.';
      case _KampanyaFilter.all:
        return _isEtkinlik ? 'Henüz etkinlik yok.' : 'Henüz kampanya yok.';
    }
  }

  String? get _emptyHint {
    if (!_isEtkinlik || _filter != _KampanyaFilter.all) return null;
    final err = lastEtkinlikLoadError;
    if (err != null && err.isNotEmpty) return err;
    if (_isAdmin) {
      return 'Haftalık AVM listesi için GitHub → Actions → scrape_events → Run workflow '
          '(GEMINI_API_KEY secret). Cron yalnız main’de çalışır.';
    }
    return null;
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
          _pageTitle,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_isEtkinlik)
            TextButton.icon(
              onPressed: () => _openPropose(),
              icon: const Icon(Icons.add, size: 20),
              label: L10nText(
                'Etkinlik ekle',
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: MetoColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          if (_isEtkinlik && _isAdmin)
            IconButton(
              tooltip: S.auto('Onay bekleyenler'),
              onPressed: _openPending,
              icon: Badge(
                isLabelVisible: _pendingCount > 0,
                label: Text('$_pendingCount'),
                child: const Icon(Icons.pending_actions_outlined),
              ),
            ),
          if (_isAdmin)
            IconButton(
              tooltip: S.auto(_addLabel),
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
                if (_isEtkinlik)
                  FilledButton.icon(
                    onPressed: () => _openPropose(),
                    style: FilledButton.styleFrom(
                      backgroundColor: MetoColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: L10nText(
                      'Etkinlik ekle',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (!_isEtkinlik)
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
          if (_isEtkinlik && _myPending.isNotEmpty && !_isAdmin)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Material(
                color: MetoColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: L10nText(
                    _myPending.length == 1
                        ? '1 öneriniz onay bekliyor.'
                        : '${_myPending.length} öneriniz onay bekliyor.',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w800,
                      color: MetoColors.primary,
                    ),
                  ),
                ),
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
                        ? RefreshIndicator(
                            color: MetoColors.primary,
                            onRefresh: () => _reload(),
                            child: ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(16, 48, 16, 32),
                              children: [_buildEmpty()],
                            ),
                          )
                        : RefreshIndicator(
                            color: MetoColors.primary,
                            onRefresh: () => _reload(),
                            child: _isEtkinlik &&
                                    _filter == _KampanyaFilter.all
                                ? _buildGroupedEtkinlikList()
                                : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      32,
                                    ),
                                    itemCount: items.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (context, i) {
                                      return _etkinlikCard(
                                        items[i],
                                        index: i,
                                        length: items.length,
                                      );
                                    },
                                  ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _etkinlikCard(
    KampanyaItem item, {
    required int index,
    required int length,
  }) {
    return GeziKampanyaFeedCard(
      imageUrl: item.imageUrl,
      title: item.title,
      description: _isEtkinlik ? item.cardDescription : item.description,
      locationLabel:
          _isEtkinlik ? item.avmName.trim() : item.locationLabel,
      venueLabel: _isEtkinlik ? item.avmName.trim() : '',
      whenLabel: _isEtkinlik ? item.eventWhenLabel : '',
      timeLabel: _isEtkinlik ? item.eventTimeLabel : '',
      brandedCover: _isEtkinlik,
      coverPlaceholderLabel: _isEtkinlik ? item.avmName.trim() : '',
      avmCoverUrl: _isEtkinlik
          ? _avmCovers.urlFor(city: item.city, avmName: item.avmName)
          : '',
      coverVariantSeed: item.id,
      isAdmin: _isAdmin,
      onDelete: _isAdmin ? () => _delete(item) : null,
      onEdit: _isAdmin ? () => _openEdit(item) : null,
      onMoveUp:
          _reorderEnabled(index, length, -1) ? () => _move(item, -1) : null,
      onMoveDown:
          _reorderEnabled(index, length, 1) ? () => _move(item, 1) : null,
      showJoin: _isEtkinlik && isEtkinlikListed(item),
      joinCount: item.joinCount,
      joinedByMe: item.joinedByMe,
      joinBusy: _joinBusyId == item.id,
      onJoinTap: () => _toggleJoin(item),
      statusBadge: _isEtkinlik && isEtkinlikPending(item)
          ? 'Onay bekliyor'
          : '',
    );
  }

  Widget _buildCityHeading({
    required String title,
    required int count,
    required bool isFirst,
  }) {
    final nationwide = title == _nationwideHeading;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, isFirst ? 4 : 18, 0, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: MetoColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(
              nationwide
                  ? Icons.public_outlined
                  : Icons.location_city_outlined,
              size: 16,
              color: MetoColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: L10nText(
              title,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: MetoColors.mutedFg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedEtkinlikList() {
    final groups = _etkinlikGroups;
    if (groups.isEmpty) {
      final items = _visible;
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          return _etkinlikCard(
            items[i],
            index: i,
            length: items.length,
          );
        },
      );
    }
    final rows = <Object>[];
    for (var gi = 0; gi < groups.length; gi++) {
      final g = groups[gi];
      rows.add(
        _EtkinlikGroupHeader(
          title: g.key,
          count: g.value.length,
          isFirst: gi == 0,
        ),
      );
      rows.addAll(g.value);
    }
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        if (row is _EtkinlikGroupHeader) {
          return _buildCityHeading(
            title: row.title,
            count: row.count,
            isFirst: row.isFirst,
          );
        }
        final item = row as KampanyaItem;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _etkinlikCard(item, index: 0, length: 1),
        );
      },
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
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MetoColors.foreground,
              ),
            ),
            if (_emptyHint != null) ...[
              const SizedBox(height: 10),
              L10nText(
                _emptyHint!,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                ),
              ),
            ],
            if (_isEtkinlik) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openPropose(city: _city),
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                ),
                icon: const Icon(Icons.event_available_outlined),
                label: const L10nText('Etkinlik ekle'),
              ),
            ],
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _openAdd(city: _city),
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                ),
                icon: const Icon(Icons.add),
                label: L10nText(_addLabel),
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

class _EtkinlikGroupHeader {
  const _EtkinlikGroupHeader({
    required this.title,
    required this.count,
    required this.isFirst,
  });

  final String title;
  final int count;
  final bool isFirst;
}

