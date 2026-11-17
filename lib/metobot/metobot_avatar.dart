import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Shared MetoBot character. Mild zoom crops teal padding so the whole
/// head (helmet visor + face + hair) fills a small circle — not eyes-only.
class MetoBotAvatar extends StatefulWidget {
  const MetoBotAvatar({
    super.key,
    this.size = 40,
    this.zoom = 1.26,
  });

  final double size;
  final double zoom;

  static const assetPath = 'assets/metobot/metobot.png';

  /// Static copy in `web/` so hosting serves it as a real PNG, not index.html.
  static const webFileUrl = 'metobot.png?v=20260914d';
  static const webBundleUrl = 'assets/assets/metobot/metobot.png';

  @override
  State<MetoBotAvatar> createState() => _MetoBotAvatarState();
}

class _MetoBotAvatarState extends State<MetoBotAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isPng(Uint8List bytes) =>
      bytes.length > 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;

  Future<Uint8List?> _httpPng(String relative) async {
    try {
      final res = await http.get(Uri.base.resolve(relative));
      if (res.statusCode == 200 && _isPng(res.bodyBytes)) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _load() async {
    if (kIsWeb) {
      for (final rel in [
        MetoBotAvatar.webFileUrl,
        MetoBotAvatar.webBundleUrl,
      ]) {
        final bytes = await _httpPng(rel);
        if (bytes != null && mounted) {
          setState(() => _bytes = bytes);
          return;
        }
      }
    }
    try {
      final data = await rootBundle.load(MetoBotAvatar.assetPath);
      final bytes = data.buffer.asUint8List();
      if (_isPng(bytes) && mounted) setState(() => _bytes = bytes);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return ClipOval(
      child: ColoredBox(
        color: const Color(0xFF3D6364),
        child: SizedBox(
          width: size,
          height: size,
          child: Transform.scale(
            scale: widget.zoom,
            alignment: const Alignment(0, -0.05),
            child: _raster(size),
          ),
        ),
      ),
    );
  }

  Widget _raster(double size) {
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.04),
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    }
    if (kIsWeb) {
      // HTML <img> bypasses CanvasKit CORS decode failures. No toy-icon hide.
      return Image.network(
        Uri.base.resolve(MetoBotAvatar.webFileUrl).toString(),
        width: size,
        height: size,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.04),
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) => Image.network(
          Uri.base.resolve(MetoBotAvatar.webBundleUrl).toString(),
          width: size,
          height: size,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.04),
          filterQuality: FilterQuality.medium,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        ),
      );
    }
    return Image.asset(
      MetoBotAvatar.assetPath,
      width: size,
      height: size,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.04),
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
  }
}
