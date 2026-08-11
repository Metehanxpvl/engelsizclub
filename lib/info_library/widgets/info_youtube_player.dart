import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/info_content.dart';
import '../../meto_theme.dart';
import '../../widgets/youtube_embed.dart' as legacy;

/// Uygulama içi YouTube — `youtube_player_flutter` (iframe motoru).
/// Geçersiz id olursa eski embed / boş durum.
class InfoYoutubePlayer extends StatefulWidget {
  const InfoYoutubePlayer({
    super.key,
    required this.youtubeUrlOrId,
    this.aspectRatio = 16 / 9,
  });

  final String youtubeUrlOrId;
  final double aspectRatio;

  @override
  State<InfoYoutubePlayer> createState() => _InfoYoutubePlayerState();
}

class _InfoYoutubePlayerState extends State<InfoYoutubePlayer> {
  YoutubePlayerController? _controller;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void didUpdateWidget(covariant InfoYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.youtubeUrlOrId != widget.youtubeUrlOrId) {
      _controller?.close();
      _controller = null;
      _init();
    }
  }

  void _init() {
    final id = extractYoutubeVideoId(widget.youtubeUrlOrId);
    _videoId = id;
    if (id == null) return;
    try {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showFullscreenButton: true,
          mute: false,
        ),
      );
    } catch (_) {
      _controller = null;
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = _videoId;
    final c = _controller;
    if (id == null) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: MetoColors.muted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'Geçerli bir YouTube bağlantısı yok',
          style: TextStyle(color: MetoColors.mutedFg),
        ),
      );
    }
    if (c == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: legacy.YoutubeEmbed(videoId: id, height: 240),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: YoutubePlayer(
        controller: c,
        aspectRatio: widget.aspectRatio,
      ),
    );
  }
}
