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
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return _NewsCandidateCard(
                              item: item,
                              busy: _busyId == item.id,
                              onEdit: () => _edit(item),
                              onApprove: () => _approve(item),
                              onReject: () => _reject(item),
                            );
                          },
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
