// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Flutter web: uygulama içi iframe.
class FullPageIframe extends StatefulWidget {
  const FullPageIframe({super.key, required this.url});

  final String url;

  @override
  State<FullPageIframe> createState() => _FullPageIframeState();
}

class _FullPageIframeState extends State<FullPageIframe> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'app_iframe_${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      return html.IFrameElement()
        ..src = widget.url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.pointerEvents = 'auto'
        ..allowFullscreen = false
        ..setAttribute('title', 'İçerik');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: HtmlElementView(viewType: _viewType),
    );
  }
}
