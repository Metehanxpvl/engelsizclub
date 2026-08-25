import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../admin_config.dart';
import '../condition_store.dart';
import '../data/condition_data.dart';
import '../data/diseases_data.dart';
import '../medical_disclaimer_store.dart';
import '../meto_theme.dart';
import '../services/catalog_adapters.dart';
import '../services/image_optimize_service.dart';
import '../services/r2_storage_service.dart';
import 'admin_disease_edit_sheet.dart';
import 'catalog_media.dart';
import 'medical_info_card.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';

/// Ana sayfa: Bilgi Kütüphanesi grid + admin CRUD / sürükle-bırak sıra.
class HastaliklarSection extends StatefulWidget {
  const HastaliklarSection({
    super.key,
    required this.userEmail,
    required this.onOpenDisease,
  });

  final String userEmail;
  final ValueChanged<DiseaseInfo> onOpenDisease;

  @override
  State<HastaliklarSection> createState() => _HastaliklarSectionState();
}

class _HastaliklarSectionState extends State<HastaliklarSection> {
  List<ConditionItem> _remote = const [];
  bool _loading = true;
  bool _tableReady = true;

  bool get _isAdmin => isAppAdmin(widget.userEmail);

  List<ConditionItem> get _activeSorted {
    final active = _remote.where((c) => c.isActive).toList()
      ..sort((a, b) {
        final o = a.sortOrder.compareTo(b.sortOrder);
        if (o != 0) return o;
        return b.createdAt.compareTo(a.createdAt);
      });
    return active;
  }

  /// Supabase `conditions` + henüz orada olmayan katalog kartları.
  /// (Eski davranış: tek remote kayıt gelince tüm katalog fallback kayboluyordu.)
  List<DiseaseInfo> get _displayDiseases {
    final catalog = CatalogAdapters.diseases();
    final active = _activeSorted;
    if (active.isEmpty) return catalog;

    bool covered(DiseaseInfo d) {
      for (final c in active) {
        final cid = c.catalogId.trim().toLowerCase();
        if (cid.isNotEmpty && cid == d.id.toLowerCase()) return true;
        if (c.title.trim().toLowerCase() == d.name.trim().toLowerCase()) {
          return true;
        }
      }
      return false;
    }

    return [
      for (final c in active)
        c.toDiseaseInfo(enrichFrom: _matchCatalog(c, catalog)),
      for (final d in catalog)
        if (!covered(d)) d,
    ];
  }

  DiseaseInfo? _matchCatalog(ConditionItem c, List<DiseaseInfo> catalog) {
    final cid = c.catalogId.trim().toLowerCase();
    if (cid.isNotEmpty) {
      for (final d in catalog) {
        if (d.id.toLowerCase() == cid) return d;
      }
    }
    final title = c.title.trim().toLowerCase();
    for (final d in catalog) {
      if (d.name.trim().toLowerCase() == title) return d;
      if (title.contains(d.name.trim().toLowerCase()) ||
          d.name.trim().toLowerCase().contains(title)) {
        return d;
      }
    }
    return null;
  }

  ConditionItem? _conditionForDisease(DiseaseInfo d) {
    if (d.id.startsWith('cond_')) {
      final id = int.tryParse(d.id.substring(5));
      if (id == null) return null;
      for (final c in _remote) {
        if (c.id == id) return c;
      }
    }
    for (final c in _remote) {
      if (c.catalogId.trim() == d.id) return c;
      if (c.title.trim().toLowerCase() == d.name.trim().toLowerCase()) {
        return c;
      }
    }
    return null;
  }

