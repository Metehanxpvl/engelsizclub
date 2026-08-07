// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Web: Flutter GoogleMap platform view ListView'da gri kalabiliyor.
/// Doğrudan google.maps.Map ile çizer (Maps JS index.html'de).
class WebGoogleMapHost extends StatefulWidget {
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
  State<WebGoogleMapHost> createState() => _WebGoogleMapHostState();
}

class _WebGoogleMapHostState extends State<WebGoogleMapHost> {
  late final String _viewType;
  var _ready = false;
  String? _error;
  js.JsObject? _map;
  final _jsMarkers = <js.JsObject>[];

  @override
  void initState() {
    super.initState();
    _viewType =
        'gmap_${identityHashCode(this)}_${DateTime.now().microsecondsSinceEpoch}';
    _register();
  }

  bool get _hasGoogleMaps {
    try {
      if (js.context['__GM_AUTH_FAILURE__'] == true) return false;
      final g = js.context['google'];
      if (g == null) return false;
      return g['maps'] != null;
    } catch (_) {
      return false;
    }
  }

  void _register() {
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final div = html.DivElement()
        ..id = _viewType
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none';

      void tryInit([int attempt = 0]) {
        if (!_hasGoogleMaps) {
          if (attempt < 50) {
            Future<void>.delayed(
              const Duration(milliseconds: 100),
              () => tryInit(attempt + 1),
            );
          } else if (mounted) {
            setState(() {
              _error = js.context['__GM_AUTH_FAILURE__'] == true
                  ? 'Google Maps kimlik doğrulama hatası. Cloud Console: Maps JavaScript API + faturalandırma + HTTP referrer.'
                  : 'Google Maps yüklenemedi.';
            });
          }
          return;
        }
        _initMap(div);
      }

      Future<void>.delayed(const Duration(milliseconds: 50), tryInit);
      return div;
    });
    _ready = true;
  }

  void _initMap(html.Element el) {
    try {
      final maps = js.context['google']['maps'] as js.JsObject;
      _map = js.JsObject(maps['Map'] as js.JsFunction, [
        el,
        js.JsObject.jsify({
          'center': {'lat': widget.lat, 'lng': widget.lng},
          'zoom': widget.zoom,
          'mapTypeControl': false,
          'streetViewControl': false,
          'fullscreenControl': false,
          'gestureHandling': 'greedy',
        }),
      ]);
      _syncMarkers();
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = 'Harita başlatılamadı: $e');
    }
  }

  void _clearMarkers() {
    for (final m in _jsMarkers) {
      try {
        m.callMethod('setMap', [null]);
      } catch (_) {}
    }
    _jsMarkers.clear();
  }

  void _syncMarkers() {
    final map = _map;
    if (map == null || !_hasGoogleMaps) return;
    _clearMarkers();
    final maps = js.context['google']['maps'] as js.JsObject;
    for (final m in widget.markers) {
      final marker = js.JsObject(maps['Marker'] as js.JsFunction, [
        js.JsObject.jsify({
          'position': {'lat': m.lat, 'lng': m.lng},
          'map': map,
          'title': m.title,
        }),
      ]);
      final tap = widget.onMarkerTap;
      if (tap != null) {
        final id = m.id;
        try {
          marker.callMethod('addListener', [
            'click',
            (Object? _) {
              tap(id);
            },
          ]);
        } catch (_) {}
      }
      _jsMarkers.add(marker);
    }
  }

  @override
  void didUpdateWidget(covariant WebGoogleMapHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    final map = _map;
    if (map == null) return;
    if (oldWidget.lat != widget.lat ||
        oldWidget.lng != widget.lng ||
        oldWidget.zoom != widget.zoom) {
      try {
        map.callMethod('setCenter', [
          js.JsObject.jsify({'lat': widget.lat, 'lng': widget.lng}),
        ]);
        map.callMethod('setZoom', [widget.zoom]);
      } catch (_) {}
    }
    _syncMarkers();
  }

  @override
  void dispose() {
    _clearMarkers();
    _map = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_ready) HtmlElementView(viewType: _viewType),
          if (_error != null)
            ColoredBox(
              color: const Color(0xFFF8FAFC),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
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
