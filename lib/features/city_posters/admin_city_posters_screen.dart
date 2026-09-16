import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin_config.dart';
import '../../gezi_kampanya_store.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/l10n_text.dart';
import '../../meto_theme.dart';
import '../../widgets/photo_gallery_lightbox.dart';
import 'city_poster_catalog.dart';

class AdminCityPostersScreen extends StatefulWidget {
  const AdminCityPostersScreen({
    super.key,
    this.adminEmail,
    this.catalog,
  });

  final String? adminEmail;
  final CityPosterCatalog? catalog;

  static Future<void> open(
    BuildContext context, {
    String? adminEmail,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminCityPostersScreen(adminEmail: adminEmail),
      ),
    );
  }

  @override
  State<AdminCityPostersScreen> createState() => _AdminCityPostersScreenState();
}

enum _PosterFilter { all, ready, missing }

class _AdminCityPostersScreenState extends State<AdminCityPostersScreen> {
  late final CityPosterCatalog _catalog =
      widget.catalog ?? CityPosterCatalog();
  CityPosterSnapshot _snap = const CityPosterSnapshot(items: []);
  var _loading = true;
  String? _error;
  var _filter = _PosterFilter.all;
  final _search = TextEditingController();

  bool get _isAdmin => isAppAdmin(widget.adminEmail);

  @override
  void initState() {
    super.initState();
    if (!_isAdmin) {
      _loading = false;
      _error = 'Bu sayfa yalnızca yöneticiler içindir.';
      return;
    }
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _catalog.load();
      if (!mounted) return;
      setState(() {
        _snap = snap;
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

  List<CityPosterItem> get _visible {
    final q = foldTurkish(_search.text);
    return _snap.items.where((item) {
      if (_filter == _PosterFilter.ready && !item.hasImage) return false;
      if (_filter == _PosterFilter.missing && item.hasImage) return false;
      if (q.isEmpty) return true;
      return foldTurkish(item.city).contains(q) || item.slug.contains(q);
    }).toList();
  }

  Future<void> _openUrl(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _snap.readyCount;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          S.t('city_poster_admin_title'),
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading || !_isAdmin ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: !_isAdmin
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: L10nText(
                  'Bu sayfa yalnızca yöneticiler içindir.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: Text(
                    S.t('city_poster_admin_sub'),
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      height: 1.35,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ),
                if (!_loading && _error == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Text(
                      S.n('city_poster_admin_count', {
                        'n': '$ready',
                        'total': '${_snap.items.length}',
                      }),
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.foreground,
                      ),
                    ),
                  ),
                if (_snap.run != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Text(
                      'Son Action: ${_snap.run!.conclusion}'
                      '${_snap.run!.runNumber != null ? ' · #${_snap.run!.runNumber}' : ''}'
                      '${_snap.run!.headSha != null && _snap.run!.headSha!.length >= 7 ? ' · ${_snap.run!.headSha!.substring(0, 7)}' : ''}',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ),
                if (!_loading && ready == 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MetoColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: MetoColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            S.t('city_poster_admin_empty'),
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              height: 1.35,
                              color: MetoColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => _openUrl(kCityPosterWorkflowUrl),
                            icon: const Icon(Icons.open_in_new, size: 16),
                            label: Text(S.t('city_poster_admin_run')),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'İl ara',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      filled: true,
                      fillColor: MetoColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: MetoColors.border),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final e in [
                        (_PosterFilter.all, 'Tümü'),
                        (_PosterFilter.ready, 'Hazır'),
                        (_PosterFilter.missing, 'Eksik'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: ChoiceChip(
                            label: L10nText(e.$2),
                            selected: _filter == e.$1,
                            onSelected: _loading
                                ? null
                                : (_) => setState(() => _filter = e.$1),
                            selectedColor: MetoColors.selectedBg,
                            labelStyle: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: _filter == e.$1
                                  ? MetoColors.primary
                                  : MetoColors.mutedFg,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: L10nText(
                                  _error!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                              itemCount: _visible.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final item = _visible[i];
                                return _CityPosterCard(
                                  item: item,
                                  onOpen: item.hasImage
                                      ? () => openFillPhotoOverlay(
                                            context,
                                            source: item.imageUrl!,
                                          )
                                      : null,
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}

class _CityPosterCard extends StatelessWidget {
  const _CityPosterCard({required this.item, this.onOpen});

  final CityPosterItem item;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 74,
                  child: item.hasImage
                      ? FillPhoto(
                          source: item.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: _missingThumb(),
                        )
                      : _missingThumb(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.city,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: MetoColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.hasImage
                          ? '${item.city} müze gezisi · ${item.date}'
                          : 'Henüz üretilmedi',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                item.hasImage ? Icons.chevron_right : Icons.hourglass_empty,
                color: MetoColors.mutedFg,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missingThumb() {
    return ColoredBox(
      color: MetoColors.selectedBg,
      child: const Center(
        child: Icon(Icons.image_outlined, color: MetoColors.mutedFg),
      ),
    );
  }
}
