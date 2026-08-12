import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../admin_config.dart';
import '../data/gelisim_etkinlik_data.dart';
import '../gelisim_etkinlik_store.dart';
import '../info_library/widgets/info_youtube_player.dart';
import '../medical_disclaimer_store.dart';
import '../meto_theme.dart';
import '../widgets/medical_info_card.dart';

/// Bilgi kütüphanesi tarzı: başlık → YouTube → kaynak → açıklama.
/// Admin: ekle / düzenle / sil / aktif-pasif.
class GelisimEtkinlikleriPage extends StatefulWidget {
  const GelisimEtkinlikleriPage({
    super.key,
    required this.adminEmail,
  });

  final String adminEmail;

  static Future<void> open(
    BuildContext context, {
    required String adminEmail,
  }) async {
    final gone = await isInfoCardDismissed(kDismissGelisimEtkinlikDisclaimer);
    if (!gone && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Sorumluluk Beyanı',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Bu etkinlikler ve videolar yalnızca bilgilendirme / gelişim '
            'desteği amaçlıdır; tıbbi teşhis veya tedavi yerine geçmez.\n\n'
            'Çocuğunuzun özel durumu için mutlaka hekim, fizyoterapist veya '
            'ilgili uzmana danışın. Uygulama klinik hizmet sunmaz.',
            style: GoogleFonts.nunito(fontSize: 14, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            TextButton(
              onPressed: () async {
                await dismissInfoCard(kDismissGelisimEtkinlikDisclaimer);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Bir daha gösterme'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: MetoColors.primary),
              child: const Text('Anladım'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GelisimEtkinlikleriPage(adminEmail: adminEmail),
      ),
    );
  }

  @override
  State<GelisimEtkinlikleriPage> createState() =>
      _GelisimEtkinlikleriPageState();
}

class _GelisimEtkinlikleriPageState extends State<GelisimEtkinlikleriPage> {
  List<GelisimEtkinlik> _all = const [];
  bool _loading = true;
  String? _error;
  String _q = '';
  String _yas = '';
  String _grup = '';
  String _zorluk = '';

  bool get _isAdmin => isAppAdmin(widget.adminEmail);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await loadGelisimEtkinlikleri(includeInactive: _isAdmin);
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
        if (list.isEmpty) {
          _error =
              'Etkinlik yok. Admin iseniz Supabase’de gelisim_etkinlikleri.sql çalıştırın veya + ile ekleyin.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  List<GelisimEtkinlik> get _filtered {
    final q = _q.trim().toLowerCase();
    return _all.where((a) {
      if (!_isAdmin && !a.isActive) return false;
      if (_yas.isNotEmpty && a.yas != _yas) return false;
      if (_grup.isNotEmpty && a.grup != _grup) return false;
      if (_zorluk.isNotEmpty && a.zorluk != _zorluk) return false;
      if (q.isEmpty) return true;
      final hay =
          '${a.title} ${a.description} ${a.kaynak} ${a.tip} ${a.grupAd}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  Future<void> _openEditor({GelisimEtkinlik? item}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GelisimEditorSheet(item: item),
    );
    if (ok == true) await _reload();
  }

  Future<void> _delete(GelisimEtkinlik item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Silinsin mi?',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: Text('"${item.title}" kalıcı silinecek.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await deleteGelisimEtkinlik(item.id);
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
    final items = _filtered;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: Text(
          'Gelişim Etkinlikleri',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              backgroundColor: MetoColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Blok ekle'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    hintText: 'Etkinlik ara…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: MetoColors.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                const MedicalInfoCard(
                  title: 'Sorumluluk beyanı',
                  body:
                      'Bu etkinlikler bilgilendirme amaçlıdır; tıbbi teşhis veya '
                      'tedavi yerine geçmez. Kararları uzmanınızla birlikte alın.',
                  icon: Icons.health_and_safety_outlined,
                  dismissKey: kDismissGelisimEtkinlikDisclaimer,
                  dismissLabel: 'Bir daha gösterme',
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        value: _yas,
                        hint: 'Yaş',
                        items: const {
                          '': 'Tümü',
                          '0-12ay': '0–12 ay',
                          '1-2yas': '1–2 yaş',
                          '2-3yas': '2–3 yaş',
                          '3-4yas': '3–4 yaş',
                          '4-6yas': '4–6 yaş',
                        },
                        onChanged: (v) => setState(() => _yas = v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _FilterDropdown(
                        value: _grup,
                        hint: 'Grup',
                        items: const {
                          '': 'Tümü',
                          'kaba-motor': 'Kaba Motor',
                          'ince-motor': 'İnce Motor',
                          'dil': 'Dil',
                          'bilissel': 'Bilişsel',
                          'sosyal': 'Sosyal',
                          'duyusal': 'Duyusal',
                          'ozbakim': 'Öz Bakım',
                        },
                        onChanged: (v) => setState(() => _grup = v),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _FilterDropdown(
                        value: _zorluk,
                        hint: 'Zorluk',
                        items: const {
                          '': 'Tümü',
                          'kolay': 'Kolay',
                          'orta': 'Orta',
                          'zor': 'Zor',
                        },
                        onChanged: (v) => setState(() => _zorluk = v),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${items.length} etkinlik',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null && items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 28),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          return _GelisimCard(
                            item: item,
                            isAdmin: _isAdmin,
                            onEdit: () => _openEditor(item: item),
                            onDelete: () => _delete(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final String hint;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: hint,
        filled: true,
        fillColor: MetoColors.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [
        for (final e in items.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (v) => onChanged(v ?? ''),
    );
  }
}

class _GelisimCard extends StatefulWidget {
  const _GelisimCard({
    required this.item,
    required this.isAdmin,
    required this.onEdit,
    required this.onDelete,
  });

  final GelisimEtkinlik item;
  final bool isAdmin;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_GelisimCard> createState() => _GelisimCardState();
}

class _GelisimCardState extends State<_GelisimCard> {
  var _play = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final videoId = item.youtubeId;

    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip(item.grupAd),
                      _chip(item.yasAd),
                      _chip(item.zorlukAd),
                    ],
                  ),
                ),
                if (widget.isAdmin)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') widget.onEdit();
                      if (v == 'delete') widget.onDelete();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
              ],
            ),
            if (!item.isActive)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Pasif (yalnızca admin görür)',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              item.title,
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: MetoColors.foreground,
              ),
            ),
            const SizedBox(height: 12),
            if (videoId == null)
              Container(
                height: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: MetoColors.muted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  widget.isAdmin
                      ? 'YouTube linki yok — Düzenle ile ekleyin'
                      : 'Video yakında',
                  style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                ),
              )
            else if (_play)
              InfoYoutubePlayer(youtubeUrlOrId: item.youtubeUrl)
            else
              Material(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _play = true),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          'https://img.youtube.com/vi/$videoId/hqdefault.jpg',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.black87,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.ondemand_video,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                        ),
                        Container(color: Colors.black38),
                        const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white,
                            size: 64,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (item.kaynak.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Kaynak: ${item.kaynak.trim()}',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                item.description,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  height: 1.45,
                  color: MetoColors.mutedFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (item.tip.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'İpucu: ${item.tip}',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MetoColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5EE),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: MetoColors.border),
        ),
        child: Text(
          t,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: MetoColors.primary,
          ),
        ),
      );
}

