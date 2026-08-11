// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Web: gerçek iframe — sayfadan ayrılmadan oynar, lazy yüklenir.
class YoutubeEmbed extends StatefulWidget {
  const YoutubeEmbed({
    super.key,
    required this.videoId,
    this.title = 'Video',
    this.height = 220,
  });

  final String videoId;
  final String title;
  final double height;

  @override
  State<YoutubeEmbed> createState() => _YoutubeEmbedState();
}

class _YoutubeEmbedState extends State<YoutubeEmbed> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType =
        'yt_${widget.videoId}_${DateTime.now().microsecondsSinceEpoch}';
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..src =
            'https://www.youtube.com/embed/${widget.videoId}?rel=0&modestbranding=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..allow =
            'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
        ..setAttribute('loading', 'lazy')
        ..setAttribute('title', widget.title);
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: HtmlElementView(viewType: _viewType),
      ),
    );
  }
}
