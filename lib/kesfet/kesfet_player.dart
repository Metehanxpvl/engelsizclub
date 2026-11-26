import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

/// Aktif slayttaki YouTube denetleyicisi; dokununca oynat/duraklat.
class KesfetPlayback {
  YoutubePlayerController? controller;

  Future<void> toggle() async {
    final c = controller;
    if (c == null) return;
    try {
      final playing = c.value.playerState == PlayerState.playing ||
          c.value.playerState == PlayerState.buffering;
      if (playing) {
        await c.pauseVideo();
      } else {
        await c.playVideo();
      }
    } catch (_) {}
  }

  Future<void> pause() async {
    final c = controller;
    if (c == null) return;
    try {
      await c.pauseVideo();
    } catch (_) {}
  }
}

/// Aktif slaytta oynatıcı; bir sonraki slaytta ([preload]) önceden hazırlanır.
/// Wi-Fi'de ([fullPreload]) videonun ilk saniyeleri sessizce indirilip durdurulur,
/// mobil veride yalnız oynatıcı kurulur. Kaydırınca hazır oynatıcı hemen başlar.
/// Web'de iframe işaret olaylarını yutmasın diye [PointerEvents.none] + [IgnorePointer].
class KesfetYoutubePlayer extends StatefulWidget {
  const KesfetYoutubePlayer({
    super.key,
    required this.videoId,
    required this.isActive,
    this.preload = false,
    this.fullPreload = false,
    this.reduceMotion = false,
    this.playback,
    this.placeholder,
  });

  final String videoId;
  final bool isActive;

  /// Sonraki slayt: oynatıcıyı şimdiden hazırla (görünmez, sessiz).
  final bool preload;

  /// Wi-Fi: ön yüklemede videonun başını da indir.
  final bool fullPreload;
  final bool reduceMotion;
  final KesfetPlayback? playback;

  /// Video oynamaya başlayana kadar üstte gösterilir (kapak resmi).
  final Widget? placeholder;

  @override
  State<KesfetYoutubePlayer> createState() => _KesfetYoutubePlayerState();
}

class _KesfetYoutubePlayerState extends State<KesfetYoutubePlayer> {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;
  Timer? _bufferTimer;

  /// Ön yükleme için sessize alındı; aktif olunca ses açılır.
  bool _mutedForPreload = false;

  /// Ön yüklemede baştaki saniyeler indirildi ve durduruldu.
  bool _preloadBuffered = false;

  /// Aktifken oynamaya başladı → kapak resmi kalkar.
  bool _started = false;

  bool get _wanted => widget.isActive || (widget.preload && !kIsWeb);

  @override
  void initState() {
    super.initState();
    if (_wanted) _create();
  }

