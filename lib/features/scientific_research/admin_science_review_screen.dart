import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin_config.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/l10n_text.dart';
import '../../meto_theme.dart';
import 'scientific_research_model.dart';
import 'scientific_research_repository.dart';

class AdminScienceReviewScreen extends StatefulWidget {
  const AdminScienceReviewScreen({
    super.key,
    this.adminEmail,
    this.repository,
  });

  final String? adminEmail;
  final ScientificResearchRepository? repository;

  static Future<void> open(
    BuildContext context, {
    String? adminEmail,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminScienceReviewScreen(adminEmail: adminEmail),
      ),
    );
  }

  @override
  State<AdminScienceReviewScreen> createState() =>
      _AdminScienceReviewScreenState();
}

class _AdminScienceReviewScreenState extends State<AdminScienceReviewScreen> {
  late final ScientificResearchRepository _repo =
      widget.repository ?? ScientificResearchRepository();
  List<ScientificResearch> _items = const [];
  var _loading = true;
  String? _error;
  String? _busyId;
  var _filter = ScienceAdminFilter.pending;

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

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _repo.loadForAdmin(filter: _filter);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = scientificResearchLoadError(e);
        _loading = false;
      });
    }
  }

  Future<void> _edit(ScientificResearch item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final summaryCtrl = TextEditingController(text: item.summary);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Metni düzenle',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Başlık (TR)'),
              ),
              if (!isBlankOrUnspecified(item.originalTitle) &&
                  item.originalTitle.trim() != item.title.trim()) ...[
                const SizedBox(height: 6),
                Text(
                  'Orijinal başlık: ${item.originalTitle}',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: summaryCtrl,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Özet'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: MetoColors.primary),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = item.id);
    try {
      await _repo.updateCopy(
        id: item.id,
        title: titleCtrl.text,
        summary: summaryCtrl.text,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: ${scientificResearchLoadError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _approve(ScientificResearch item) async {
    setState(() => _busyId = item.id);
    try {
      await _repo.approve(item.id);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yayınlandı. Bildirim veya ana sayfa duyurusu gönderilmedi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Onaylanamadı: ${scientificResearchLoadError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(ScientificResearch item) async {
    setState(() => _busyId = item.id);
    try {
      await _repo.reject(item.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reddedilemedi: ${scientificResearchLoadError(e)}')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _unpublish(ScientificResearch item) async {
    setState(() => _busyId = item.id);
    try {
      await _repo.unpublish(item.id);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yayından kaldırıldı.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaldırılamadı: ${scientificResearchLoadError(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  String get _emptyCopy {
    switch (_filter) {
      case ScienceAdminFilter.pending:
        return 'Bekleyen kayıt yok. Collector henüz pending_review yazmadıysa liste boş kalır.';
      case ScienceAdminFilter.published:
        return 'Yayınlanan araştırma yok.';
      case ScienceAdminFilter.rejected:
        return 'Reddedilen kayıt yok.';
      case ScienceAdminFilter.highValue:
        return 'Tedavi umudu yüksek işaretli kayıt yok.';
      case ScienceAdminFilter.clinical:
        return 'Klinik çalışma kaydı yok.';
      case ScienceAdminFilter.pediatric:
        return 'Çocuk / pediatri kaydı yok.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          S.t('science_admin_title'),
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
                    'Araştırma özetidir; tedavi bulundu iddiası yoktur. Aşama (hayvan / faz / insan) kartta yazılır.',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      height: 1.35,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(
                    children: [
                      for (final e in const [
                        (ScienceAdminFilter.pending, 'science_admin_filter_pending'),
                        (ScienceAdminFilter.published, 'science_admin_filter_published'),
                        (ScienceAdminFilter.rejected, 'science_admin_filter_rejected'),
                        (ScienceAdminFilter.highValue, 'science_admin_filter_high'),
                        (ScienceAdminFilter.clinical, 'science_admin_filter_clinical'),
                        (ScienceAdminFilter.pediatric, 'science_admin_filter_pediatric'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(S.t(e.$2)),
                            selected: _filter == e.$1,
                            onSelected: _loading
                                ? null
                                : (_) {
                                    setState(() => _filter = e.$1);
                                    _reload();
                                  },
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
                          : _items.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: L10nText(
                                      _emptyCopy,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.nunito(
                                        color: MetoColors.mutedFg,
                                      ),
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.fromLTRB(12, 8, 12, 24),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final item = _items[i];
                                    return _ScienceReviewCard(
                                      item: item,
                                      busy: _busyId == item.id,
                                      onEdit: () => _edit(item),
                                      onApprove: item.status == 'pending_review'
                                          ? () => _approve(item)
                                          : null,
                                      onReject: item.status == 'pending_review'
                                          ? () => _reject(item)
                                          : null,
                                      onUnpublish: item.status == 'published'
                                          ? () => _unpublish(item)
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

class _ScienceReviewCard extends StatelessWidget {
  const _ScienceReviewCard({
    required this.item,
    required this.busy,
    required this.onEdit,
    this.onApprove,
    this.onReject,
    this.onUnpublish,
  });

  final ScientificResearch item;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onUnpublish;

  Future<void> _open(String raw) async {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final ids = <String>[
      if (item.pmid.isNotEmpty) 'PMID ${item.pmid}',
      if (item.nctId.isNotEmpty) 'NCT ${item.nctId}',
      if (item.doi.isNotEmpty) 'DOI ${item.doi}',
    ];
    return Card(
      color: MetoColors.card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.displayTitle,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            if (!isBlankOrUnspecified(item.originalTitle) &&
                item.originalTitle.trim() != item.displayTitle) ...[
              const SizedBox(height: 8),
              _labeled('Orijinal başlık', item.originalTitle),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _chip(item.stageLabel, const Color(0xFF1D4ED8)),
                if (item.treatmentPotential.isNotEmpty)
                  _chip(
                    item.treatmentPotential == 'HIGH_VALUE'
                        ? 'Tedavi umudu yüksek'
                        : item.treatmentPotential,
                    item.treatmentPotential == 'HIGH_VALUE'
                        ? const Color(0xFF15803D)
                        : MetoColors.mutedFg,
                  ),
                if (!isBlankOrUnspecified(item.recruitmentStatus))
                  _chip(item.recruitmentStatus, MetoColors.mutedFg),
                if (!isBlankOrUnspecified(item.pediatricRelevance))
                  _chip(item.pediatricRelevance, const Color(0xFF7C3AED)),
              ],
            ),
            if (!isBlankOrUnspecified(item.summary)) ...[
              const SizedBox(height: 10),
              Text(item.summary, style: GoogleFonts.nunito(height: 1.35)),
            ],
            if (!isBlankOrUnspecified(item.whyImportant)) ...[
              const SizedBox(height: 8),
              _labeled('Neden önemli', item.whyImportant),
            ],
            if (!isBlankOrUnspecified(item.limitations)) ...[
              const SizedBox(height: 8),
              _labeled('Sınırlılıklar', item.limitations),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (item.relevanceScore != null)
                  _chip('İlgi ${item.relevanceScore}', MetoColors.mutedFg),
                if (item.scientificImportanceScore != null)
                  _chip(
                    'Bilim ${item.scientificImportanceScore}',
                    MetoColors.mutedFg,
                  ),
                if (item.treatmentPotentialScore != null)
                  _chip(
                    'Umudu ${item.treatmentPotentialScore}',
                    MetoColors.mutedFg,
                  ),
                if (item.clinicalReadinessScore != null)
                  _chip(
                    'Klinik hazırlık ${item.clinicalReadinessScore}',
                    MetoColors.mutedFg,
                  ),
              ],
            ),
            if (ids.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ids.join(' · '),
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: MetoColors.mutedFg,
                ),
              ),
            ],
            if (item.sourceUrl.isNotEmpty) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _open(item.sourceUrl),
                child: Text(
                  item.sourceUrl,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: MetoColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : onEdit,
                  child: const Text('Düzenle'),
                ),
                if (onApprove != null)
                  FilledButton(
                    onPressed: busy ? null : onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: MetoColors.primary,
                    ),
                    child: const Text('Onayla'),
                  ),
                if (onReject != null)
                  OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                    ),
                    child: const Text('Reddet'),
                  ),
                if (onUnpublish != null)
                  OutlinedButton(
                    onPressed: busy ? null : onUnpublish,
                    child: const Text('Yayından kaldır'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _labeled(String label, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: MetoColors.mutedFg,
          ),
        ),
        const SizedBox(height: 2),
        Text(body, style: GoogleFonts.nunito(height: 1.35)),
      ],
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
