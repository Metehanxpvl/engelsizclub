import 'package:flutter/material.dart';

/// Asset path veya https URL — katalog / Storage fotoğrafları için.
class CatalogImage extends StatelessWidget {
  const CatalogImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.errorBuilder,
  });

  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;

  bool get _isNetwork {
    final s = source.trim().toLowerCase();
    return s.startsWith('http://') || s.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final src = source.trim();
    if (src.isEmpty) {
      return SizedBox(width: width, height: height);
    }
    if (_isNetwork) {
      return Image.network(
        src,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: errorBuilder ??
            (_, __, ___) => ColoredBox(
                  color: Colors.black12,
                  child: SizedBox(width: width, height: height),
                ),
      );
    }
    return Image.asset(
      src,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: errorBuilder,
    );
  }
}
