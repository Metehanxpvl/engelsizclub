import 'package:flutter/material.dart';
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

/// Yalnızca aktif slaytta iframe; kaydırınca durur / kapanır.
/// Web'de iframe işaret olaylarını yutmasın diye [PointerEvents.none] + [IgnorePointer].
class KesfetYoutubePlayer extends StatefulWidget {
  const KesfetYoutubePlayer({
    super.key,
    required this.videoId,
    required this.isActive,
    this.reduceMotion = false,
    this.playback,
  });

  final String videoId;
  final bool isActive;
  final bool reduceMotion;
  final KesfetPlayback? playback;

  @override
  State<KesfetYoutubePlayer> createState() => _KesfetYoutubePlayerState();
}

class _KesfetYoutubePlayerState extends State<KesfetYoutubePlayer> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _create();
  }

  @override
  void didUpdateWidget(covariant KesfetYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive) {
      _controller?.pauseVideo();
      if (oldWidget.isActive) {
        _unbind();
        _controller?.close();
        _controller = null;
      }
      return;
    }
    if (_controller == null) {
      _create();
      return;
    }
    if (oldWidget.videoId != widget.videoId) {
      _controller!.loadVideoById(videoId: widget.videoId);
    } else if (!oldWidget.isActive && widget.isActive && !widget.reduceMotion) {
      _controller!.playVideo();
    }
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
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: widget.isActive && !widget.reduceMotion,
        params: const YoutubePlayerParams(
          mute: false,
          loop: false,
          showControls: false,
          showFullscreenButton: false,
          enableKeyboard: false,
          strictRelatedVideos: true,
          enableCaption: true,
          pointerEvents: PointerEvents.none,
        ),
      );
      _bind();
    } catch (_) {
      _controller = null;
      _unbind();
    }
  }

  @override
  void dispose() {
    _unbind();
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (!widget.isActive || c == null) {
      return const ColoredBox(color: Colors.black);
    }
    return ColoredBox(
      color: Colors.black,
      child: IgnorePointer(
        child: YoutubePlayer(
          controller: c,
          aspectRatio: 9 / 16,
          enableFullScreenOnVerticalDrag: false,
        ),
      ),
    );
  }
}

class KesfetThumb extends StatelessWidget {
  const KesfetThumb({super.key, required this.url, this.semanticLabel});

  final String url;
  final String? semanticLabel;

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
  });

  final String videoId;
  final String thumbnailUrl;
  final bool isActive;
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
            child: isActive
                ? KesfetYoutubePlayer(
                    videoId: videoId,
                    isActive: true,
                    reduceMotion: reduceMotion,
                    playback: playback,
                  )
                : KesfetThumb(url: thumbnailUrl, semanticLabel: title),
          ),
        ),
      ),
    );
  }
}