class _GelisimEditorSheet extends StatefulWidget {
  const _GelisimEditorSheet({this.item});
  final GelisimEtkinlik? item;

  @override
  State<_GelisimEditorSheet> createState() => _GelisimEditorSheetState();
}

class _GelisimEditorSheetState extends State<_GelisimEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _youtube;
  late final TextEditingController _kaynak;
  late final TextEditingController _desc;
  late final TextEditingController _tip;
  late bool _active;
  late String _grup;
  late String _yas;
  late String _zorluk;
  var _saving = false;

  static const _gruplar = {
    'kaba-motor': 'Kaba Motor',
    'ince-motor': 'İnce Motor',
    'dil': 'Dil ve İletişim',
    'bilissel': 'Bilişsel',
    'sosyal': 'Sosyal-Duygusal',
    'duyusal': 'Duyusal',
    'ozbakim': 'Öz Bakım',
  };
  static const _yaslar = {
    '0-12ay': '0–12 ay',
    '1-2yas': '1–2 yaş',
    '2-3yas': '2–3 yaş',
    '3-4yas': '3–4 yaş',
    '4-6yas': '4–6 yaş',
  };
  static const _zorluklar = {
    'kolay': 'Kolay',
    'orta': 'Orta',
    'zor': 'Zor',
  };

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final e = widget.item;
    _title = TextEditingController(text: e?.title ?? '');
    _youtube = TextEditingController(text: e?.youtubeUrl ?? '');
    _kaynak = TextEditingController(text: e?.kaynak ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _tip = TextEditingController(text: e?.tip ?? '');
    _active = e?.isActive ?? true;
    _grup = e?.grup ?? 'bilissel';
    _yas = e?.yas ?? '2-3yas';
    _zorluk = e?.zorluk ?? 'kolay';
  }

  @override
  void dispose() {
    _title.dispose();
    _youtube.dispose();
    _kaynak.dispose();
    _desc.dispose();
    _tip.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık gerekli.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await updateGelisimEtkinlik(
          id: widget.item!.id,
          title: title,
          description: _desc.text,
          youtubeUrl: _youtube.text,
          kaynak: _kaynak.text,
          tip: _tip.text,
          grup: _grup,
          grupAd: _gruplar[_grup] ?? _grup,
          yas: _yas,
          yasAd: _yaslar[_yas] ?? _yas,
          zorluk: _zorluk,
          zorlukAd: _zorluklar[_zorluk] ?? _zorluk,
          isActive: _active,
        );
      } else {
        await insertGelisimEtkinlik(
          title: title,
          description: _desc.text,
          youtubeUrl: _youtube.text,
          kaynak: _kaynak.text,
          tip: _tip.text,
          grup: _grup,
          grupAd: _gruplar[_grup] ?? _grup,
          yas: _yas,
          yasAd: _yaslar[_yas] ?? _yas,
          zorluk: _zorluk,
          zorlukAd: _zorluklar[_zorluk] ?? _zorluk,
          isActive: _active,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final msg = '$e';
      final missing = msg.contains('schema cache') ||
          msg.contains('does not exist') ||
          msg.contains('PGRST');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 7),
          content: Text(
            missing
                ? 'Tablo yok. Supabase SQL Editor’de gelisim_etkinlikleri.sql çalıştırın.\n$msg'
                : 'Kaydedilemedi: $msg',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MetoColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isEdit ? 'Etkinliği düzenle' : 'Yeni etkinlik',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sıra: başlık → YouTube → kaynak → açıklama (bilgi kütüphanesi gibi).',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  color: MetoColors.mutedFg,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: '1. Başlık',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _youtube,
                decoration: const InputDecoration(
                  labelText: '2. YouTube linki',
                  hintText: 'https://www.youtube.com/watch?v=...',
                  border: OutlineInputBorder(),
                  helperText: 'Video uygulamada gömülü oynar',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _kaynak,
                decoration: const InputDecoration(
                  labelText: '3. Kaynak',
                  hintText: 'örn. Pathways.org, Aile Bakanlığı',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: '4. Açıklama',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tip,
                decoration: const InputDecoration(
                  labelText: 'İpucu (isteğe bağlı)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _grup,
                decoration: const InputDecoration(
                  labelText: 'Grup',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final e in _gruplar.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _grup = v ?? _grup),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _yas,
                      decoration: const InputDecoration(
                        labelText: 'Yaş',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final e in _yaslar.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _yas = v ?? _yas),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _zorluk,
                      decoration: const InputDecoration(
                        labelText: 'Zorluk',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final e in _zorluklar.entries)
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _zorluk = v ?? _zorluk),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Aktif',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                ),
                value: _active,
                activeThumbColor: MetoColors.primary,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEdit ? 'Kaydet' : 'Ekle'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
