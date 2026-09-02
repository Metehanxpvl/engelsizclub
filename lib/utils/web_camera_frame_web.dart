// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:typed_data';

html.VideoElement? _liveVideo() {
  html.VideoElement? fallback;
  for (final node in html.document.querySelectorAll('video')) {
    if (node is! html.VideoElement) continue;
    if (node.videoWidth <= 0 || node.videoHeight <= 0) continue;
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

class WebLiveBarcodePoller {
  Timer? _timer;
  bool _busy = false;
  Object? _detector;
  bool _detectorUnavailable = false;

  void start(void Function(String code) onCode) {
    stop();
    _timer = Timer.periodic(const Duration(milliseconds: 320), (_) {
      unawaited(_tick(onCode));
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _busy = false;
  }

  Object? _ensureDetector() {
    if (_detectorUnavailable) return null;
    if (_detector != null) return _detector;
    if (!js_util.hasProperty(html.window, 'BarcodeDetector')) {
      _detectorUnavailable = true;
      return null;
    }
    final ctor = js_util.getProperty(html.window, 'BarcodeDetector');
    try {
      _detector = js_util.callConstructor(ctor, [
        js_util.jsify({
          'formats': [
            'ean_13',
            'ean_8',
            'upc_a',
            'upc_e',
            'qr_code',
            'code_128',
            'code_39',
            'itf',
            'data_matrix',
          ],
        }),
      ]);
    } catch (_) {
      try {
        _detector = js_util.callConstructor(ctor, []);
      } catch (_) {
        _detectorUnavailable = true;
        return null;
      }
    }
    return _detector;
  }

  Future<void> _tick(void Function(String code) onCode) async {
    if (_busy) return;
    final detector = _ensureDetector();
    if (detector == null) {
      if (_detectorUnavailable) stop();
      return;
    }
    final video = _liveVideo();
    if (video == null) return;
    _busy = true;
    try {
      prepareLiveVideosForScan();
      final canvas = _frameCanvas(video);
      final source = canvas ?? video;
      final detected = js_util.callMethod(detector, 'detect', [source]);
      final raw = await js_util.promiseToFuture<Object?>(detected);
      final code = _firstCode(raw);
      if (code != null) onCode(code);
    } catch (_) {
      // Keep polling; a single failed frame is normal.
    } finally {
      _busy = false;
    }
  }

  String? _firstCode(Object? raw) {
    if (raw == null) return null;
    final items = <Object?>[];
    if (raw is List) {
      items.addAll(raw);
    } else if (js_util.hasProperty(raw, 'length')) {
      final len = js_util.getProperty(raw, 'length');
      if (len is int) {
        for (var i = 0; i < len; i++) {
          items.add(js_util.getProperty(raw, i));
        }
      }
    }
    for (final item in items) {
      if (item == null) continue;
      try {
        final value = js_util.getProperty(item, 'rawValue');
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      } catch (_) {}
    }
    return null;
  }
}
