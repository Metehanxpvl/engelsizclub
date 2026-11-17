import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../admin_config.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import '../uzman_kosesi/expert_cv_models.dart';
import '../uzman_kosesi/expert_cv_store.dart';
import 'uzman_kosesi_cv_detail_page.dart';

class AdminUzmanCvPage extends StatefulWidget {
  const AdminUzmanCvPage({super.key, required this.adminEmail});

  final String adminEmail;

  static Future<void> open(BuildContext context, {required String adminEmail}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminUzmanCvPage(adminEmail: adminEmail),
      ),
    );
  }

  @override
  State<AdminUzmanCvPage> createState() => _AdminUzmanCvPageState();
}

class _AdminUzmanCvPageState extends State<AdminUzmanCvPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  List<ExpertCvProfile> _pending = const [];
  List<ExpertCvProfile> _published = const [];
  List<MeslekGrubu> _gruplar = const [];
  List<MeslekAlanSablon> _sablon = const [];
  int? _grupId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _boot();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    if (!isAppAdmin(widget.adminEmail)) {
      setState(() => _loading = false);
      return;
    }
    final pending = await loadPendingExpertProfiles();
    final published = await loadPublishedExpertProfiles();
    final gruplar = await loadMeslekGruplari(includeInactive: true);
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _published = published;
      _gruplar = gruplar;
      _loading = false;
    });
  }

  Future<void> _loadSablon(int id) async {
    final s = await loadMeslekAlanSablonlari(
      meslekGrubuId: id,
      includeInactive: true,
    );
    if (!mounted) return;
    setState(() {
      _grupId = id;
      _sablon = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!isAppAdmin(widget.adminEmail)) {
      return const Scaffold(
        body: Center(child: L10nText('Bu sayfa yalnızca yöneticiler içindir.')),
      );
    }
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        title: L10nText(
          'Uzman Onayları',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Bekleyenler'),
            Tab(text: 'Yayınlananlar'),
            Tab(text: 'Şablonlar'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _pendingTab(),
                _publishedTab(),
                _sablonTab(),
              ],
            ),
    );
  }

  Widget _pendingTab() {
    if (_pending.isEmpty) {
      return const Center(child: L10nText('Bekleyen profil yok'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _pending.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final p = _pending[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('${p.meslekEtiket} · ${p.yerLabel}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  children: [
                    TextButton(
                      onPressed: () => UzmanKosesCvDetailPage.open(
                        context,
                        profileId: p.id,
                        userEmail: widget.adminEmail,
                      ),
                      child: const Text('İncele'),
                    ),
                    TextButton(
                      onPressed: () => _uploadAdminDoc(p, 'kimlik_dogrulama'),
                      child: const Text('Kimlik'),
                    ),
                    TextButton(
                      onPressed: () => _uploadAdminDoc(p, 'adli_sicil'),
                      child: const Text('Adli sicil'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await adminReviewExpertProfile(
                          id: p.id,
                          approve: true,
                          dogrulandi: true,
                        );
                        await _boot();
                      },
                      child: const Text('Onayla + doğrula'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await adminReviewExpertProfile(
                          id: p.id,
                          approve: true,
                        );
                        await _boot();
                      },
                      child: const Text('Onayla'),
                    ),
                    TextButton(
                      onPressed: () async {
                        final reason = await _askReason();
                        if (reason == null) return;
                        await adminReviewExpertProfile(
                          id: p.id,
                          approve: false,
                          reason: reason,
                        );
                        await _boot();
                      },
                      child: const Text('Reddet'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _publishedTab() {
    if (_published.isEmpty) {
      return const Center(child: L10nText('Yayınlanan profil yok'));
    }
    final list = List<ExpertCvProfile>.from(_published)
      ..sort((a, b) {
        final ad = uzmanProfilYayindaGun(b).compareTo(uzmanProfilYayindaGun(a));
        if (ad != 0) return ad;
        return a.fullName.compareTo(b.fullName);
      });
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (ctx, i) {
        final p = list[i];
        final odeme = uzmanProfilOdemeOzeti(p);
        final paid = p.puanOdedi;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text('${p.meslekEtiket} · ${p.yerLabel}'),
                if (p.ownerEmail.isNotEmpty)
                  Text(
                    p.ownerEmail,
                    style: const TextStyle(
                      fontSize: 12,
                      color: MetoColors.mutedFg,
                    ),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _infoChip(
                      uzmanProfilYayindaOzet(p),
                      Icons.schedule,
                    ),
                    _infoChip(
                      p.tamSatir ? 'Tam satır' : '1 kutu',
                      Icons.grid_view,
                    ),
                    _infoChip(
                      odeme,
                      paid ? Icons.payments_outlined : Icons.money_off_outlined,
                      color: paid
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFD97706),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => UzmanKosesCvDetailPage.open(
                      context,
                      profileId: p.id,
                      userEmail: widget.adminEmail,
                    ),
                    child: const Text('İncele'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoChip(String label, IconData icon, {Color? color}) {
    final c = color ?? MetoColors.primary;
    return Chip(
      avatar: Icon(icon, size: 16, color: c),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: c.withValues(alpha: 0.35)),
    );
  }

  Future<String?> _askReason() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Red sebebi'),
        content: TextField(controller: c, maxLines: 3),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    final t = c.text.trim();
    c.dispose();
    if (ok == true && t.length >= 3) return t;
    return null;
  }

  Widget _sablonTab() {
    final saglik = _gruplar.where((g) => g.ustGrup == 'Sağlık Uzmanları');
    final bakim = _gruplar.where((g) => g.ustGrup == 'Bakım ve Ev Desteği');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const L10nText('Meslek grubu'),
        const SizedBox(height: 8),
        const L10nText(
          'Sağlık Uzmanları',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addSaglikMeslegi,
            icon: const Icon(Icons.add),
            label: const Text('Sağlık mesleği ekle'),
          ),
        ),
        for (final g in saglik)
          ListTile(
            title: Text(g.etiket),
            subtitle: Text(g.ustGrup),
            selected: _grupId == g.id,
            onTap: () => _loadSablon(g.id),
          ),
        const SizedBox(height: 8),
        const L10nText(
          'Bakım ve Ev Desteği',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        for (final g in bakim)
          ListTile(
            title: Text(g.etiket),
            subtitle: Text(g.ustGrup),
            selected: _grupId == g.id,
            onTap: () => _loadSablon(g.id),
          ),
        const Divider(),
        if (_grupId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _editSablon(),
              icon: const Icon(Icons.add),
              label: const Text('Alan ekle'),
            ),
          ),
        for (final s in _sablon)
          SwitchListTile(
            title: Text(s.etiket),
            subtitle: Text(
              '${s.tip} · ${s.alanKey}${s.zorunlu ? ' · zorunlu' : ''}'
              '${s.aktif ? '' : ' · pasif'}',
            ),
            value: s.aktif,
            onChanged: (v) async {
              await setMeslekAlanAktif(id: s.id, aktif: v);
              if (_grupId != null) await _loadSablon(_grupId!);
            },
            secondary: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editSablon(existing: s),
            ),
          ),
      ],
    );
  }

  Future<void> _addSaglikMeslegi() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sağlık mesleği ekle'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Meslek adı',
            hintText: 'Örn. Diyetisyen',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    final name = c.text.trim();
    c.dispose();
    if (ok != true || name.isEmpty) return;
    try {
      final created = await insertMeslekGrubu(
        etiket: name,
        ustGrup: kMeslekUstSaglik,
        sira: nextMeslekGrubuSira(_gruplar, kMeslekUstSaglik),
      );
      await _boot();
      if (!mounted) return;
      await _loadSablon(created.id);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$name eklendi. İstersen bu mesleğe özel alan ekleyebilirsin.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Bad state: ', '').replaceFirst('StateError: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> _uploadAdminDoc(ExpertCvProfile p, String alanKey) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final raw = await file.readAsBytes();
    final opt = await ImageOptimizeService.forListing(raw);
    final url = await R2StorageService.uploadBytes(
      bytes: opt.bytes,
      fileName:
          'expert_${alanKey}_${p.id}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      contentType: opt.contentType,
    );
    await saveExpertFile(
      profileId: p.id,
      ownerId: p.ownerId,
      alanKey: alanKey,
      fileUrl: url,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          alanKey == 'adli_sicil'
              ? 'Adli sicil belgesi kaydedildi (yalnız admin/sahip).'
              : 'Kimlik belgesi kaydedildi (yalnız admin/sahip).',
        ),
      ),
    );
  }

  Future<void> _editSablon({MeslekAlanSablon? existing}) async {
    final grupId = _grupId;
    if (grupId == null) return;
    final etiket = TextEditingController(text: existing?.etiket ?? '');
    final key = TextEditingController(text: existing?.alanKey ?? '');
    final secenek = TextEditingController(
      text: (existing?.secenekler ?? const []).join(', '),
    );
    final sira = TextEditingController(
      text: (existing?.sira ?? ((_sablon.length + 1) * 10)).toString(),
    );
    var tip = existing?.tip ?? 'text';
    var zorunlu = existing?.zorunlu ?? false;
    const tips = [
      'text',
      'textarea',
      'number',
      'select',
      'multi_select',
      'boolean',
      'file',
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Alan ekle' : 'Alanı düzenle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: etiket,
                  decoration: const InputDecoration(labelText: 'Etiket'),
                ),
                TextField(
                  controller: key,
                  enabled: existing == null,
                  decoration: const InputDecoration(
                    labelText: 'alan_key (eski cevaplar silinmez)',
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: tip,
                  decoration: const InputDecoration(labelText: 'Tip'),
                  items: [
                    for (final t in tips)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) {
                    if (v != null) setLocal(() => tip = v);
                  },
                ),
                TextField(
                  controller: secenek,
                  decoration: const InputDecoration(
                    labelText: 'Seçenekler (virgülle)',
                  ),
                ),
                TextField(
                  controller: sira,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sıra'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Zorunlu'),
                  value: zorunlu,
                  onChanged: (v) => setLocal(() => zorunlu = v),
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
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    final label = etiket.text.trim();
    var alanKey = key.text.trim();
    final secenekText = secenek.text;
    final siraText = sira.text.trim();
    if (alanKey.isEmpty) {
      alanKey = label
          .toLowerCase()
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c')
          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
    }
    etiket.dispose();
    key.dispose();
    secenek.dispose();
    sira.dispose();
    if (ok != true || label.isEmpty || alanKey.isEmpty) return;
    final opts = [
      for (final p in secenekText.split(','))
        if (p.trim().isNotEmpty) p.trim(),
    ];
    await upsertMeslekAlanSablon(
      MeslekAlanSablon(
        id: existing?.id ?? 0,
        meslekGrubuId: grupId,
        alanKey: existing?.alanKey ?? alanKey,
        etiket: label,
        tip: tip,
        secenekler: opts,
        zorunlu: zorunlu,
        sira: int.tryParse(siraText) ?? 0,
        aktif: existing?.aktif ?? true,
      ),
    );
    await _loadSablon(grupId);
  }
}