  Future<void> _editDiseaseCard(DiseaseInfo d) async {
    final cond = _conditionForDisease(d);
    if (cond != null) {
      await _openForm(edit: cond);
      return;
    }
    final result = await showModalBottomSheet<DiseaseInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AdminDiseaseEditSheet(disease: d),
    );
    if (result == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: L10nText('Kart kaydedildi.')),
    );
    setState(() {}    );
  }

  @override
  void initState() {
    super.initState();
    final cached = cachedConditions;
    if (cached != null) {
      _remote = cached;
      _loading = false;
    }
    _reload(silent: cached != null);
  }

  Future<void> _reload({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      var items = await loadConditions(
        forceRefresh: !hasFreshConditionCache,
        viewerEmail: widget.userEmail,
      );
      // Admin: katalog kutularını conditions'a yaz ki kaybolmasın / sürükle-bırak olsun.
      if (_isAdmin) {
        try {
          items = await ensureCatalogConditionsSeeded(
            adminEmail: widget.userEmail,
            catalog: CatalogAdapters.diseases(),
          );
        } catch (_) {
          // Tablo yoksa veya yetki yoksa sadece merge display ile devam.
        }
      }
      if (!mounted) return;
      setState(() {
        _remote = items;
        _tableReady = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _tableReady = false;
        _loading = false;
      });
    }
  }

  Future<void> _openForm({ConditionItem? edit}) async {
    if (edit == null && _isAdmin) {
      try {
        final seeded = await ensureCatalogConditionsSeeded(
          adminEmail: widget.userEmail,
          catalog: CatalogAdapters.diseases(),
        );
        if (mounted) setState(() => _remote = seeded);
      } catch (_) {}
    }
    var draft = edit;
    if (draft != null) {
      final enrich = _matchCatalog(draft, CatalogAdapters.diseases());
      if (enrich != null) {
        draft = draft.copyWith(
          catalogId:
              draft.catalogId.trim().isEmpty ? enrich.id : draft.catalogId,
          icon: draft.icon.trim().isEmpty || draft.icon == '🩺'
              ? enrich.icon
              : draft.icon,
          description: draft.description.trim().isEmpty
              ? enrich.desc
              : draft.description,
          symptoms:
              draft.symptoms.isEmpty ? enrich.symptoms : draft.symptoms,
          diagnosis: draft.diagnosis.trim().isEmpty
              ? enrich.diagnosis
              : draft.diagnosis,
          support: draft.support.isEmpty ? enrich.support : draft.support,
          faq: draft.faq.isEmpty ? enrich.faq : draft.faq,
          imageUrl: draft.imageUrl.trim().isEmpty
              ? (enrich.photo ?? '')
              : draft.imageUrl,
        );
      }
    }
    final result = await showModalBottomSheet<ConditionItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminConditionSheet(
        adminEmail: widget.userEmail,
        edit: draft,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      final rest = _remote.where((c) => c.id != result.id).toList();
      final next = [...rest, result]
        ..sort((a, b) {
          final o = a.sortOrder.compareTo(b.sortOrder);
          if (o != 0) return o;
          return b.createdAt.compareTo(a.createdAt);
        });
      _remote = next;
    });
  }

  Future<void> _openManage() async {
    try {
      final seeded = await ensureCatalogConditionsSeeded(
        adminEmail: widget.userEmail,
        catalog: CatalogAdapters.diseases(),
      );
      if (!mounted) return;
      setState(() => _remote = seeded);
    } catch (_) {
      final all = await loadConditions(
        forceRefresh: true,
        viewerEmail: widget.userEmail,
      );
      if (!mounted) return;
      setState(() => _remote = all);
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AdminConditionManageSheet(
        items: List<ConditionItem>.from(_remote),
        onChanged: (next) {
          if (!mounted) return;
          setState(() => _remote = next);
        },
        onAdd: () async {
          Navigator.pop(ctx);
          await _openForm();
        },
        onEdit: (item) async {
          Navigator.pop(ctx);
          await _openForm(edit: item);
        },
        onDelete: (item) async {
          await deleteCondition(item.id);
          if (!mounted) return;
          setState(() {
            _remote = _remote.where((c) => c.id != item.id).toList();
          });
        },
        onToggleActive: (item) async {
          final updated = await updateCondition(
            id: item.id,
            title: item.title,
            imageUrl: item.imageUrl,
            description: item.description,
            isActive: !item.isActive,
            sortOrder: item.sortOrder,
          );
          if (!mounted) return;
          setState(() {
            _remote = [
              for (final c in _remote)
                if (c.id == updated.id) updated else c,
            ];
          });
        },
        onReorderSaved: (ordered) async {
          await reorderConditions(ordered);
          if (!mounted) return;
          setState(() {
            final byId = {for (final c in ordered) c.id: c};
            _remote = [
              for (final c in _remote) byId[c.id] ?? c,
            ];
          });
        },
      ),
    );
    await _reload(silent: true);
  }

  /// Ana sayfa grid'i kaydırılabilir kalır; sıra değiştirme Yönet sayfasında.
  Widget _buildStaticGrid(List<DiseaseInfo> diseases) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: diseases.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, i) {
        final d = diseases[i];
        return _ConditionCard(
          disease: d,
          onTap: () => widget.onOpenDisease(d),
          onEdit: _isAdmin ? () => _editDiseaseCard(d) : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final diseases = _displayDiseases;
    final active = _activeSorted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: L10nText(
                  'Bilgi Kütüphanesi',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              if (_isAdmin) ...[
                IconButton(
                  tooltip: S.auto('Yönet'),
                  onPressed: _openManage,
                  style: IconButton.styleFrom(
                    backgroundColor: MetoColors.primary.withValues(alpha: 0.1),
                    foregroundColor: MetoColors.primary,
                  ),
                  icon: const Icon(Icons.tune, size: 20),
                ),
                IconButton(
                  tooltip: S.auto('Yeni durum kartı ekle'),
                  onPressed: () => _openForm(),
                  style: IconButton.styleFrom(
                    backgroundColor: MetoColors.primary.withValues(alpha: 0.1),
                    foregroundColor: MetoColors.primary,
                  ),
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          const MedicalInfoCard(
            title: 'Bilgilendirme',
            body:
                'Bu bölüm yalnızca bilgilendirme amaçlıdır. İçerikler klinik hizmet veya tavsiye niteliğinde değildir.',
            icon: Icons.menu_book_outlined,
            dismissKey: kDismissLibraryInfo,
          ),
          if (_isAdmin && active.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: L10nText(
                'Sırayı değiştirmek için Yönet’e dokunun',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: MetoColors.mutedFg,
                ),
              ),
            ),
          if (_isAdmin && !_tableReady)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Tablo yoksa conditions.sql dosyasını Supabase’te çalıştırın.',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  color: MetoColors.mutedFg,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (_loading && diseases.isEmpty)
            const SizedBox(
              height: 120,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            _buildStaticGrid(diseases),
        ],
      ),
    );
  }
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({
    super.key,
    required this.disease,
    required this.onTap,
    this.onEdit,
  });

  final DiseaseInfo disease;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MetoColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  if (disease.photo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 10,
                        child: CatalogImage(
                          source: disease.photo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: disease.bg,
                            alignment: Alignment.center,
                            child: Text(
                              disease.icon,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: disease.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        disease.icon,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  if (onEdit != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onEdit,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: MetoColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              L10nText(
                disease.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: L10nText(
                  disease.desc,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: MetoColors.mutedFg,
                    height: 1.3,
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

class _AdminConditionSheet extends StatefulWidget {
  const _AdminConditionSheet({
    required this.adminEmail,
    this.edit,
  });

  final String adminEmail;
  final ConditionItem? edit;

  @override
  State<_AdminConditionSheet> createState() => _AdminConditionSheetState();
}

class _AdminConditionSheetState extends State<_AdminConditionSheet> {
  late final TextEditingController _title;
  late final TextEditingController _imageUrl;
  late final TextEditingController _description;
  late final TextEditingController _icon;
  late final TextEditingController _catalogId;
  late final TextEditingController _symptoms;
  late final TextEditingController _diagnosis;
  late final TextEditingController _support;
  late final TextEditingController _faq;
  Uint8List? _pickedBytes;
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.edit != null && widget.edit!.id > 0;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _title = TextEditingController(text: e?.title ?? '');
    _imageUrl = TextEditingController(text: e?.imageUrl ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _icon = TextEditingController(text: e?.icon ?? '🩺');
    _catalogId = TextEditingController(text: e?.catalogId ?? '');
    _symptoms = TextEditingController(text: (e?.symptoms ?? const []).join('\n'));
    _diagnosis = TextEditingController(text: e?.diagnosis ?? '');
    _support = TextEditingController(text: (e?.support ?? const []).join('\n'));
    _faq = TextEditingController(
      text: [
        for (final f in e?.faq ?? const <FaqItem>[]) '${f.q} | ${f.a}',
      ].join('\n'),
    );
    _isActive = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _imageUrl.dispose();
    _description.dispose();
    _icon.dispose();
    _catalogId.dispose();
    _symptoms.dispose();
    _diagnosis.dispose();
    _support.dispose();
    _faq.dispose();
    super.dispose();
  }

  List<String> _lines(String raw) => raw
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<FaqItem> _parseFaq(String raw) {
    final out = <FaqItem>[];
    for (final line in _lines(raw)) {
      final parts = line.split('|');
      if (parts.length < 2) continue;
      final q = parts.first.trim();
      final a = parts.sublist(1).join('|').trim();
      if (q.isNotEmpty) out.add(FaqItem(q, a));
    }
    return out;
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _imageUrl.clear();
    });
  }

  Future<String> _resolveImagePayload() async {
    if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
      final optimized = await ImageOptimizeService.forCatalogCard(_pickedBytes!);
      return R2StorageService.uploadBytes(
        bytes: optimized.bytes,
        fileName: optimized.fileName,
        contentType: optimized.contentType,
      );
    }
    return _imageUrl.text.trim();
  }

  /// Video “Daha fazlası” kategorisi için sabit anahtar.
  String _slugFromTitle(String title) {
    var s = title.trim().toLowerCase();
    const map = {
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    map.forEach((k, v) => s = s.replaceAll(k, v));
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    s = s.replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty) s = 'yeni_konu';
    if (s.length > 48) s = s.substring(0, 48);
    return s;
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Başlık gerekli.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final image = await _resolveImagePayload();
      final desc = _description.text.trim();
      final symptoms = _lines(_symptoms.text);
      final diagnosis = _diagnosis.text.trim();
      final support = _lines(_support.text);
      final faq = _parseFaq(_faq.text);
      final icon = _icon.text.trim().isEmpty ? '🩺' : _icon.text.trim();
      var catalogId = _catalogId.text.trim();
      if (catalogId.isEmpty) {
        catalogId = _slugFromTitle(title);
      }
      final ConditionItem item;
      if (_isEdit) {
        item = await updateCondition(
          id: widget.edit!.id,
          title: title,
          imageUrl: image,
          description: desc,
          isActive: _isActive,
          sortOrder: widget.edit!.sortOrder,
          catalogId: catalogId,
          icon: icon,
          symptoms: symptoms,
          diagnosis: diagnosis,
          support: support,
          faq: faq,
        );
      } else {
        item = await addCondition(
          title: title,
          imageUrl: image,
          description: desc,
          adminEmail: widget.adminEmail,
          isActive: _isActive,
          catalogId: catalogId,
          icon: icon,
          symptoms: symptoms,
          diagnosis: diagnosis,
          support: support,
          faq: faq,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(item);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('conditions') ||
                    e.toString().contains('PGRST') ||
                    e.toString().contains('schema') ||
                    e.toString().contains('column')
                ? 'Tablo/kolon eksik. conditions.sql ve conditions_detail.sql çalıştırın.'
                : 'Kaydedilemedi: $e',
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: MetoColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: MetoColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _isEdit ? 'Kartı ve detayı düzenle' : 'Yeni durum kartı',
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    L10nText(
                      'Kart',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 72,
                            height: 72,
                            child: _pickedBytes != null
                                ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
                                : (_imageUrl.text.trim().isNotEmpty
                                    ? CatalogImage(
                                        source: _imageUrl.text.trim(),
                                        fit: BoxFit.cover,
                                      )
                                    : ColoredBox(
                                        color: MetoColors.muted,
                                        child: const Icon(
                                          Icons.image_outlined,
                                          color: MetoColors.primary,
                                        ),
                                      )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _pickImage,
                            icon: const Icon(Icons.photo_library_outlined,
                                size: 18),
                            label: const L10nText('Galeriden yükle'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _imageUrl,
                      enabled: !_saving && _pickedBytes == null,
                      decoration: InputDecoration(
                        hintText: S.auto('veya görsel URL / asset yolu'),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _title,
                      enabled: !_saving,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: S.auto('Başlık'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _icon,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: S.auto('İkon (emoji)'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _description,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: S.auto('Kısa açıklama (kart)'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    L10nText(
                      'Detay içeriği',
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _symptoms,
                      enabled: !_saving,
                      minLines: 4,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: S.auto('Belirtiler (her satır bir madde)'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _diagnosis,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: S.auto('Değerlendirme bilgisi'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _support,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: S.auto('Destek yolları (her satır bir madde)'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _faq,
                      enabled: !_saving,
                      minLines: 3,
                      maxLines: 8,
                      decoration: InputDecoration(
                        labelText: S.auto('SSS (satır: soru | cevap)'),
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _catalogId,
                      enabled: !_saving,
                      decoration: InputDecoration(
                        labelText: S.auto(
                          'Katalog id (video kategorisi, örn. otizm)',
                        ),
                        helperText: S.auto(
                          'Boş bırakırsan başlıktan üretilir. Detayda “Bilgilendirici Videolar İçin Tıklayınız” ile video eklenir.',
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: L10nText(
                        'Aktif',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: L10nText(
                        'Kapalıysa ana sayfada görünmez.',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                      value: _isActive,
                      activeThumbColor: MetoColors.primary,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _isActive = v),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
                    : Text(
                        _isEdit ? 'Kaydet' : 'Ekle',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminConditionManageSheet extends StatefulWidget {
  const _AdminConditionManageSheet({
    required this.items,
    required this.onChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
    required this.onReorderSaved,
  });

  final List<ConditionItem> items;
  final ValueChanged<List<ConditionItem>> onChanged;
  final VoidCallback onAdd;
  final ValueChanged<ConditionItem> onEdit;
  final Future<void> Function(ConditionItem item) onDelete;
  final Future<void> Function(ConditionItem item) onToggleActive;
  final Future<void> Function(List<ConditionItem> ordered) onReorderSaved;

  @override
  State<_AdminConditionManageSheet> createState() =>
      _AdminConditionManageSheetState();
}

class _AdminConditionManageSheetState extends State<_AdminConditionManageSheet> {
  late List<ConditionItem> _items;
  int? _busyId;
  bool _savingOrder = false;

  @override
  void initState() {
    super.initState();
    _items = List<ConditionItem>.from(widget.items)
      ..sort((a, b) {
        final o = a.sortOrder.compareTo(b.sortOrder);
        if (o != 0) return o;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  void _emit(List<ConditionItem> next) {
    setState(() => _items = next);
    widget.onChanged(next);
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (_savingOrder || oldIndex == newIndex) return;
    setState(() {
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _items = [
        for (var i = 0; i < _items.length; i++)
          _items[i].copyWith(sortOrder: i),
      ];
      _savingOrder = true;
    });
    widget.onChanged(_items);
    try {
      await widget.onReorderSaved(_items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Sıra kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _savingOrder = false);
    }
  }

  Future<void> _toggle(ConditionItem item) async {
    setState(() => _busyId = item.id);
    try {
      await widget.onToggleActive(item);
      _emit([
        for (final c in _items)
          if (c.id == item.id) c.copyWith(isActive: !c.isActive) else c,
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Güncellenemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(ConditionItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: L10nText(
          'Kartı sil?',
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
    setState(() => _busyId = item.id);
    try {
      await widget.onDelete(item);
      _emit(_items.where((c) => c.id != item.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: L10nText('Silinemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      height: h,
      decoration: const BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: MetoColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      L10nText(
                        'Durum kartı yönetimi',
                        style: GoogleFonts.nunito(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: MetoColors.foreground,
                        ),
                      ),
                      L10nText(
                        'Sürükleyerek sırayı değiştirin',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_savingOrder)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                TextButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const L10nText('Ekle'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: L10nText(
                        'Henüz kayıt yok.\nEkle ile yeni kart oluşturun.\n(Boşken ana sayfa yerel kataloğu gösterir.)',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                      ),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _items.length,
                    buildDefaultDragHandles: false,
                    onReorderItem: _onReorder,
                    itemBuilder: (context, i) {
                      final item = _items[i];
                      final busy = _busyId == item.id;
                      return Padding(
                        key: ValueKey('manage_${item.id}'),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: MetoColors.background,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: i,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Icon(
                                      Icons.drag_handle,
                                      color: MetoColors.mutedFg,
                                    ),
                                  ),
                                ),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: item.imageUrl.trim().isEmpty
                                        ? ColoredBox(
                                            color: MetoColors.muted,
                                            child: const Icon(
                                              Icons.medical_services_outlined,
                                              color: MetoColors.primary,
                                            ),
                                          )
                                        : CatalogImage(
                                            source: item.imageUrl,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      L10nText(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.nunito(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        item.isActive ? 'Aktif' : 'Pasif',
                                        style: GoogleFonts.nunito(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: item.isActive
                                              ? MetoColors.primary
                                              : MetoColors.mutedFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (busy)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else ...[
                                  IconButton(
                                    tooltip: item.isActive
                                        ? 'Pasife al'
                                        : 'Aktif et',
                                    onPressed: () => _toggle(item),
                                    icon: Icon(
                                      item.isActive
                                          ? Icons.visibility
                                          : Icons.visibility_off_outlined,
                                      color: item.isActive
                                          ? MetoColors.primary
                                          : MetoColors.mutedFg,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: S.auto('Düzenle'),
                                    onPressed: () => widget.onEdit(item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: S.auto('Sil'),
                                    onPressed: () => _delete(item),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFDC2626),
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
        ],
      ),
    );
  }
}
