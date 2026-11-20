import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../admin_config.dart';
import '../../l10n/l10n_text.dart';
import '../../meto_theme.dart';
import '../../services/image_optimize_service.dart';
import '../../services/r2_storage_service.dart';
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
  String _kategori = _kTumu;
  bool _topluRet = false;

  /// Benzer başlıklı haberler tek kartta: ilk eleman gösterilen haberdir.
  List<List<DailyNewsCandidate>> get _gruplar => benzerHaberGruplari(_gorunen);

  Future<void> _benzerleriReddet(List<DailyNewsCandidate> liste) async {
    if (_topluRet || liste.isEmpty) return;
    setState(() => _topluRet = true);
    var hata = 0;
    final silinen = <String>{};
    for (final e in liste) {
      try {
        await _repo.reject(e.id);
        silinen.add(e.id);
      } catch (_) {
        hata++;
      }
    }
    if (!mounted) return;
    setState(() {
      _items = [for (final e in _items) if (!silinen.contains(e.id)) e];
      _topluRet = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          hata == 0
              ? '${silinen.length} benzer haber reddedildi.'
              : '${silinen.length} reddedildi, $hata reddedilemedi.',
        ),
      ),
    );
  }

  List<DailyNewsCandidate> get _gorunen => _kategori == _kTumu
      ? _items
      : [for (final e in _items) if (haberKategorileri(e).contains(_kategori)) e];

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
    final result = await showDialog<_NewsEditResult>(
      context: context,
      builder: (_) => _NewsEditDialog(item: item),
    );
    if (result == null || !mounted) return;
    setState(() => _busyId = item.id);
    try {
      await _repo.updateDraft(
        id: item.id,
        title: result.title,
        summary: result.summary,
        imageUrl: result.imageUrl,
      );
      if (!mounted) return;
      setState(() {
        _items = [
          for (final e in _items)
            if (e.id == item.id)
              e.copyWith(
                title: result.title,
                summary: result.summary,
                imageUrl: result.imageUrl,
              )
            else
              e,
        ];
        _busyId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: L10nText('Haber kaydedildi.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaydedilemedi: $e'.replaceFirst('Bad state: ', '')),
        ),
      );
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
                      : Column(
                          children: [
                            _KategoriSeridi(
                              items: _items,
                              secili: _kategori,
                              onSec: (k) => setState(() => _kategori = k),
                            ),
                            Expanded(
                              child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: _gruplar.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final grup = _gruplar[i];
                            final item = grup.first;
                            final kart = _NewsCandidateCard(
                              item: item,
                              busy: _busyId == item.id,
                              onEdit: () => _edit(item),
                              onApprove: () => _approve(item),
                              onReject: () => _reject(item),
                            );
                            if (grup.length == 1) return kart;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                kart,
                                _BenzerHaberler(
                                  benzerler: grup.sublist(1),
                                  busy: _topluRet,
                                  onHepsiniReddet: () =>
                                      _benzerleriReddet(grup.sublist(1)),
                                ),
                              ],
                            );
                          },
                        ),
                            ),
                          ],
                        ),
    );
  }
}

class _NewsEditResult {
  const _NewsEditResult({
    required this.title,
    required this.summary,
    required this.imageUrl,
  });

  final String title;
  final String summary;
  final String imageUrl;
}

class _NewsEditDialog extends StatefulWidget {
  const _NewsEditDialog({required this.item});

  final DailyNewsCandidate item;

  @override
  State<_NewsEditDialog> createState() => _NewsEditDialogState();
}