  @override
  void didUpdateWidget(covariant KesfetYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_wanted) {
      _teardown();
      return;
    }
    if (_controller == null) {
      _create();
      return;
    }
    if (oldWidget.videoId != widget.videoId) {
      _resetFlags();
      if (widget.isActive) {
        _controller!.loadVideoById(videoId: widget.videoId);
      } else {
        _controller!.cueVideoById(videoId: widget.videoId);
      }
    } else if (!oldWidget.isActive && widget.isActive) {
      _activate();
    } else if (oldWidget.isActive && !widget.isActive) {
      // Aktiften "sonraki" konumuna döndü (geri kaydırma): durdur, hazır tut.
      _unbind();
      unawaited(_controller!.pauseVideo());
      if (_started) setState(() => _started = false);
      return;
    }
    if (widget.isActive) _bind();
  }

  void _resetFlags() {
    _bufferTimer?.cancel();
    _bufferTimer = null;
    _mutedForPreload = false;
    _preloadBuffered = false;
    _started = false;
  }

  void _activate() {
    final c = _controller;
    if (c == null) return;
    _bufferTimer?.cancel();
    _bufferTimer = null;
    if (_mutedForPreload) {
      _mutedForPreload = false;
      unawaited(c.unMute());
    }
    if (_preloadBuffered) {
      unawaited(c.seekTo(seconds: 0, allowSeekAhead: true));
    }
    if (!widget.reduceMotion) unawaited(c.playVideo());
    _bind();
  }

  void _bind() {
    widget.playback?.controller = _controller;
  }

  void _unbind() {
    if (widget.playback?.controller == _controller) {
      widget.playback?.controller = null;
    }
  }

  void _create() {
    try {
      final bufferAhead = !widget.isActive && widget.fullPreload;
      _mutedForPreload = bufferAhead;
      final c = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: widget.isActive ? !widget.reduceMotion : bufferAhead,
        params: YoutubePlayerParams(
          mute: bufferAhead,
          loop: false,
          showControls: false,
          showFullscreenButton: false,
          enableKeyboard: false,
          strictRelatedVideos: true,
          enableCaption: true,
          pointerEvents: PointerEvents.none,
        ),
      );
      _controller = c;
      _sub = c.stream.listen(_onValue);
      if (widget.isActive) _bind();
      // YoutubePlayer widget on Android/iOS lifts the WebView into OverlayPortal,
      // which sits above the Keşfet swipe layer and eats vertical drags.
      if (!kIsWeb) {
        unawaited(_initNativeSurface());
      }
    } catch (_) {
      _controller = null;
      _unbind();
    }
  }

  void _onValue(YoutubePlayerValue v) {
    if (!mounted) return;
    final playing = v.playerState == PlayerState.playing;
    if (widget.isActive) {
      if (playing && !_started) setState(() => _started = true);
      return;
    }
    // Ön yükleme: sessiz oynamaya başladı → ~2 sn indirip başa sar ve durdur.
    if (playing &&
        _mutedForPreload &&
        !_preloadBuffered &&
        _bufferTimer == null) {
      _bufferTimer = Timer(const Duration(seconds: 2), () {
        _bufferTimer = null;
        final c = _controller;
        if (!mounted || c == null || widget.isActive) return;
        _preloadBuffered = true;
        unawaited(c.pauseVideo());
        unawaited(c.seekTo(seconds: 0, allowSeekAhead: true));
      });
    }
  }

  Future<void> _initNativeSurface() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.webViewController.setBackgroundColor(Colors.black);
      await c.initWithParams(params: c.params);
    } catch (_) {}
    if (!mounted || _controller != c) return;
    setState(() {});
  }

  void _teardown() {
    final c = _controller;
    if (c == null) return;
    _bufferTimer?.cancel();
    _bufferTimer = null;
    unawaited(_sub?.cancel());
    _sub = null;
    _unbind();
    unawaited(c.pauseVideo());
    unawaited(c.close());
    _controller = null;
    _mutedForPreload = false;
    _preloadBuffered = false;
    _started = false;
  }

  @override
  void dispose() {
    _bufferTimer?.cancel();
    unawaited(_sub?.cancel());
    _unbind();
    _controller?.close();
    super.dispose();
  }

  Widget _withPlaceholder(Widget player) {
    final ph = widget.placeholder;
    if (ph == null) return player;
    return Stack(
      fit: StackFit.expand,
      children: [
        player,
        if (!widget.isActive || !_started) ph,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!_wanted || c == null) {
      return widget.placeholder ?? const ColoredBox(color: Colors.black);
    }
    if (kIsWeb) {
      return _withPlaceholder(
        ColoredBox(
          color: Colors.black,
          child: IgnorePointer(
            child: YoutubePlayer(
              controller: c,
              aspectRatio: 9 / 16,
              enableFullScreenOnVerticalDrag: false,
            ),
          ),
        ),
      );
    }
    // Keep the WebView in the PageView tree so vertical swipes reach Flutter.
    return _withPlaceholder(
      ColoredBox(
        color: Colors.black,
        child: WebViewWidget(
          controller: c.webViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        ),
      ),
    );
  }
}

class KesfetThumb extends StatelessWidget {
  const KesfetThumb({
    super.key,
    required this.url,
    this.semanticLabel,
    this.loading = false,
  });

  final String url;
  final String? semanticLabel;

  /// Video yüklenirken: oynat ikonu yerine küçük yükleniyor göstergesi.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final img = url.trim().isEmpty
        ? const ColoredBox(color: Colors.black)
        : Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Icon(Icons.play_circle_outline,
                    color: Colors.white70, size: 64),
              ),
            ),
          );
    return Semantics(
      label: semanticLabel ?? 'Video önizlemesi',
      image: true,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            img,
            if (loading)
              const Center(
                child: SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white70,
                  ),
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white70,
                  size: 72,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 9:16 alan; aktifken oynatıcı.
class KesfetStage extends StatelessWidget {
  const KesfetStage({
    super.key,
    required this.videoId,
    required this.thumbnailUrl,
    required this.isActive,
    required this.reduceMotion,
    this.title = 'Video',
    this.playback,
    this.preload = false,
    this.fullPreload = false,
  });

  final String videoId;
  final String thumbnailUrl;
  final bool isActive;

  /// Sonraki slayt: oynatıcı önceden hazırlanır.
  final bool preload;

  /// Wi-Fi: ön yüklemede videonun başı da indirilir.
  final bool fullPreload;
  final bool reduceMotion;
  final String title;
  final KesfetPlayback? playback;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: (isActive || (preload && !kIsWeb))
                ? KesfetYoutubePlayer(
                    videoId: videoId,
                    isActive: isActive,
                    preload: preload,
                    fullPreload: fullPreload,
                    reduceMotion: reduceMotion,
                    playback: playback,
                    // Video oynayana kadar siyah ekran yerine kapak resmi.
                    placeholder: KesfetThumb(
                      url: thumbnailUrl,
                      semanticLabel: title,
                      loading: isActive,
                    ),
                  )
                : KesfetThumb(url: thumbnailUrl, semanticLabel: title),
          ),
        ),
      ),
    );
  }
}
