// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

class WebBarcodeHit {
  const WebBarcodeHit({required this.text, this.format = ''});

  final String text;
  final String format;
}

html.VideoElement? _liveVideo() {
  html.VideoElement? fallback;
  for (final node in html.document.querySelectorAll('video')) {
    if (node is! html.VideoElement) continue;
    if (node.videoWidth < 80 || node.videoHeight < 80) continue;
    fallback ??= node;
    final playing = !node.paused && node.readyState >= 2;
    if (playing) return node;
  }
  return fallback;
}

void prepareLiveVideosForScan() {
  for (final node in html.document.querySelectorAll('video')) {
    if (node is! html.VideoElement) continue;
    node.autoplay = true;
    node.muted = true;
    node.controls = false;
    node.setAttribute('playsinline', 'true');
    node.setAttribute('webkit-playsinline', 'true');
    try {
      unawaited(node.play().catchError((_) => null));
    } catch (_) {}
  }
}

void boostLiveCameraResolution() {
  try {
    if (js_util.hasProperty(html.window, '__engelsizBoostCamera')) {
      js_util.callMethod(html.window, '__engelsizBoostCamera', []);
    }
  } catch (_) {}
}

bool isMedicinePreviewBlurry() {
  try {
    if (!js_util.hasProperty(html.window, '__engelsizIsPreviewBlurry')) {
      return false;
    }
    final raw = js_util.callMethod(html.window, '__engelsizIsPreviewBlurry', []);
    return raw == true;
  } catch (_) {
    return false;
  }
}

bool isMedicineTorchAvailable() {
  try {
    if (!js_util.hasProperty(html.window, '__engelsizTorchAvailable')) {
      return false;
    }
    final raw = js_util.callMethod(html.window, '__engelsizTorchAvailable', []);
    return raw == true;
  } catch (_) {
    return false;
  }
}

bool isMedicineTorchOn() {
  try {
    if (!js_util.hasProperty(html.window, '__engelsizTorchOn')) {
      return false;
    }
    final raw = js_util.callMethod(html.window, '__engelsizTorchOn', []);
    return raw == true;
  } catch (_) {
    return false;
  }
}

bool toggleMedicineTorch([bool? on]) {
  try {
    if (!js_util.hasProperty(html.window, '__engelsizToggleTorch')) {
      return false;
    }
    final raw = js_util.callMethod(
      html.window,
      '__engelsizToggleTorch',
      [on],
    );
    return raw == true;
  } catch (_) {
    return false;
  }
}

void tapMedicineFocus(double nx, double ny) {
  try {
    if (!js_util.hasProperty(html.window, '__engelsizTapFocus')) return;
    js_util.callMethod(html.window, '__engelsizTapFocus', [nx, ny]);
  } catch (_) {}
}

html.CanvasElement? _frameCanvas(html.VideoElement video) {
  final w = video.videoWidth;
  final h = video.videoHeight;
  if (w <= 0 || h <= 0) return null;
  final canvas = html.CanvasElement(width: w, height: h);
  canvas.context2D.drawImageScaled(video, 0, 0, w, h);
  return canvas;
}

Future<Uint8List?> captureLiveCameraJpeg({double quality = 0.88}) async {
  prepareLiveVideosForScan();
  final video = _liveVideo();
  if (video == null) return null;
  final canvas = _frameCanvas(video);
  if (canvas == null) return null;
  try {
    final blob = await canvas.toBlob('image/jpeg', quality);
    return _blobToBytes(blob);
  } catch (_) {
    try {
      final dataUrl = canvas.toDataUrl('image/jpeg', quality);
      return Uri.parse(dataUrl).data?.contentAsBytes();
    } catch (_) {
      return null;
    }
  }
}

Future<Uint8List?> _blobToBytes(html.Blob blob) {
  final reader = html.FileReader();
  final done = Completer<Uint8List?>();
  reader.onLoadEnd.listen((_) {
    done.complete(_asBytes(reader.result));
  });
  reader.onError.listen((_) => done.complete(null));
  reader.readAsArrayBuffer(blob);
  return done.future;
}

Uint8List? _asBytes(Object? result) {
  if (result == null) return null;
  if (result is Uint8List) return result;
  if (result is ByteBuffer) return result.asUint8List();
  if (result is List<int>) return Uint8List.fromList(result);
  return null;
}

