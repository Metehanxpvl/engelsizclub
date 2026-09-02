import 'dart:typed_data';

class WebBarcodeHit {
  const WebBarcodeHit({required this.text, this.format = ''});

  final String text;
  final String format;
}

Future<Uint8List?> captureLiveCameraJpeg({double quality = 0.88}) async =>
    null;

void prepareLiveVideosForScan() {}

void boostLiveCameraResolution() {}

bool isMedicinePreviewBlurry() => false;

bool isMedicineTorchAvailable() => false;

bool isMedicineTorchOn() => false;

bool toggleMedicineTorch([bool? on]) => false;

void tapMedicineFocus(double nx, double ny) {}

Future<WebBarcodeHit?> decodeWebBarcodeImage(Uint8List bytes) async => null;

String? webDecoderStatus() => null;

Future<WebBarcodeHit?> decodeMedicineLiveFrameAsync() async => null;

class WebLiveBarcodePoller {
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

  void start(
    void Function(WebBarcodeHit hit) onCode, {
    List<String>? formats,
    bool medicineMode = false,
    void Function(bool blurry)? onPreviewQuality,
  }) {}

  void stop() {}
}
