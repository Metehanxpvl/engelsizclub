import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../kesfet/kesfet_models.dart';
import '../kesfet/kesfet_oembed.dart';
import '../kesfet/kesfet_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';

/// Profil → Keşfet İçerikleri (isAppAdmin).
class AdminKesfetPanel extends StatefulWidget {
  const AdminKesfetPanel({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<AdminKesfetPanel> createState() => _AdminKesfetPanelState();
}

class _AdminKesfetPanelState extends State<AdminKesfetPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  int _gen = 0;

  static const _status = ['pending', 'approved', 'rejected', 'hidden'];
  static const _labels = ['Bekleyen', 'Onaylanan', 'Reddedilen', 'Gizlenen'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Geri',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                'Keşfet İçerikleri',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                await showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: MetoColors.card,
                  builder: (_) => const _AddYoutubeSheet(),
                );
                if (mounted) setState(() => _gen++);
              },
              icon: const Icon(Icons.add),
              label: const L10nText('+ YouTube Videosu Ekle'),
            ),
          ],
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          labelColor: MetoColors.primary,
          tabs: const [
            Tab(text: 'Bekleyen'),
            Tab(text: 'Onaylanan'),
            Tab(text: 'Reddedilen'),
            Tab(text: 'Gizlenen'),
            Tab(text: 'Raporlar'),
            Tab(text: 'Kelimeler'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              for (var i = 0; i < 4; i++)
                _StatusList(
                  key: ValueKey('${_status[i]}_$_gen'),
                  status: _status[i],
                  label: _labels[i],
                ),
              const _ReportsList(),
              const _KeywordsEditor(),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusList extends StatefulWidget {
  const _StatusList({
    super.key,
    required this.status,
    required this.label,
  });
  final String status;
  final String label;

  @override
  State<_StatusList> createState() => _StatusListState();
}

class _StatusListState extends State<_StatusList> {
  late Future<List<KesfetVideo>> _future;

  @override
  void initState() {
    super.initState();
    _future = KesfetStore.instance.adminList(widget.status);
  }

  Future<void> _reload() async {
    setState(() => _future = KesfetStore.instance.adminList(widget.status));
  }

  Future<void> _set(KesfetVideo v, String status) async {
    try {
      await KesfetStore.instance.adminSetStatus(v.id, status);
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
    return FutureBuilder<List<KesfetVideo>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: L10nText(
                'Liste alınamadı. Supabase’de kesfet_*.sql dosyalarını çalıştırın.\n\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return Center(
            child: L10nText(
              '${widget.label} listesi boş. Sahte video eklenmez.',
              style: const TextStyle(color: MetoColors.mutedFg),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final v = list[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: v.resolvedThumb.isEmpty
                      ? const SizedBox(
                          width: 64,
                          height: 64,
                          child: ColoredBox(color: MetoColors.muted),
                        )
                      : Image.network(
                          v.resolvedThumb,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(
                            width: 64,
                            height: 64,
                            child: ColoredBox(color: MetoColors.muted),
                          ),
                        ),
                ),
                title: Text(
                  v.title.trim().isEmpty ? '(başlıksız)' : v.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${v.channelName} · ${v.categoryTitle} · skor ${v.relevanceScore}'
                  '${v.safetyFlag ? ' · ⚠ güvenlik' : ''}\n'
                  '${v.createdAt.toLocal()} · ${v.status}',
                  maxLines: 3,
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  tooltip: 'İşlemler',
                  onSelected: (s) {
                    if (s == 'yt') {
                      unawaited(launchUrl(
                        Uri.parse(v.watchUrl),
                        mode: LaunchMode.externalApplication,
                      ));
                      return;
                    }
                    unawaited(_set(v, s));
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'yt',
                      child: Text('YouTube’da aç'),
                    ),
                    if (v.status != 'approved')
                      const PopupMenuItem(
                        value: 'approved',
                        child: Text('Onayla'),
                      ),
                    if (v.status != 'rejected')
                      const PopupMenuItem(
                        value: 'rejected',
                        child: Text('Reddet'),
                      ),
                    if (v.status != 'hidden')
                      const PopupMenuItem(
                        value: 'hidden',
                        child: Text('Gizle'),
                      ),
                    if (v.status != 'pending')
                      const PopupMenuItem(
                        value: 'pending',
                        child: Text('Beklemeye al'),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ReportsList extends StatefulWidget {
  const _ReportsList();

  @override
  State<_ReportsList> createState() => _ReportsListState();
}

class _ReportsListState extends State<_ReportsList> {
  late Future<List<KesfetReportRow>> _future;

  @override
  void initState() {
    super.initState();
    _future = KesfetStore.instance.adminReports();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<KesfetReportRow>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('${snap.error}'));
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return const Center(
            child: L10nText(
              'Henüz rapor yok.',
              style: TextStyle(color: MetoColors.mutedFg),
            ),
          );
        }
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (_, i) {
            final r = list[i];
            return ListTile(
              title: Text(r.videoTitle.trim().isEmpty ? r.videoId : r.videoTitle),
              subtitle: Text('${r.reason}\n${r.ownerEmail} · ${r.status}'),
              isThreeLine: true,
              trailing: r.youtubeUrl.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'YouTube',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: () => launchUrl(
                        Uri.parse(r.youtubeUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                    ),
            );
          },
        );
      },
    );
  }
}

class _KeywordsEditor extends StatefulWidget {
  const _KeywordsEditor();

  @override
  State<_KeywordsEditor> createState() => _KeywordsEditorState();
}

class _KeywordsEditorState extends State<_KeywordsEditor> {
  List<KesfetKeyword> _items = const [];
  bool _loading = true;
  final _phrase = TextEditingController();
  String _polarity = 'positive';

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  @override
  void dispose() {
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final list = await KesfetStore.instance.loadKeywords(force: true);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final p = _phrase.text.trim().toLowerCase();
    if (p.isEmpty) return;
    try {
      await KesfetStore.instance.upsertKeyword(
        KesfetKeyword(phrase: p, polarity: _polarity),
      );
      _phrase.clear();
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phrase,
                  decoration: const InputDecoration(
                    hintText: 'Yeni kelime / ifade',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _polarity,
                items: const [
                  DropdownMenuItem(value: 'positive', child: Text('Pozitif')),
                  DropdownMenuItem(value: 'negative', child: Text('Negatif')),
                  DropdownMenuItem(value: 'safety', child: Text('Güvenlik')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _polarity = v);
                },
              ),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  minimumSize: const Size(44, 44),
                ),
                onPressed: _add,
                tooltip: 'Ekle',
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: L10nText(
            'Pozitif: alaka artırır. Negatif: düşürür (zayıf “gündem” otomatik red değildir). Güvenlik: sağlık iddiası, asla otomatik onay.',
            style: TextStyle(fontSize: 11, color: MetoColors.mutedFg),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _items.length,
            itemBuilder: (_, i) {
              final k = _items[i];
              return ListTile(
                dense: true,
                title: Text(k.phrase),
                subtitle: Text(
                  '${k.polarity} · ağırlık ${k.weight}'
                  '${k.categoryHint.isEmpty ? '' : ' · ${k.categoryHint}'}'
                  '${k.isWeak ? ' · zayıf' : ''}',
                ),
                trailing: IconButton(
                  tooltip: 'Sil',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: k.id <= 0
                      ? null
                      : () async {
                          await KesfetStore.instance.deleteKeyword(k.id);
                          await _reload();
                        },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddYoutubeSheet extends StatefulWidget {
  const _AddYoutubeSheet();

  @override
  State<_AddYoutubeSheet> createState() => _AddYoutubeSheetState();
}

class _AddYoutubeSheetState extends State<_AddYoutubeSheet> {
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _related = TextEditingController();
  String _category = 'engellilik';
  String _channel = '';
  String _channelUrl = '';
  String _thumb = '';
  String _videoId = '';
  KesfetScore? _score;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _desc.dispose();
    _related.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final id = extractYoutubeVideoId(_url.text);
      if (id == null) {
        throw StateError(
          'youtube.com/shorts/…, youtu.be/… veya watch?v= bağlantısı girin.',
        );
      }
      final o = await fetchYoutubeOEmbed(_url.text);
      final score = await KesfetStore.instance.scoreFields(
        title: o.title,
        description: _desc.text,
        channel: o.authorName,
      );
      if (!mounted) return;
      setState(() {
        _videoId = id;
        _title.text = o.title;
        _channel = o.authorName;
        _channelUrl = o.authorUrl;
        _thumb = o.thumbnailUrl;
        _score = score;
        if (score.suggestedCategory.isNotEmpty) {
          _category = score.suggestedCategory;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _save(String status) async {
    if (_videoId.isEmpty) {
      await _lookup();
      if (_videoId.isEmpty) return;
    }
    var score = _score;
    score ??= await KesfetStore.instance.scoreFields(
      title: _title.text,
      description: _desc.text,
      channel: _channel,
    );
    if (score.safetyFlag && status == 'approved') {
      if (!mounted) return;
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const L10nText('Güvenlik uyarısı'),
          content: L10nText(
            '${score!.safetyNote}\n\nSağlık iddiası içeren videolar otomatik onaylanmaz. Yine de yayınlamak istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const L10nText('Beklemede bırak'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const L10nText('Yine de yayınla'),
            ),
          ],
        ),
      );
      if (go != true) status = 'pending';
    }
    try {
      setState(() => _loading = true);
      final related = _related.text.trim();
      final uuid = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      await KesfetStore.instance.adminUpsertVideo(
        youtubeVideoId: _videoId,
        youtubeUrl: canonicalYoutubeUrl(_videoId),
        title: _title.text,
        description: _desc.text,
        thumbnailUrl: _thumb,
        channelName: _channel,
        channelUrl: _channelUrl,
        category: _category,
        status: status,
        score: score,
        relatedArticleId: uuid.hasMatch(related) ? related : '',
        relatedArticleSlug: uuid.hasMatch(related) ? '' : related,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: L10nText(
            status == 'approved' ? 'Yayınlandı.' : 'Bekleyenlere kaydedildi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'YouTube videosu ekle',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const L10nText(
              'Shorts veya normal YouTube bağlantısı. API anahtarı kullanılmaz (oEmbed).',
              style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'YouTube URL',
                hintText: 'https://www.youtube.com/shorts/…',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _lookup,
              style: FilledButton.styleFrom(backgroundColor: MetoColors.primary),
              child: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const L10nText('Bilgileri getir'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFB91C1C))),
            ],
            if (_videoId.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (_thumb.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(_thumb, height: 120, fit: BoxFit.cover),
                ),
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
              TextField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Kısa açıklama'),
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Kategori'),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: KesfetCategory.feed.any(
                            (c) => c.slug == _category && c.slug != 'sana-ozel')
                        ? _category
                        : 'engellilik',
                    items: [
                      for (final c in KesfetCategory.feed)
                        if (c.slug != 'sana-ozel')
                          DropdownMenuItem(value: c.slug, child: Text(c.title)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _category = v);
                    },
                  ),
                ),
              ),
              TextField(
                controller: _related,
                decoration: const InputDecoration(
                  labelText: 'İlgili içerik (slug / yol)',
                  hintText: 'otizm veya /bilgi-kutuphanesi/…',
                ),
              ),
              if (_score != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Skor: ${_score!.score} · önerilen: ${KesfetCategory.titleFor(_score!.suggestedCategory)}'
                  '${_score!.safetyFlag ? '\n⚠ ${_score!.safetyNote}' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _score!.safetyFlag
                        ? const Color(0xFFB45309)
                        : MetoColors.mutedFg,
                  ),
                ),
                if (_channel.isNotEmpty)
                  Text(
                    'Kanal: $_channel',
                    style: const TextStyle(color: MetoColors.mutedFg),
                  ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loading ? null : () => _save('pending'),
                      child: const L10nText('Beklemede kaydet'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _loading ? null : () => _save('approved'),
                      style: FilledButton.styleFrom(
                        backgroundColor: MetoColors.primary,
                      ),
                      child: const L10nText('Yayınla'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
