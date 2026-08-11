import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../meto_theme.dart';

/// Mobil: WebView iframe; web dışı yedek: harici YouTube linki.
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
  WebViewController? _controller;
  Object? _error;

  String get _watchUrl => 'https://www.youtube.com/watch?v=${widget.videoId}';
  String get _embedUrl =>
      'https://www.youtube.com/embed/${widget.videoId}?rel=0&modestbranding=1';

  @override
  void initState() {
    super.initState();
    try {
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..loadRequest(Uri.parse(_embedUrl));
      _controller = c;
    } catch (e) {
      _error = e;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null && _error == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: WebViewWidget(controller: _controller!),
        ),
      );
    }
    return Material(
      color: MetoColors.muted,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => launchUrl(
          Uri.parse(_watchUrl),
          mode: LaunchMode.externalApplication,
        ),
        child: SizedBox(
          height: widget.height,
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill, size: 56, color: MetoColors.primary),
              const SizedBox(height: 8),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: MetoColors.foreground,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'YouTube’da aç',
                style: TextStyle(color: MetoColors.mutedFg, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
