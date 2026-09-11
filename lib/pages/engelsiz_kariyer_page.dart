import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../engelsiz_kariyer_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../section_editors.dart';
import '../widgets/engelsiz_kariyer_admin_sheet.dart';

class EngelsizKariyerPage extends StatefulWidget {
  const EngelsizKariyerPage({
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
        builder: (_) => EngelsizKariyerPage(userEmail: userEmail),
      ),
    );
  }

  @override
  State<EngelsizKariyerPage> createState() => _EngelsizKariyerPageState();
}

class _EngelsizKariyerPageState extends State<EngelsizKariyerPage> {
  final _search = TextEditingController();
  List<KariyerJob> _items = const [];
  bool _loading = true;
  String _sektor = kKariyerSektorAll;

  bool get _isAdmin => canEditSection(widget.userEmail, SectionKey.kariyer);

  @override
  void initState() {
    super.initState();
    final cached = cachedKariyerJobs;
    if (cached != null) {
      _items = List<KariyerJob>.from(cached);
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
    final list = await loadKariyerJobs(
      forceRefresh: !hasFreshKariyerCache,
      includeHidden: _isAdmin,
    );
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  List<KariyerJob> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _items.where((j) {
      if (!_isAdmin && j.hidden) return false;
      if (!kariyerMatchesSektor(j, _sektor)) return false;
      if (q.isEmpty) return true;
      final hay =
          '${j.title} ${j.city} ${j.date} ${j.workType} ${j.employerType} ${j.sektorDisplay}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _openApply(KariyerJob job) async {
    final raw = job.applyUrl.trim().isEmpty ? kKariyerSourceUrl : job.applyUrl;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openEdit({KariyerJob? item}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EngelsizKariyerAdminSheet(
        adminEmail: widget.userEmail,
        edit: item,
      ),
    );
    if (ok == true && mounted) await _reload(silent: false);
  }

  Future<void> _delete(KariyerJob item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('İlanı gizle?'),
        content: const L10nText(
          'İlan katalogdan silinmez; yalnızca listede gizlenir. '
          'İŞKUR kaynağı yenilenince de gizli kalır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const L10nText('Gizle'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await hideKariyerJob(adminEmail: widget.userEmail, job: item);
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
    final items = _visible;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: L10nText(
          'Engelsiz Kariyer',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: S.auto('Yenile'),
            onPressed: _loading
                ? null
                : () {
                    invalidateKariyerCache();
                    _reload();
                  },
            icon: const Icon(Icons.refresh),
          ),
          if (_isAdmin)
            IconButton(
              tooltip: S.auto('İlan ekle'),
              onPressed: () => _openEdit(),
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: L10nText(
              'İŞKUR açık iş ilanları (engelli ve yaşlı bakım). '
              'Kamu / özel, kaynaktaki işyeri türü ile aynıdır. '
              'Başvuru İŞKUR sayfasında yapılır. Liste GitHub JSON önbelleğidir; '
              'ana sayfa veritabanına sormaz.',
              style: GoogleFonts.nunito(
                fontSize: 13,
                height: 1.35,
                color: MetoColors.mutedFg,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SektorChip(
                  label: 'Kamu',
                  active: _sektor == kKariyerSektorKamu,
                  onTap: () => setState(() => _sektor = kKariyerSektorKamu),
                ),
                _SektorChip(
                  label: 'Özel',
                  active: _sektor == kKariyerSektorOzel,
                  onTap: () => setState(() => _sektor = kKariyerSektorOzel),
                ),
                _SektorChip(
                  label: 'Tümü',
                  active: _sektor == kKariyerSektorAll,
                  onTap: () => setState(() => _sektor = kKariyerSektorAll),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.nunito(),
              decoration: InputDecoration(
                hintText: S.auto('İl veya ilan ara…'),
                prefixIcon: const Icon(Icons.search, color: MetoColors.mutedFg),
                suffixIcon: _search.text.isNotEmpty
                    ? IconButton(
                        onPressed: () => setState(_search.clear),
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
              ),
            ),
          ),
          if (_loading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: MetoColors.primary,
            ),
          Expanded(
            child: _loading && items.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: MetoColors.primary),
                  )
                : items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: L10nText(
                            lastKariyerLoadError ??
                                (_sektor == kKariyerSektorKamu
                                    ? 'Şu an kamu ilanı yok. İŞKUR’da bu meslek için kamu kaydı açılınca burada görünür.'
                                    : _sektor == kKariyerSektorOzel
                                        ? 'Şu an özel sektör ilanı yok.'
                                        : 'Şu an listelenecek ilan yok.'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        color: MetoColors.primary,
                        onRefresh: () {
                          invalidateKariyerCache();
                          return _reload();
                        },
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final job = items[i];
                            return _JobCard(
                              job: job,
                              isAdmin: _isAdmin,
                              onOpen: () => _openApply(job),
                              onEdit: () => _openEdit(item: job),
                              onDelete: () => _delete(job),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _SektorChip extends StatelessWidget {
  const _SektorChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? MetoColors.primary : MetoColors.muted,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: L10nText(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : MetoColors.mutedFg,
            ),
          ),
        ),
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.job,
    required this.isAdmin,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final KariyerJob job;
  final bool isAdmin;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bits = <String>[
      if (job.sektorDisplay.isNotEmpty) job.sektorDisplay,
      if (job.city.isNotEmpty) job.city,
      if (job.date.isNotEmpty) 'Son: ${job.date}',
      if (job.workType.isNotEmpty) job.workType,
      if (job.positions.isNotEmpty) '${job.positions} pozisyon',
    ];
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (job.hidden)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: L10nText(
                          'Gizli',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                      ),
                    L10nText(
                      job.title,
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: MetoColors.foreground,
                      ),
                    ),
                    if (bits.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        bits.join(' · '),
                        style: GoogleFonts.nunito(
                          fontSize: 13,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isAdmin) ...[
                IconButton(
                  tooltip: S.auto('Düzenle'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
                IconButton(
                  tooltip: S.auto('Gizle'),
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ] else
                IconButton(
                  tooltip: S.auto('İŞKUR’da aç'),
                  onPressed: onOpen,
                  icon: const Icon(Icons.open_in_new, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
