import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin_config.dart';
import '../../l10n/l10n_text.dart';
import '../../meto_theme.dart';
import 'daily_news_model.dart';
import 'daily_news_repository.dart';

class AdminDailyNewsScreen extends StatefulWidget {
  const AdminDailyNewsScreen({
    super.key,
    this.adminEmail,
    this.repository,
  });

  final String? adminEmail;
  final DailyNewsRepository? repository;

  static Future<void> open(
    BuildContext context, {
    String? adminEmail,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminDailyNewsScreen(adminEmail: adminEmail),
      ),
    );
  }

  @override
  State<AdminDailyNewsScreen> createState() => _AdminDailyNewsScreenState();
}

class _AdminDailyNewsScreenState extends State<AdminDailyNewsScreen> {
  late final DailyNewsRepository _repo =
      widget.repository ?? DailyNewsRepository();
  List<DailyNewsCandidate> _items = const [];
  var _loading = true;
  String? _error;
  String? _busyId;

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
      final items = await _repo.loadPending();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('Bad state: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _approve(DailyNewsCandidate item) async {
    setState(() => _busyId = item.id);
    try {
      await _repo.approve(item, adminEmail: widget.adminEmail);
      if (!mounted) return;
      setState(() {
        _items = [for (final e in _items) if (e.id != item.id) e];
        _busyId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Yayınlandı (Güncel Duyurular).')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yayınlanamadı: $e'.replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _edit(DailyNewsCandidate item) async {
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
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: summaryCtrl,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'AI özeti'),
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
        SnackBar(content: Text('Kaydedilemedi: $e'.replaceFirst('Bad state: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(DailyNewsCandidate item) async {
    setState(() => _busyId = item.id);
    try {
      await _repo.reject(item.id);
      if (!mounted) return;
      setState(() {
        _items = [for (final e in _items) if (e.id != item.id) e];
        _busyId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reddedilemedi: $e'.replaceFirst('Bad state: ', ''))),
      );
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
          'Yeni Haberler',
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
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
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
                              'Bekleyen gazete haberi yok. Daily news scan henüz pending yazmadıysa liste boş kalır.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return _NewsCandidateCard(
                              item: item,
                              busy: _busyId == item.id,
                              onEdit: () => _edit(item),
                              onApprove: () => _approve(item),
                              onReject: () => _reject(item),
                            );
                          },
                        ),
    );
  }
}

class _NewsCandidateCard extends StatelessWidget {
  const _NewsCandidateCard({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onApprove,
    required this.onReject,
  });

  final DailyNewsCandidate item;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final date = item.publishedAt;
    final dateLabel = date == null
        ? ''
        : '${date.toLocal().day.toString().padLeft(2, '0')}.'
            '${date.toLocal().month.toString().padLeft(2, '0')}.'
            '${date.toLocal().year}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(
                label: const Text('Yeni / Onay bekliyor'),
                visualDensity: VisualDensity.compact,
                backgroundColor: const Color(0xFFFEF3C7),
                labelStyle: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: const Color(0xFFB45309),
                ),
              ),
              if (item.category.isNotEmpty)
                Chip(
                  label: Text(item.category),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (dateLabel.isNotEmpty) dateLabel,
              '${item.importanceLabelTr} · ${item.relevanceScore}',
            ].join('  ·  '),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          if (item.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'AI özeti',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: MetoColors.mutedFg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.summary,
              style: GoogleFonts.nunito(fontSize: 13, height: 1.4),
            ),
          ],
          if (item.sourceName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Kaynak: ${item.sourceName}',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: MetoColors.mutedFg,
              ),
            ),
          ],
          if (item.aiReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.aiReason,
              style: GoogleFonts.nunito(
                fontSize: 12,
                height: 1.35,
                color: MetoColors.mutedFg,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (item.articleUrl.isNotEmpty)
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () {
                          final uri = Uri.tryParse(item.articleUrl);
                          if (uri != null) {
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                  child: const L10nText('Haberi aç'),
                ),
              OutlinedButton(
                onPressed: busy ? null : onEdit,
                child: const L10nText('Düzenle'),
              ),
              FilledButton(
                onPressed: busy ? null : onApprove,
                style: FilledButton.styleFrom(backgroundColor: MetoColors.primary),
                child: const L10nText('Yayınla'),
              ),
              OutlinedButton(
                onPressed: busy ? null : onReject,
                child: const L10nText('Reddet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