WebBarcodeHit? _hitFromJs(Object? raw) {
  if (raw == null) return null;
  try {
    final text = js_util.getProperty(raw, 'text');
    if (text is! String || text.trim().isEmpty) return null;
    var format = '';
    try {
      final f = js_util.getProperty(raw, 'format');
      if (f is String) format = f;
    } catch (_) {}
    return WebBarcodeHit(text: text.trim(), format: format);
  } catch (_) {
    return null;
  }
}

/// `ready` | `loading` | `failed`, or null if the script is missing.
String? webDecoderStatus() {
  try {
    if (js_util.hasProperty(html.window, '__engelsizDecoderStatus')) {
      final raw =
          js_util.callMethod(html.window, '__engelsizDecoderStatus', []);
      if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    }
    if (js_util.hasProperty(html.window, 'ZXing')) return 'ready';
  } catch (_) {}
  return null;
}

WebBarcodeHit? decodeMedicineLiveFrame() {
  final fn = js_util.hasProperty(html.window, '__engelsizDecodeLiveFrame')
      ? '__engelsizDecodeLiveFrame'
      : (js_util.hasProperty(html.window, '__engelsizDecodeMedicineFrame')
          ? '__engelsizDecodeMedicineFrame'
          : null);
  if (fn == null) return null;
  try {
    final raw = js_util.callMethod(html.window, fn, []);
    return _hitFromJs(raw);
  } catch (_) {
    return null;
  }
}

Future<WebBarcodeHit?> decodeMedicineLiveFrameAsync() async {
  if (js_util.hasProperty(html.window, '__engelsizDecodeLiveFrameAsync')) {
    try {
      final promise = js_util.callMethod(
        html.window,
        '__engelsizDecodeLiveFrameAsync',
        [],
      );
      final raw = await js_util.promiseToFuture<Object?>(promise);
      return _hitFromJs(raw);
    } catch (_) {}
  }
  return decodeMedicineLiveFrame();
}

Future<WebBarcodeHit?> decodeWebBarcodeImage(Uint8List bytes) async {
  if (bytes.isEmpty) return null;
  if (!js_util.hasProperty(html.window, '__engelsizDecodeImageBlob')) {
    return null;
  }
  try {
    final blob = html.Blob([bytes]);
    final promise = js_util.callMethod(
      html.window,
      '__engelsizDecodeImageBlob',
      [blob],
    );
    final raw = await js_util.promiseToFuture<Object?>(promise);
    return _hitFromJs(raw);
  } catch (_) {
    return null;
  }
}

class WebLiveBarcodePoller {
  /// Both Ürün and İlaç: EAN/UPC + QR + Data Matrix (ZXing, not 1D-only).
  static const productFormats = <String>[
    'ean_13',
    'ean_8',
    'upc_a',
    'upc_e',
    'qr_code',
    'data_matrix',
    'pdf417',
    'aztec',
    'code_128',
  ];

  static const medicineFormats = productFormats;

  Timer? _timer;
  bool _busy = false;
  bool _boosted = false;
  DateTime? _lastHitAt;
  void Function(bool blurry)? _onPreviewQuality;

  void start(
    void Function(WebBarcodeHit hit) onCode, {
    List<String>? formats,
    bool medicineMode = false,
    void Function(bool blurry)? onPreviewQuality,
  }) {
    stop();
    _onPreviewQuality = onPreviewQuality;
    _boosted = false;
    _lastHitAt = null;
    _timer = Timer.periodic(
      const Duration(milliseconds: 160),
      (_) => unawaited(_tick(onCode)),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _busy = false;
    _onPreviewQuality = null;
  }

  Future<void> _tick(void Function(WebBarcodeHit hit) onCode) async {
    if (_busy) return;
    _busy = true;
    try {
      prepareLiveVideosForScan();
      if (!_boosted) {
        _boosted = true;
        boostLiveCameraResolution();
      }
      final hit = await decodeMedicineLiveFrameAsync();
      if (_timer == null) return;
      if (hit != null) {
        final now = DateTime.now();
        if (_lastHitAt != null &&
            now.difference(_lastHitAt!) < const Duration(milliseconds: 700)) {
          return;
        }
        _lastHitAt = now;
        final callback = onCode;
        stop();
        callback(hit);
        return;
      }
      _onPreviewQuality?.call(isMedicinePreviewBlurry());
    } catch (_) {
      // Keep polling; a single failed frame is normal.
    } finally {
      _busy = false;
    }
  }
}
