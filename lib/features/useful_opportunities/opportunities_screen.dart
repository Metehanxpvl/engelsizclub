import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin_config.dart';
import '../../l10n/l10n_text.dart';
import '../../meto_theme.dart';
import '../../widgets/guest_timed_guard.dart';
import '../../widgets/medical_info_card.dart';
import 'admin_review_screen.dart';
import 'useful_content_model.dart';
import 'useful_content_repository.dart';

class OpportunitiesScreen extends StatefulWidget {
  const OpportunitiesScreen({
    super.key,
    this.adminEmail,
    this.repository,
  });

  final String? adminEmail;
  final UsefulContentRepository? repository;

  static Future<void> open(
    BuildContext context, {
    String? adminEmail,
    bool isGuest = false,
    VoidCallback? onRequireLogin,
    bool reviewQueue = false,
  }) {
    final child = reviewQueue && isAppAdmin(adminEmail)
        ? AdminReviewScreen(adminEmail: adminEmail)
        : OpportunitiesScreen(adminEmail: adminEmail);
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => GuestTimedGuard(
          isGuest: isGuest,
          tab: 'daha_fazlasi',
          onRequireLogin: onRequireLogin,
          child: child,
        ),
      ),
    );
  }

  @override
  State<OpportunitiesScreen> createState() => _OpportunitiesScreenState();
}

class _OpportunitiesScreenState extends State<OpportunitiesScreen> {
  late final UsefulContentRepository _repo =
      widget.repository ?? UsefulContentRepository();
  final _search = TextEditingController();
  List<UsefulContentItem> _items = const [];
  var _loading = true;
  String? _error;
  var _category = 'tumu';

  bool get _isAdmin => isAppAdmin(widget.adminEmail);

  @override
  void initState() {
    super.initState();
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
      final items = await _repo.loadPublished(
        category: _category,
        query: _search.text,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openAdmin() async {
    if (!_isAdmin) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminReviewScreen(adminEmail: widget.adminEmail),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Bağlantı açılamadı')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd.MM.yyyy');
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          'Fırsatlar ve Destekler',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'İnceleme',
              onPressed: _openAdmin,
              icon: const Icon(Icons.rate_review_outlined),
            ),
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _reload(),
              decoration: InputDecoration(
                hintText: 'Ara: burs, hak, haber, şehir…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.arrow_forward),
                ),
                filled: true,
                fillColor: MetoColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: MedicalInfoCard(
              title: 'Bilgilendirme',
              body:
                  'Bu kayıtlar resmi kaynak özetidir; tıbbi teşhis veya hukuki '
                  'danışmanlık değildir. Başvuru öncesi kaynağı kendiniz doğrulayın.',
              icon: Icons.info_outline,
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              children: [
                for (final e in kUsefulContentCategories.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _category == e.key,
                      onSelected: (_) {
                        setState(() => _category = e.key);
                        _reload();
                      },
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              L10nText(
                                'Liste yüklenemedi. SQL henüz çalıştırılmamış olabilir.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _reload,
                                child: const L10nText('Tekrar dene'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  L10nText(
                                    _isAdmin
                                        ? 'Kullanıcı listesi boş. Toplanan kayıtlar sağ üstteki İnceleme ikonunda onay bekliyor.'
                                        : 'Henüz yayınlanmış fırsat yok. Admin onayından sonra burada görünür.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.nunito(
                                      color: MetoColors.mutedFg,
                                    ),
                                  ),
                                  if (_isAdmin) ...[
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      onPressed: _openAdmin,
                                      icon: const Icon(Icons.rate_review_outlined),
                                      label: const L10nText('İnceleme'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            color: MetoColors.primary,
                            onRefresh: _reload,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                              itemCount: _items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final item = _items[i];
                                return Material(
                                  color: MetoColors.card,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _showDetail(item, dateFmt),
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Chip(
                                                label: Text(item.categoryLabel),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                              if (item.city.isNotEmpty) ...[
                                                const SizedBox(width: 8),
                                                Text(
                                                  item.city,
                                                  style: GoogleFonts.nunito(
                                                    color: MetoColors.mutedFg,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            item.title,
                                            style: GoogleFonts.nunito(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: MetoColors.foreground,
                                            ),
                                          ),
                                          if (item.summary.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              item.summary,
                                              maxLines: 3,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.nunito(
                                                height: 1.35,
                                                color: MetoColors.mutedFg,
                                              ),
                                            ),
                                          ],
                                          if (item.sourceName.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              item.sourceName,
                                              style: GoogleFonts.nunito(
                                                color: MetoColors.mutedFg,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                          if (item.deadlineAt != null) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              'Son tarih: ${dateFmt.format(item.deadlineAt!)}',
                                              style: GoogleFonts.nunito(
                                                fontWeight: FontWeight.w700,
                                                color: MetoColors.primary,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetail(
    UsefulContentItem item,
    DateFormat dateFmt,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              if (item.summary.isNotEmpty)
                Text(
                  item.summary,
                  style: GoogleFonts.nunito(height: 1.4),
                ),
              if (item.body.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(item.body, style: GoogleFonts.nunito(height: 1.4)),
              ],
              const SizedBox(height: 12),
              if (item.sourceName.isNotEmpty)
                Text(
                  'Kaynak: ${item.sourceName}',
                  style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                ),
              if (item.deadlineAt != null)
                Text(
                  'Son tarih: ${dateFmt.format(item.deadlineAt!)}',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                ),
              const SizedBox(height: 16),
              if (item.sourceUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openSource(item.sourceUrl);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: MetoColors.primary,
                    ),
                    child: const L10nText('Kaynağı aç'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
