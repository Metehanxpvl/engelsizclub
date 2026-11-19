part of 'duyurular_section.dart';

enum _DuyuruAllSort { newestFirst, oldestFirst }

/// Tüm görünür duyuru/haberler (pop-up dahil; şerit tavanı yok).
class DuyurularAllScreen extends StatefulWidget {
  const DuyurularAllScreen({
    super.key,
    required this.userEmail,
  });

  final String userEmail;

  static Future<void> open(
    BuildContext context, {
    required String userEmail,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DuyurularAllScreen(userEmail: userEmail),
      ),
    );
  }

  @override
  State<DuyurularAllScreen> createState() => _DuyurularAllScreenState();
}

class _DuyurularAllScreenState extends State<DuyurularAllScreen> {
  List<DuyuruItem> _items = const [];
  Set<int> _seen = {};
  bool _loading = true;
  _DuyuruAllSort _sort = _DuyuruAllSort.newestFirst;

  bool get _isAdmin =>
      canEditSection(widget.userEmail, SectionKey.duyurular);

  List<DuyuruItem> get _catalog {
    return duyurularForAllScreen(
      _items,
      isEditor: _isAdmin,
      newestFirst: _sort == _DuyuruAllSort.newestFirst,
    );
  }

  @override
  void initState() {
    super.initState();
    final cached = cachedDuyurular;
    if (cached != null) {
      _items = cached;
      _loading = false;
    }
    _reload(silent: cached != null);
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final items = await loadDuyurular(
      forceRefresh: true,
      viewerEmail: widget.userEmail,
    );
    final seen = await loadSeenDuyuruIds(widget.userEmail);
    if (!mounted) return;
    setState(() {
      _items = items;
      _seen = seen;
      _loading = false;
    });
  }

  void _onStorySeen(DuyuruItem item) {
    unawaited(markDuyuruSeen(email: widget.userEmail, id: item.id));
    if (!mounted || _seen.contains(item.id)) return;
    setState(() => _seen = {..._seen, item.id});
  }

  Future<void> _confirmDelete(DuyuruItem item) async {
    if (!_isAdmin) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: L10nText(
          'Duyuruyu sil?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: L10nText(
          '"${item.title}" kalıcı olarak silinecek.',
          style: GoogleFonts.nunito(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const L10nText('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await deleteDuyuru(item.id);
      if (!mounted) return;
      setState(() {
        _items = _items.where((d) => d.id != item.id).toList();
        _seen = {..._seen}..remove(item.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Silinemedi: $e')),
      );
    }
  }

  Future<void> _openAdminForm({DuyuruItem? edit}) async {
    final result = await showModalBottomSheet<DuyuruItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminDuyuruSheet(
        adminEmail: widget.userEmail,
        edit: edit,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _items = [
        for (final d in _items)
          if (d.id == result.id) result else d,
      ];
    });
  }

  Future<void> _openViewer(DuyuruItem item) async {
    final items = _catalog;
    await _showDuyuruStoryViewer(
      context: context,
      items: items,
      item: item,
      isAdmin: _isAdmin,
      onSeen: _onStorySeen,
      onDelete: _isAdmin ? _confirmDelete : null,
      onEdit: _isAdmin ? (it) => _openAdminForm(edit: it) : null,
    );
    if (mounted) setState(() {});
  }

  String _shortDate(DuyuruItem item) {
    final dt = duyuruSortDate(item);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }

  Widget _thumb(DuyuruItem item, {required double width, required double height, required double radius}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: item.isInstagramEmbed
            ? const FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: _InstagramStoryThumb(size: 104),
              )
            : item.imageUrl.trim().isEmpty
                ? ColoredBox(
                    color: MetoColors.muted,
                    child: Center(
                      child: Icon(
                        Icons.campaign_outlined,
                        color: MetoColors.primary,
                        size: 28,
                      ),
                    ),
                  )
                : _DuyuruImage(
                    source: item.imageUrl,
                    width: width,
                    height: height,
                    fit: BoxFit.cover,
                  ),
      ),
    );
  }

  Widget _yeniBadge() {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: MetoColors.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'Yeni',
        style: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _mansetItem(DuyuruItem item, String dateLabel, bool seen) {
    final title = item.title.trim().isEmpty ? 'Duyuru' : item.title;
    final body = item.body.trim();
    return Semantics(
      button: true,
      label: 'Duyuru: $title, $dateLabel',
      child: InkWell(
        onTap: () => _openViewer(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _thumb(item, width: 800, height: 450, radius: 16),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!seen) _yeniBadge(),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunito(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: MetoColors.foreground,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: MetoColors.mutedFg,
                ),
              ),
              if (body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    color: MetoColors.mutedFg,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowItem(DuyuruItem item, String dateLabel, bool seen) {
    final title = item.title.trim().isEmpty ? 'Duyuru' : item.title;
    return Semantics(
      button: true,
      label: 'Duyuru: $title, $dateLabel',
      child: InkWell(
        onTap: () => _openViewer(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumb(item, width: 104, height: 78, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!seen) _yeniBadge(),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateLabel,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _catalog;
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: MetoColors.background,
          appBar: AppBar(
            backgroundColor: MetoColors.card,
            foregroundColor: MetoColors.foreground,
            elevation: 0,
            title: Text(
              S.t('duyuru_all_title'),
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(
                        S.t('duyuru_sort_newest'),
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      selected: _sort == _DuyuruAllSort.newestFirst,
                      selectedColor: MetoColors.primary.withValues(alpha: 0.18),
                      onSelected: (_) => setState(
                        () => _sort = _DuyuruAllSort.newestFirst,
                      ),
                    ),
                    ChoiceChip(
                      label: Text(
                        S.t('duyuru_sort_oldest'),
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      selected: _sort == _DuyuruAllSort.oldestFirst,
                      selectedColor: MetoColors.primary.withValues(alpha: 0.18),
                      onSelected: (_) => setState(
                        () => _sort = _DuyuruAllSort.oldestFirst,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                S.t('duyuru_all_empty'),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 1,
                              color: MetoColors.border,
                            ),
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final seen = _seen.contains(item.id);
                              final dateLabel = _shortDate(item);
                              if (i == 0) {
                                return _mansetItem(item, dateLabel, seen);
                              }
                              return _rowItem(item, dateLabel, seen);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