class _NewsEditDialogState extends State<_NewsEditDialog> {
  late final TextEditingController _title;
  late final TextEditingController _summary;
  late final TextEditingController _imageUrl;
  Uint8List? _pickedBytes;
  var _uploading = false;
  var _clearedImage = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item.title);
    _summary = TextEditingController(text: widget.item.summary);
    _imageUrl = TextEditingController(text: widget.item.imageUrl);
  }

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _imageUrl.dispose();
    super.dispose();
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
      _clearedImage = false;
      _imageUrl.clear();
    });
  }

  Future<String> _resolveImage() async {
    if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
      setState(() => _uploading = true);
      try {
        final optimized =
            await ImageOptimizeService.forCatalogCard(_pickedBytes!);
        return R2StorageService.uploadBytes(
          bytes: optimized.bytes,
          fileName: 'haber_${DateTime.now().millisecondsSinceEpoch}.jpg',
          contentType: optimized.contentType,
        );
      } finally {
        if (mounted) setState(() => _uploading = false);
      }
    }
    if (_clearedImage) return '';
    final typed = _imageUrl.text.trim();
    if (typed.isNotEmpty) return typed;
    return widget.item.imageUrl.trim();
  }

  Future<void> _save() async {
    if (_uploading) return;
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık boş olamaz.')),
      );
      return;
    }
    String image;
    try {
      image = await _resolveImage();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görsel yüklenemedi: $e')),
      );
      return;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      _NewsEditResult(
        title: title,
        summary: _summary.text.trim(),
        imageUrl: image.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final previewUrl = _imageUrl.text.trim();
    return AlertDialog(
      title: Text(
        'Haberi düzenle',
        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _summary,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'İçerik'),
            ),
            const SizedBox(height: 12),
            Text(
              'Görsel',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_pickedBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _pickedBytes!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else if (!_clearedImage && previewUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  previewUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _uploading ? null : _pickImage,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(
                    _pickedBytes == null && previewUrl.isEmpty
                        ? 'Görsel ekle'
                        : 'Görseli değiştir',
                  ),
                ),
                if (_pickedBytes != null ||
                    (!_clearedImage &&
                        (previewUrl.isNotEmpty ||
                            widget.item.imageUrl.isNotEmpty)))
                  TextButton(
                    onPressed: _uploading
                        ? null
                        : () => setState(() {
                              _pickedBytes = null;
                              _clearedImage = true;
                              _imageUrl.clear();
                            }),
                    child: const Text('Görseli kaldır'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _imageUrl,
              decoration: const InputDecoration(
                labelText: 'veya görsel bağlantısı',
              ),
              onChanged: (_) => setState(() {
                _pickedBytes = null;
                _clearedImage = _imageUrl.text.trim().isEmpty;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _uploading ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _uploading ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: MetoColors.primary),
          child: Text(_uploading ? 'Yükleniyor…' : 'Kaydet'),
        ),
      ],
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
          Text(
            item.title,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (item.collectedAtLabel.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Geldi: ${item.collectedAtLabel}',
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MetoColors.mutedFg,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            [
              item.sourceName,
              if (dateLabel.isNotEmpty) dateLabel,
              item.category,
              '${item.importanceLabelTr} · ${item.relevanceScore}',
            ].join('  ·  '),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MetoColors.mutedFg,
            ),
          ),
          if (item.imageUrl.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                item.imageUrl.trim(),
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          if (item.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.summary,
              style: GoogleFonts.nunito(fontSize: 13, height: 1.4),
            ),
          ],
          if (item.aiReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'AI: ${item.aiReason}',
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

const String _kTumu = 'Tümü';

/// Başlık + özetteki kelimelere göre haber kategorileri (birden fazla olabilir).
const Map<String, List<String>> _kHaberKategoriKelimeleri = {
  'Haklar ve destekler': [
    'hakk', 'hakları', 'hak ', 'maaş', 'aylık', 'ödeme', 'yasa', 'kanun', 'teklif', 'meclis\'e',
    'milletvekili', 'bakan', 'yardım', 'ötv', 'vergi', 'sgk', 'emekli',
    'indirim', 'muafiyet',
  ],
  'İş ve istihdam': [
    'istihdam', 'personel alım', 'kadro', 'kpss', 'ekpss', 'işe alım',
    'iş arayan', 'iş ilanı', 'çalışan', 'iş kur', 'işkur',
  ],
  'Eğitim': [
    'okul', 'öğrenci', 'öğretmen', 'eğitim', 'kaynaştırma', 'üniversite',
    'rehabilitasyon',
  ],
  'Sağlık': [
    'hastane', 'tedavi', 'ilaç', 'sağlık', 'doktor', 'hemşire', 'ameliyat',
    'otizm', 'down sendrom', 'serebral', 'spinal müsküler', 'hastalık',
  ],
  'Erişilebilirlik ve şehir': [
    'erişilebil', 'engelsiz', 'rampa', 'ulaşım', 'asansör', 'şehir',
    'kaldırım', 'otopark', 'afet', 'tahliye',
  ],
  'Etkinlik ve spor': [
    'spor', ' maç', 'maçı', 'festival', 'etkinlik', 'doğum günü', 'sinema', 'yarışma',
    'şampiyon', 'turnuva', 'konser', 'tiyatro', '3 aralık',
  ],
  'Dernek ve STK': [
    'dernek', 'platform', 'kent konseyi', 'engelliler meclisi', 'vakıf',
    'federasyon', 'ziyaret',
  ],
  'Asayiş ve kaza': [
    'kaza ', 'kazası', 'kazada', 'ölü bulundu', 'öldü', 'hayatını kaybetti', 'darp', 'yaralandı', 'saldırı', 'ihmal',
    'gözaltı', 'tutuklandı', 'çarptı',
  ],
};

String _trKucuk(String s) =>
    s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

/// [item] için eşleşen kategoriler; hiçbiri yoksa `Diğer`.
Set<String> haberKategorileri(DailyNewsCandidate item) {
  final metin = _trKucuk('${item.title} ${item.summary}');
  final out = <String>{};
  _kHaberKategoriKelimeleri.forEach((kategori, kelimeler) {
    for (final k in kelimeler) {
      if (metin.contains(k)) {
        out.add(kategori);
        break;
      }
    }
  });
  if (out.isEmpty) out.add('Diğer');
  return out;
}

class _KategoriSeridi extends StatelessWidget {
  const _KategoriSeridi({
    required this.items,
    required this.secili,
    required this.onSec,
  });

  final List<DailyNewsCandidate> items;
  final String secili;
  final ValueChanged<String> onSec;

  @override
  Widget build(BuildContext context) {
    final sayilar = <String, int>{};
    for (final e in items) {
      for (final k in haberKategorileri(e)) {
        sayilar[k] = (sayilar[k] ?? 0) + 1;
      }
    }
    final sira = [
      _kTumu,
      ..._kHaberKategoriKelimeleri.keys.where((k) => (sayilar[k] ?? 0) > 0),
      if ((sayilar['Diğer'] ?? 0) > 0) 'Diğer',
    ];
    if (!sira.contains(secili)) sira.add(secili);
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        itemCount: sira.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final k = sira[i];
          final n = k == _kTumu ? items.length : (sayilar[k] ?? 0);
          final aktif = k == secili;
          return ChoiceChip(
            label: Text(
              '$k ($n)',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: aktif ? Colors.white : MetoColors.foreground,
              ),
            ),
            selected: aktif,
            showCheckmark: false,
            selectedColor: MetoColors.primary,
            backgroundColor: MetoColors.card,
            side: BorderSide(
              color: aktif ? MetoColors.primary : MetoColors.border,
            ),
            onSelected: (_) => onSec(k),
          );
        },
      ),
    );
  }
}

