import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../data/duyuru_data.dart';
import '../data/instagram_video_resolve.dart';
import '../meto_theme.dart';

/// Mobil: önce doğrudan MP4 (autoplay), olmazsa izinleri düzeltilmiş WebView.
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
  WebViewController? _controller;
  VideoPlayerController? _video;
  Timer? _autoplayTimer;
  var _loading = true;
  var _failed = false;
  var _autoplayTries = 0;
  var _mode = 'boot'; // boot | video | webview | fail

  String get _targetUrl {
    final embed = (widget.embedUrl ?? '').trim();
    if (embed.isNotEmpty) return embed;
    return instagramAutoplayEmbedUrl(widget.pageUrl) ??
        widget.pageUrl.trim();
  }

  bool get _isStoryOnly =>
      isInstagramStoryUrl(widget.pageUrl) &&
      instagramEmbedUrl(widget.pageUrl) == null;

  @override
  void initState() {
    super.initState();
    if (_isStoryOnly) {
      _loading = false;
      _failed = true;
      _mode = 'fail';
      return;
    }
    _boot();
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      _loading = true;
      _failed = false;
      _mode = 'boot';
    });

    final mp4 = (widget.initialVideoUrl ?? '').trim().isNotEmpty
        ? widget.initialVideoUrl!.trim()
        : await resolveInstagramVideoUrl(widget.pageUrl);
    if (!mounted) return;

    if (mp4 != null && mp4.isNotEmpty) {
      final ok = await _startVideo(mp4);
      if (!mounted) return;
      if (ok) {
        setState(() {
          _mode = 'video';
          _loading = false;
        });
        return;
      }
    }

    await _initWebView();
  }

  Future<bool> _startVideo(String url) async {
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        httpHeaders: const {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
          'Referer': 'https://www.instagram.com/',
        },
      );
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0); // sessiz autoplay
      await c.play();
      if (!mounted) {
        await c.dispose();
        return false;
      }
      _video?.dispose();
      _video = c;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _allowInWebView(String url) {
    final u = url.toLowerCase();
    if (u.startsWith('about:') ||
        u.startsWith('data:') ||
        u.startsWith('blob:')) {
      return true;
    }
    return u.contains('instagram.com') ||
        u.contains('cdninstagram.com') ||
        u.contains('fbcdn.net') ||
        u.contains('facebook.com') ||
        u.contains('meta.com') ||
        u.contains('accountkit.com');
  }

  Future<void> _initWebView() async {
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      // Masaüstü UA: mobil WebView'da Instagram sıkça boş / giriş ekranı gösteriyor.
      ..setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
            _startAutoplayLoop();
          },
          onWebResourceError: (err) {
            // Alt kaynak hataları (tracker/font) oynatıcıyı kapatmasın.
            if (err.isForMainFrame == true && mounted) {
              setState(() {
                _loading = false;
                _failed = true;
                _mode = 'fail';
              });
            }
          },
          onNavigationRequest: (request) {
            final url = request.url;
            if (_allowInWebView(url)) {
              return NavigationDecision.navigate;
            }
            final uri = Uri.tryParse(url);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
            return NavigationDecision.prevent;
          },
        ),
      );

    final platform = controller.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
    }

    await controller.loadRequest(Uri.parse(_targetUrl));
    if (!mounted) return;
    setState(() {
      _controller = controller;
      _mode = 'webview';
      _loading = false;
    });
  }

  void _startAutoplayLoop() {
    _autoplayTimer?.cancel();
    _autoplayTries = 0;
    _autoplayTimer =
        Timer.periodic(const Duration(milliseconds: 400), (t) async {
      _autoplayTries++;
      final c = _controller;
      if (c == null || !mounted) {
        t.cancel();
        return;
      }
      try {
        await c.runJavaScript(_kAutoplayJs);
      } catch (_) {}
      if (_autoplayTries >= 20) t.cancel();
    });
  }

  Future<void> _openExternal() async {
    final uri = Uri.tryParse(widget.pageUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_mode == 'fail' || _failed || _isStoryOnly) {
      return _InstagramFallback(
        isStory: _isStoryOnly,
        failed: true,
        onOpen: _openExternal,
      );
    }

    if (_mode == 'video' && _video != null && _video!.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: _video!.value.aspectRatio == 0
                ? 9 / 16
                : _video!.value.aspectRatio,
            child: VideoPlayer(_video!),
          ),
        ),
      );
    }

    if (_mode == 'webview' && _controller != null) {
      return ColoredBox(
        color: const Color(0xFF0F172A),
        child: Stack(
          fit: StackFit.expand,
          children: [
            WebViewWidget(controller: _controller!),
            if (_loading)
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white70,
                  ),
                ),
              ),
            Positioned(
              left: 12,
              bottom: 12,
              child: TextButton.icon(
                onPressed: _openExternal,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.black54,
                ),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  'Instagram\'da Aç',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
}

const _kAutoplayJs = r'''
(function () {
  function clickPlay() {
    var labels = ['Play', 'Oynat', 'Play video', 'Videoyu oynat'];
    var nodes = document.querySelectorAll('div[role="button"], button, [tabindex="0"]');
    for (var i = 0; i < nodes.length; i++) {
      var el = nodes[i];
      var al = ((el.getAttribute('aria-label') || '') + ' ' + (el.textContent || ''));
      for (var j = 0; j < labels.length; j++) {
        if (al.indexOf(labels[j]) !== -1) {
          try { el.click(); return true; } catch (e) {}
        }
      }
    }
    var svgs = document.querySelectorAll('svg[aria-label]');
    for (var k = 0; k < svgs.length; k++) {
      var lab = svgs[k].getAttribute('aria-label') || '';
      if (lab.indexOf('Play') !== -1 || lab.indexOf('Oynat') !== -1) {
        var p = svgs[k].closest('[role="button"],button,div') || svgs[k].parentElement;
        try { if (p) p.click(); return true; } catch (e) {}
      }
    }
    return false;
  }
  var videos = document.querySelectorAll('video');
  for (var i = 0; i < videos.length; i++) {
    var v = videos[i];
    try {
      v.muted = true;
      v.defaultMuted = true;
      v.volume = 0;
      v.playsInline = true;
      v.setAttribute('playsinline', '');
      v.setAttribute('webkit-playsinline', '');
      v.setAttribute('autoplay', '');
      var p = v.play();
      if (p && p.catch) p.catch(function () {});
    } catch (e) {}
  }
  clickPlay();
})();
''';

class _InstagramFallback extends StatelessWidget {
  const _InstagramFallback({
    required this.isStory,
    required this.failed,
    required this.onOpen,
  });

  final bool isStory;
  final bool failed;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final msg = isStory
        ? 'Geçici Instagram hikayeleri gömülemez.\nInstagram altyapısında açılır.'
        : 'Gömülü önizleme yüklenemedi.\nInstagram\'da açmayı dene.';

    return ColoredBox(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStory ? Icons.info_outline : Icons.play_circle_outline,
                size: 56,
                color: Colors.white70,
              ),
              const SizedBox(height: 14),
              Text(
                msg,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onOpen,
                style: FilledButton.styleFrom(
                  backgroundColor: MetoColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(
                  'Instagram\'da Aç',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
