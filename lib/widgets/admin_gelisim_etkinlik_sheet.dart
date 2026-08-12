import 'package:flutter/material.dart';

import '../data/gelisim_etkinlik_data.dart';
import '../gelisim_etkinlik_store.dart';
import '../meto_theme.dart';

/// Admin: her etkinliğe gömülü YouTube + kaynak.
class AdminGelisimEtkinlikSheet extends StatefulWidget {
  const AdminGelisimEtkinlikSheet({super.key});

  @override
  State<AdminGelisimEtkinlikSheet> createState() =>
      _AdminGelisimEtkinlikSheetState();
}

class _AdminGelisimEtkinlikSheetState extends State<AdminGelisimEtkinlikSheet> {
  List<GelisimEtkinlik> _items = const [];
  List<GelisimEtkinlik> _filtered = const [];
  final _q = TextEditingController();
  bool _loading = true;
  String? _error;
  int? _busyId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await loadGelisimEtkinlikleri(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
        _applyFilter();
      });
      if (list.isEmpty && mounted) {
        setState(() {
          _error =
              'Tablo boş. Supabase SQL Editor’de gelisim_etkinlikleri.sql çalıştırın.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _q.text.trim().toLowerCase();
    _filtered = q.isEmpty
        ? List.of(_items)
        : _items
            .where(
              (e) =>
                  e.title.toLowerCase().contains(q) ||
                  e.grupAd.toLowerCase().contains(q) ||
                  e.kaynak.toLowerCase().contains(q),
            )
            .toList();
  }

  Future<void> _edit(GelisimEtkinlik item) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GelisimEditForm(item: item),
    );
    if (result == null) return;
    setState(() => _busyId = item.id);
    try {
      await updateGelisimEtkinlik(
        id: item.id,
        youtubeUrl: result.youtubeUrl,
        kaynak: result.kaynak,
        isActive: result.isActive,
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MetoColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Gelişim Etkinlikleri — Video & Kaynak',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _reload,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const Text(
              'Her etkinliğe YouTube linki ve kaynak yazın. Kartta gömülü video + kaynak görünür.',
              style: TextStyle(fontSize: 12, color: MetoColors.mutedFg),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _q,
              onChanged: (_) => setState(_applyFilter),
              decoration: const InputDecoration(
                hintText: 'Etkinlik ara…',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = _filtered[i];
                    final busy = _busyId == item.id;
                    final hasYt = item.youtubeUrl.trim().isNotEmpty;
                    final hasSrc = item.kaynak.trim().isNotEmpty;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          item.grupAd,
                          item.yasAd,
                          if (hasYt) 'YouTube var',
                          if (hasSrc) 'Kaynak var',
                          if (!item.isActive) 'Pasif',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              tooltip: 'YouTube / Kaynak',
                              onPressed: () => _edit(item),
                              icon: Icon(
                                hasYt ? Icons.ondemand_video : Icons.videocam_off_outlined,
                                color: hasYt
                                    ? MetoColors.primary
                                    : MetoColors.mutedFg,
                              ),
                            ),
                      onTap: busy ? null : () => _edit(item),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditResult {
  const _EditResult({
    required this.youtubeUrl,
    required this.kaynak,
    required this.isActive,
  });
  final String youtubeUrl;
  final String kaynak;
  final bool isActive;
}

class _GelisimEditForm extends StatefulWidget {
  const _GelisimEditForm({required this.item});
  final GelisimEtkinlik item;

  @override
  State<_GelisimEditForm> createState() => _GelisimEditFormState();
}

class _GelisimEditFormState extends State<_GelisimEditForm> {
  late final TextEditingController _yt;
  late final TextEditingController _src;
  late bool _active;

  @override
  void initState() {
    super.initState();
    _yt = TextEditingController(text: widget.item.youtubeUrl);
    _src = TextEditingController(text: widget.item.kaynak);
    _active = widget.item.isActive;
  }

  @override
  void dispose() {
    _yt.dispose();
    _src.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + inset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.item.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.item.grupAd} · ${widget.item.yasAd} · ${widget.item.zorlukAd}',
              style: const TextStyle(fontSize: 12, color: MetoColors.mutedFg),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _yt,
              decoration: const InputDecoration(
                labelText: 'YouTube linki (gömülü video)',
                hintText: 'https://www.youtube.com/watch?v=…',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _src,
              decoration: const InputDecoration(
                labelText: 'Kaynak',
                hintText: 'Örn. Aile ve Sosyal Hizmetler Bakanlığı',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Aktif',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              value: _active,
              activeThumbColor: MetoColors.primary,
              onChanged: (v) => setState(() => _active = v),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  _EditResult(
                    youtubeUrl: _yt.text.trim(),
                    kaynak: _src.text.trim(),
                    isActive: _active,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