const Set<String> _kBenzerDurak = {
  'engel', 'birey', 'için', 'olan', 'haber', 'gazet', 'ajans', 'ihlas',
  'dakik', 'günde', 'yeni', 'büyük', 'önemli', 'anlam',
};

/// Başlığı karşılaştırma için kelime köklerine (ilk 5 harf) çevirir.
Set<String> _baslikKokleri(String title) {
  var t = title;
  final tire = t.lastIndexOf(' - ');
  if (tire > 20) t = t.substring(0, tire);
  t = _trKucuk(t).replaceAll(RegExp(r"[^a-zçğıöşü\s]"), ' ');
  final out = <String>{};
  for (final w in t.split(RegExp(r'\s+'))) {
    if (w.length < 3) continue;
    final kok = w.length > 5 ? w.substring(0, 5) : w;
    if (_kBenzerDurak.contains(kok)) continue;
    out.add(kok);
  }
  return out;
}

bool _benzerMi(Set<String> a, Set<String> b) {
  if (a.length < 3 || b.length < 3) return false;
  final ortak = a.intersection(b).length;
  if (ortak < 3) return false;
  final kucuk = a.length < b.length ? a.length : b.length;
  return ortak / kucuk >= 0.6;
}

/// Benzer başlıklı haberleri gruplar. Her grubun ilk elemanı en yüksek
/// puanlı (eşitse en yeni) haberdir; sıra ilk görülme sırasına göredir.
List<List<DailyNewsCandidate>> benzerHaberGruplari(
  List<DailyNewsCandidate> items,
) {
  final gruplar = <List<DailyNewsCandidate>>[];
  final kokler = <Set<String>>[];
  for (final e in items) {
    final k = _baslikKokleri(e.title);
    var eklendi = false;
    for (var i = 0; i < gruplar.length; i++) {
      if (_benzerMi(k, kokler[i])) {
        gruplar[i].add(e);
        eklendi = true;
        break;
      }
    }
    if (!eklendi) {
      gruplar.add([e]);
      kokler.add(k);
    }
  }
  for (final g in gruplar) {
    g.sort((a, b) {
      final p = b.relevanceScore.compareTo(a.relevanceScore);
      if (p != 0) return p;
      final ad = a.publishedAt ?? DateTime(2000);
      final bd = b.publishedAt ?? DateTime(2000);
      return bd.compareTo(ad);
    });
  }
  return gruplar;
}

class _BenzerHaberler extends StatelessWidget {
  const _BenzerHaberler({
    required this.benzerler,
    required this.busy,
    required this.onHepsiniReddet,
  });

  final List<DailyNewsCandidate> benzerler;
  final bool busy;
  final VoidCallback onHepsiniReddet;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MetoColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Text(
            '+${benzerler.length} benzer haber (başka kaynaklar)',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: MetoColors.primary,
            ),
          ),
          children: [
            for (final b in benzerler)
              InkWell(
                onTap: b.articleUrl.trim().isEmpty
                    ? null
                    : () => launchUrl(
                          Uri.parse(b.articleUrl.trim()),
                          mode: LaunchMode.externalApplication,
                        ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.article_outlined, size: 16),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${b.title}  ·  ${b.sourceName}',
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: MetoColors.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onHepsiniReddet,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.close, size: 18),
                label: Text('Benzerlerini reddet (${benzerler.length})'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
