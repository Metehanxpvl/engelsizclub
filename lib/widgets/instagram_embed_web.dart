// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/instagram_video_resolve.dart';

/// Web oynatıcı:
/// 1) CDN mp4 varsa HTML5 ile sessiz autoplay (sayfada kalır).
/// 2) Yoksa Instagram embed iframe — sandbox ile üst sayfaya kaçış engelli.
class InstagramEmbedView extends StatefulWidget {
  const InstagramEmbedView({
    super.key,
    required this.pageUrl,
    this.embedUrl,
    this.initialVideoUrl,
  });

  final String pageUrl;
  final String? embedUrl;
  final String? initialVideoUrl;

  @override
  State<InstagramEmbedView> createState() => _InstagramEmbedViewState();
}

class _InstagramEmbedViewState extends State<InstagramEmbedView> {
  String? _viewType;
  var _loading = true;
  var _failed = false;
  var _mode = ''; // video | embed

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _failed = false;
      _viewType = null;
      _mode = '';
    });

    final page = widget.pageUrl.trim();
    final embed = (widget.embedUrl ?? '').trim().isNotEmpty
        ? widget.embedUrl!.trim()
        : (instagramAutoplayEmbedUrl(page) ?? '');

    var mp4 = (widget.initialVideoUrl ?? '').trim();
    if (mp4.isEmpty) {
      mp4 = (await resolveInstagramVideoUrl(page))?.trim() ?? '';
    }
    if (!mounted) return;

    if (mp4.isNotEmpty) {
      _registerVideo(mp4);
      setState(() {
        _mode = 'video';
        _loading = false;
      });
      return;
    }

    if (embed.isNotEmpty) {
      _registerSandboxedEmbed(embed);
      setState(() {
        _mode = 'embed';
        _loading = false;
      });
      return;
    }

    setState(() {
      _failed = true;
      _loading = false;
    });
  }

  void _registerVideo(String mp4Url) {
    _viewType =
        'ig_video_${identityHashCode(this)}_${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType!, (int id) {
      final root = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.overflow = 'hidden';

      final video = html.VideoElement()
        ..src = mp4Url
        ..autoplay = true
        ..muted = true
        ..controls = true
        ..loop = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.backgroundColor = '#000';
      video
        ..setAttribute('playsinline', '')
        ..setAttribute('webkit-playsinline', '')
        ..setAttribute('muted', '')
        ..setAttribute('autoplay', '');
      root.append(video);

      void tryPlay() {
        try {
          video.muted = true;
          video.volume = 0;
          video.play().catchError((_) {});
        } catch (_) {}
      }

      video.onLoadedData.listen((_) => tryPlay());
      video.onCanPlay.listen((_) => tryPlay());
      scheduleMicrotask(tryPlay);
      Timer(const Duration(milliseconds: 250), tryPlay);
      Timer(const Duration(milliseconds: 800), tryPlay);
      return root;
    });
  }

  void _registerSandboxedEmbed(String embedUrl) {
    _viewType =
        'ig_embed_${identityHashCode(this)}_${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType!, (int id) {
      final root = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.backgroundColor = '#0F172A'
        ..style.position = 'relative';

      // allow-top-navigation / allow-popups YOK → Play site dışına atamaz.
      final iframe = html.IFrameElement()
        ..src = embedUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.position = 'absolute'
        ..style.top = '0'
        ..style.left = '0'
        ..style.right = '0'
        ..style.bottom = '0'
        ..allow =
            'autoplay; encrypted-media; clipboard-write; picture-in-picture; fullscreen'
        ..allowFullscreen = true
        ..referrerPolicy = 'strict-origin-when-cross-origin'
        ..setAttribute(
          'sandbox',
          'allow-scripts allow-same-origin allow-presentation',
        )
        ..setAttribute('scrolling', 'no')
        ..setAttribute('loading', 'eager');
      root.append(iframe);
      return root;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Color(0xFF0F172A),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white70,
            ),
          ),
        ),
      );
    }

    if (_failed || _viewType == null) {
      return ColoredBox(
        color: const Color(0xFF0F172A),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Video açılamadı. Geçerli bir Reel veya gönderi linki kullan.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: _mode == 'video' ? Colors.black : const Color(0xFF0F172A),
      child: HtmlElementView(viewType: _viewType!),
    );
  }
}
