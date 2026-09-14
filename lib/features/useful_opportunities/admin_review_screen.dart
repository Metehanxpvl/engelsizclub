import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../admin_config.dart';
import '../../data/duyuru_data.dart';
import '../../l10n/l10n_text.dart';
import '../../meto_theme.dart';
import '../../services/image_optimize_service.dart';
import '../../services/r2_storage_service.dart';
import 'useful_content_model.dart';
import 'useful_content_repository.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({
    super.key,
    this.adminEmail,
    this.repository,
  });

  final String? adminEmail;
  final UsefulContentRepository? repository;

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  late final UsefulContentRepository _repo =
      widget.repository ?? UsefulContentRepository();
  List<UsefulContentItem> _items = const [];
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
      final items = await _repo.loadPendingReview();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _replaceItem(UsefulContentItem next) {
    setState(() {
      _items = [
        for (final e in _items)
          if (e.id == next.id) next else e,
      ];
    });
  }

  Future<void> _edit(UsefulContentItem item) async {
    final titleCtrl = TextEditingController(text: item.title);
    final summaryCtrl = TextEditingController(text: item.summary);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Metni düzenle',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: summaryCtrl,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Özet'),
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
            style: FilledButton.styleFrom(backgroundColor: MetoColors.primary),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busyId = item.id);
    try {
      await _repo.updateCopy(
        id: item.id,
        title: titleCtrl.text,
        summary: summaryCtrl.text,
      );
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _saveImage(UsefulContentItem item, String imageUrl) async {
    try {
      await _repo.updateImage(id: item.id, imageUrl: imageUrl);
      _replaceItem(item.copyWith(imageUrl: imageUrl));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Görsel kaydedilemedi: $e')),
      );
    }
  }

  Future<void> _approve(UsefulContentItem item, String imageUrl) async {
    setState(() => _busyId = item.id);
    try {
      await _repo.approve(
        item.id,
        adminEmail: widget.adminEmail,
        imageUrl: imageUrl,
      );
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Onaylandı. Ana sayfa Güncel Duyurular story’sine eklendi.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Onaylanamadı: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _reject(UsefulContentItem item) async {
    setState(() => _busyId = item.id);
    try {
      await _repo.reject(item.id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reddedilemedi: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
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
          'Fırsat inceleme',
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
                        padding: const EdgeInsets.all(24),
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
                              'Bekleyen kayıt yok. Collector henüz pending_review yazmadıysa liste boş kalır — onaylı story ana sayfadadır.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(color: MetoColors.mutedFg),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final item = _items[i];
                            return _PendingReviewCard(
                              item: item,
                              busy: _busyId == item.id,
                              onEdit: () => _edit(item),
                              onReject: () => _reject(item),
                              onImageSaved: (url) => _saveImage(item, url),
                              onApprove: (url) => _approve(item, url),
                            );
                          },
                        ),
    );
  }
}

class _PendingReviewCard extends StatefulWidget {
  const _PendingReviewCard({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onReject,
    required this.onImageSaved,
    required this.onApprove,
  });

  final UsefulContentItem item;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onReject;
  final Future<void> Function(String imageUrl) onImageSaved;
  final Future<void> Function(String imageUrl) onApprove;

  @override
  State<_PendingReviewCard> createState() => _PendingReviewCardState();
}

class _PendingReviewCardState extends State<_PendingReviewCard> {
  late final TextEditingController _imageUrl;
  Uint8List? _pickedBytes;
  String? _uploadedUrl;
  var _uploading = false;

  bool get _isInstagram => isInstagramUrl(widget.item.sourceUrl);

  @override
  void initState() {
    super.initState();
    _imageUrl = TextEditingController(text: widget.item.imageUrl);
  }

  @override
  void didUpdateWidget(covariant _PendingReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _pickedBytes = null;
      _uploadedUrl = null;
      _imageUrl.text = widget.item.imageUrl;
      return;
    }
    if (_pickedBytes == null &&
        widget.item.imageUrl != oldWidget.item.imageUrl &&
        widget.item.imageUrl != _imageUrl.text.trim()) {
      _imageUrl.text = widget.item.imageUrl;
    }
  }

  @override
  void dispose() {
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
      _uploadedUrl = null;
      _imageUrl.clear();
    });
    await _uploadPicked();
  }

  Future<String> _uploadPicked() async {
    if (_pickedBytes == null || _pickedBytes!.isEmpty) return '';
    setState(() => _uploading = true);
    try {
      final optimized = await ImageOptimizeService.forCatalogCard(_pickedBytes!);
      final url = await R2StorageService.uploadBytes(
        bytes: optimized.bytes,
        fileName: 'firsat_${DateTime.now().millisecondsSinceEpoch}.jpg',
        contentType: optimized.contentType,
      );
      if (!mounted) return url;
      _uploadedUrl = url;
      _imageUrl.text = url;
      await widget.onImageSaved(url);
      return url;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Görsel yüklenemedi: $e')),
        );
      }
      rethrow;
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String> _resolveImagePayload() async {
    if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
      if (_uploadedUrl != null && _uploadedUrl!.isNotEmpty) {
        return _uploadedUrl!;
      }
      return _uploadPicked();
    }
    final typed = _imageUrl.text.trim();
    if (typed.isNotEmpty) return typed;
    return widget.item.imageUrl.trim();
  }

  Future<void> _approve() async {
    if (_uploading) return;
    String image;
    try {
      image = await _resolveImagePayload();
    } catch (_) {
      return;
    }
    if (image.isNotEmpty && image != widget.item.imageUrl) {
      await widget.onImageSaved(image);
    }
    await widget.onApprove(image);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final busy = widget.busy || _uploading;
    final previewUrl = _imageUrl.text.trim();
    return Card(
      color: MetoColors.card,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            if (item.summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                item.summary,
                style: GoogleFonts.nunito(height: 1.35),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              item.sourceUrl,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: MetoColors.mutedFg,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Dairesel görsel',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MetoColors.mutedFg,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isInstagram
                  ? 'Instagram kaynak — görsel gerekmez (gömülü story). İstersen yine foto yükleyebilirsin.'
                  : 'Güncel Duyurular’daki gibi dairesel görsel gerekir.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: MetoColors.mutedFg,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: _pickedBytes != null
                        ? Image.memory(_pickedBytes!, fit: BoxFit.cover)
                        : previewUrl.startsWith('http')
                            ? Image.network(
                                previewUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => ColoredBox(
                                  color: MetoColors.muted,
                                  child: Icon(
                                    _isInstagram
                                        ? Icons.camera_alt_outlined
                                        : Icons.campaign_outlined,
                                    color: MetoColors.primary,
                                  ),
                                ),
                              )
                            : ColoredBox(
                                color: MetoColors.muted,
                                child: Icon(
                                  _isInstagram
                                      ? Icons.camera_alt_outlined
                                      : Icons.campaign_outlined,
                                  color: MetoColors.primary,
                                ),
                              ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _pickImage,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library_outlined, size: 18),
                    label: const L10nText('Galeriden yükle'),
                  ),
                ),
              ],
            ),
            if (!_isInstagram) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _imageUrl,
                enabled: !busy && _pickedBytes == null,
                decoration: const InputDecoration(
                  hintText: 'veya görsel URL (https://...)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: busy ? null : widget.onEdit,
                  child: const Text('Düzenle'),
                ),
                FilledButton(
                  onPressed: busy ? null : _approve,
                  style: FilledButton.styleFrom(
                    backgroundColor: MetoColors.primary,
                  ),
                  child: const Text('Onayla'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : widget.onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                  ),
                  child: const Text('Reddet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
