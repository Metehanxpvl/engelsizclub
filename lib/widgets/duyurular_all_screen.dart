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

  Future<void> _openViewer(DuyuruItem item) async {
    final items = _catalog;
    await _showDuyuruStoryViewer(
      context: context,
      items: items,
      item: item,
      isAdmin: _isAdmin,
      onSeen: _onStorySeen,
      onDelete: _isAdmin ? _confirmDelete : null,
    );
    if (mounted) setState(() {});
  }

  String _shortDate(DuyuruItem item) {
    final dt = duyuruSortDate(item);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
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
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              // Kullanıcı satırda 4 kart istedi. Dar telefonda
                              // 4 sütun okunmaz: <500px → 2, aksi halde 4.
                              final columns =
                                  constraints.maxWidth < 500 ? 2 : 4;
                              return GridView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  24,
                                ),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 0.78,
                                ),
                                itemCount: items.length,
                                itemBuilder: (context, i) {
                                  final item = items[i];
                                  return _DuyuruAllTile(
                                    item: item,
                                    seen: _seen.contains(item.id),
                                    dateLabel: _shortDate(item),
                                    onTap: () => _openViewer(item),
                                  );
                                },
                              );
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

class _DuyuruAllTile extends StatelessWidget {
  const _DuyuruAllTile({
    required this.item,
    required this.seen,
    required this.dateLabel,
    required this.onTap,
  });

  final DuyuruItem item;
  final bool seen;
  final String dateLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: MetoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 5, 5, 0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: seen
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                MetoColors.primary,
                                Color(0xFF2F9B6A),
                                MetoColors.accentGold,
                              ],
                            ),
                      color: seen ? const Color(0xFFCBD5E1) : null,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.5),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: item.isInstagramEmbed
                                  ? const DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topRight,
                                          end: Alignment.bottomLeft,
                                          colors: [
                                            Color(0xFFF58529),
                                            Color(0xFFDD2A7B),
                                            Color(0xFF8134AF),
                                            Color(0xFF515BD4),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.camera_alt_outlined,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                    )
                                  : SizedBox.expand(
                                      child: _DuyuruImage(
                                        source: item.imageUrl,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  dateLabel,
                                  style: GoogleFonts.nunito(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Text(
                  item.title.trim().isEmpty ? 'Duyuru' : item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    color: seen ? MetoColors.mutedFg : MetoColors.foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
