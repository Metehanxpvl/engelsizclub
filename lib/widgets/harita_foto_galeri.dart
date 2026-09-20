import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_view/photo_view.dart';

import '../data/centers_data.dart';
import '../harita_foto_store.dart';
import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import 'guest_gate.dart';

/// Mekan detayında R2 fotoğraf şeridi (metadata Postgres, dosya R2).
class HaritaFotoGaleri extends StatefulWidget {
  const HaritaFotoGaleri({
    super.key,
    required this.center,
    required this.isGuest,
    this.onRequireLogin,
  });

  final MetoCenter center;
  final bool isGuest;
  final VoidCallback? onRequireLogin;

  @override
  State<HaritaFotoGaleri> createState() => _HaritaFotoGaleriState();
}

class _HaritaFotoGaleriState extends State<HaritaFotoGaleri> {
  List<HaritaPlacePhoto> _photos = const [];
  bool _loading = true;
  bool _uploading = false;
  int? _deletingId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant HaritaFotoGaleri oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.center.id != widget.center.id ||
        oldWidget.center.name != widget.center.name ||
        oldWidget.center.lat != widget.center.lat ||
        oldWidget.center.lng != widget.center.lng) {
      _reload();
    }
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final rows = await loadHaritaPlacePhotos(widget.center);
    if (!mounted) return;
    setState(() {
      _photos = rows;
      _loading = false;
    });
  }

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    if (widget.isGuest) {
      await ensureMemberAccess(
        context,
        isGuest: true,
        onRequireLogin: widget.onRequireLogin ?? () {},
        message: 'Fotoğraf eklemek için giriş yapın.',
      );
      return;
    }
    if (_photos.length >= kHaritaFotoMaxPerPlace) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu mekanda en fazla 8 fotoğraf olabilir.')),
      );
      return;
    }
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 88,
    );
    if (file == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final added = await uploadHaritaPlacePhoto(
        center: widget.center,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _photos = [added, ..._photos];
        _uploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    }
  }

  Future<void> _removePhoto(HaritaPlacePhoto photo) async {
    if (_uploading || _deletingId != null) return;
    if (widget.isGuest) {
      await ensureMemberAccess(
        context,
        isGuest: true,
        onRequireLogin: widget.onRequireLogin ?? () {},
        message: 'Fotoğraf silmek için giriş yapın.',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const L10nText('Fotoğrafı kaldır'),
        content: const L10nText(
          'Bu fotoğrafı kaldırmak istiyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const L10nText('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const L10nText('Kaldır'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deletingId = photo.id);
    try {
      await deleteHaritaPlacePhoto(center: widget.center, photo: photo);
      if (!mounted) return;
      setState(() {
        _photos = _photos
            .where((p) => p.photoUrl != photo.photoUrl && p.id != photo.id)
            .toList();
        _deletingId = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'.replaceFirst('Bad state: ', ''))),
      );
    }
  }

  void _openFull(HaritaPlacePhoto photo) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: L10nText(photo.altText.isEmpty ? widget.center.name : photo.altText),
          ),
          body: PhotoView(
            imageProvider: NetworkImage(photo.photoUrl),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.4,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: L10nText(
                  'Mekan fotoğrafları',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: MetoColors.foreground,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _uploading ? null : _pickAndUpload,
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_a_photo_outlined, size: 18),
                label: L10nText(_uploading ? 'Yükleniyor…' : 'Fotoğraf ekle'),
                style: TextButton.styleFrom(
                  foregroundColor: MetoColors.primary,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_photos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: L10nText(
                'Henüz fotoğraf yok. İlk erişilebilirlik fotoğrafını siz ekleyin.',
                style: TextStyle(fontSize: 13, color: MetoColors.mutedFg),
              ),
            )
          else
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _photos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final p = _photos[i];
                  final mine = haritaFotoSilinebilir(widget.center, p);
                  final busy = _deletingId == p.id;
                  return Semantics(
                    button: true,
                    label: p.altText.isEmpty
                        ? 'Mekan fotoğrafı ${i + 1}'
                        : p.altText,
                    child: Stack(
                      children: [
                        InkWell(
                          onTap: () => _openFull(p),
                          borderRadius: BorderRadius.circular(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              p.previewUrl,
                              width: 120,
                              height: 92,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 120,
                                height: 92,
                                color: MetoColors.muted,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                        ),
                        if (mine)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: InkWell(
                              onTap: busy || _uploading
                                  ? null
                                  : () => unawaited(_removePhoto(p)),
                              child: CircleAvatar(
                                radius: 11,
                                backgroundColor: Colors.black54,
                                child: busy
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                      ],
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
