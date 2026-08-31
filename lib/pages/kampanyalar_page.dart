import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_config.dart';
import '../gezi_kampanya_store.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../widgets/gezi_kampanya_admin_sheet.dart';
import '../widgets/gezi_kampanya_feed_card.dart';

/// Kampanyalar — story benzeri dikey liste (görsel + açıklama).
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
  List<KampanyaItem> _items = const [];
  bool _loading = true;

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

  List<KampanyaItem> get _visible {
    final list = (_isAdmin ? _items : _items.where((k) => k.isActive)).toList();
    list.sort((a, b) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<void> _openAdd() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GeziKampanyaAdminSheet(
        adminEmail: widget.userEmail,
        kind: GeziKampanyaKind.kampanya,
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
          'Kampanyalar',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: S.auto('Kampanya ekle'),
              onPressed: _openAdd,
              icon: const Icon(Icons.add_circle_outline),
            ),
        ],
      ),
      body: _loading && items.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: MetoColors.primary),
            )
          : items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        L10nText(
                          'Henüz kampanya yok.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: MetoColors.mutedFg,
                          ),
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _openAdd,
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
                )
              : RefreshIndicator(
                  color: MetoColors.primary,
                  onRefresh: () => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final item = items[i];
                      return GeziKampanyaFeedCard(
                        imageUrl: item.imageUrl,
                        title: item.title,
                        description: item.description,
                        isAdmin: _isAdmin,
                        onDelete: _isAdmin ? () => _delete(item) : null,
                      );
                    },
                  ),
                ),
    );
  }
}
