import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

const _r2ServeBase =
    'https://qycrkqwqrysypvqaipqn.supabase.co/functions/v1/r2-serve';

/// Eski pub-*.r2.dev linklerini CORS'lu proxy'ye çevirir.
String? resolveIlanPhotoUrl(String? source) {
  final src = (source ?? '').trim();
  if (src.isEmpty) return src;
  final uri = Uri.tryParse(src);
  if (uri == null || !uri.hasScheme) return src;
  if (uri.host.endsWith('.r2.dev')) {
    final key = uri.path.replaceFirst(RegExp(r'^/+'), '');
    if (key.startsWith('ilanlar/')) {
      return '$_r2ServeBase?key=${Uri.encodeQueryComponent(key)}';
    }
  }
  return src;
}

/// data: / http(s) / asset yolundan [ImageProvider] üretir.
ImageProvider? galleryImageProvider(String? source) {
  final src = resolveIlanPhotoUrl(source) ?? '';
  if (src.isEmpty) return null;
  if (src.startsWith('http://') || src.startsWith('https://')) {
    return NetworkImage(src);
  }
  if (src.startsWith('data:image') || src.startsWith('data:')) {
    try {
      final b64 = src.contains(',') ? src.split(',').last : src;
      return MemoryImage(Uint8List.fromList(base64Decode(b64)));
    } catch (_) {
      return null;
    }
  }
  if (src.startsWith('assets/') || src.startsWith('src/')) {
    return AssetImage(src);
  }
  return null;
}

List<ImageProvider> galleryProvidersFromSources(Iterable<String> sources) {
  return [
    for (final s in sources)
      if (galleryImageProvider(s) != null) galleryImageProvider(s)!,
  ];
}

/// Kapak/kart fotoğrafı.
/// Web'de NetworkImage CORS kırılmasını `webHtmlElementStrategy` ile aşar.
class FillPhoto extends StatelessWidget {
  const FillPhoto({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width = double.infinity,
    this.height = double.infinity,
    this.placeholder,
  });

  final String? source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final src = resolveIlanPhotoUrl(source) ?? '';
    if (src.isEmpty) return placeholder ?? const SizedBox.shrink();

    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) =>
            placeholder ?? const SizedBox.shrink(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return placeholder ??
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
        },
      );
    }

    final provider = galleryImageProvider(src);
    if (provider == null) return placeholder ?? const SizedBox.shrink();
    return Image(
      image: provider,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) =>
          placeholder ?? const SizedBox.shrink(),
    );
  }
}


/// Tam ekran galeri / lightbox (pinch-zoom, swipe, oklar, X, aşağı kaydırarak kapat).
Future<void> openPhotoGallery(
  BuildContext context, {
  required List<ImageProvider> images,
  int initialIndex = 0,
}) {
  if (images.isEmpty) return Future.value();
  final start = initialIndex.clamp(0, images.length - 1);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim, secondary) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: PhotoGalleryLightbox(
            images: images,
            initialIndex: start,
          ),
        );
      },
    ),
  );
}

class PhotoGalleryLightbox extends StatefulWidget {
  const PhotoGalleryLightbox({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<ImageProvider> images;
  final int initialIndex;

  @override
  State<PhotoGalleryLightbox> createState() => _PhotoGalleryLightboxState();
}

class _PhotoGalleryLightboxState extends State<PhotoGalleryLightbox> {
  late final PageController _pageController;
  late int _index;
  double _dragY = 0;
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _close() {
    if (_dismissing || !mounted) return;
    _dismissing = true;
    Navigator.of(context).maybePop();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.images.length - 1);
    if (next == _index) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    setState(() {
      _dragY = (_dragY + d.delta.dy).clamp(0.0, 400.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_dragY > 110 || v > 900) {
      _close();
      return;
    }
    setState(() => _dragY = 0);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    final opacity = (1.0 - (_dragY / 320)).clamp(0.35, 1.0);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Aşağı kaydırınca kapanma (zoom kapalıyken PhotoView ile paylaşır)
            GestureDetector(
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              behavior: HitTestBehavior.translucent,
              child: Transform.translate(
                offset: Offset(0, _dragY),
                child: Opacity(
                  opacity: opacity,
                  child: PhotoViewGallery.builder(
                    pageController: _pageController,
                    itemCount: count,
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                    onPageChanged: (i) => setState(() => _index = i),
                    scrollPhysics: const BouncingScrollPhysics(),
                    builder: (context, index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: widget.images[index],
                        initialScale: PhotoViewComputedScale.contained,
                        minScale: PhotoViewComputedScale.contained * 0.8,
                        maxScale: PhotoViewComputedScale.covered * 3.5,
                        heroAttributes: PhotoViewHeroAttributes(
                          tag: 'gallery_$index',
                        ),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      );
                    },
                    loadingBuilder: (context, event) => const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Üst bar: kapat + sayaç
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Row(
                children: [
                  Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Kapat',
                      onPressed: _close,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  if (count > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${_index + 1} / $count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // İleri / geri
            if (count > 1) ...[
              if (_index > 0)
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Önceki',
                        onPressed: () => _go(-1),
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
              if (_index < count - 1)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Material(
                      color: Colors.black45,
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Sonraki',
                        onPressed: () => _go(1),
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
            ],

            // İpucu
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Text(
                  count > 1
                      ? 'Kaydır · yakınlaştır · aşağı çekerek kapat'
                      : 'Yakınlaştır · aşağı çekerek kapat',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
