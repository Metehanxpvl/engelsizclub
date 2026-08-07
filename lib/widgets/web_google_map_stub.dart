import 'package:flutter/material.dart';

/// Mobil: kullanılmaz — Merkezler sayfasında native [GoogleMap] var.
class WebGoogleMapHost extends StatelessWidget {
  const WebGoogleMapHost({
    super.key,
    required this.lat,
    required this.lng,
    required this.zoom,
    required this.markers,
    this.onMarkerTap,
    this.height = 220,
  });

  final double lat;
  final double lng;
  final double zoom;
  final List<WebMapMarker> markers;
  final ValueChanged<String>? onMarkerTap;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class WebMapMarker {
  const WebMapMarker({
    required this.id,
    required this.lat,
    required this.lng,
    required this.title,
    this.snippet,
  });

  final String id;
  final double lat;
  final double lng;
  final String title;
  final String? snippet;
}
