import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n/l10n_text.dart';
import '../meto_theme.dart';
import '../models/medicine_report.dart';
import '../models/product_safety.dart';
import '../services/e_number_explanations.dart';
import '../services/gemini_service.dart';
import '../services/medicine_repository.dart';
import '../services/product_repository.dart';
import '../services/prospectus_viewer.dart';
import '../services/image_optimize_service.dart';
import '../services/label_ocr.dart';
import '../services/mlkit_barcode.dart';
import '../services/product_disclaimer.dart';
import '../services/titck_skrs_index.dart';
import '../utils/gs1_barcode.dart';
import '../utils/web_camera_frame.dart';
import '../utils/web_session_tab.dart';
import '../widgets/additive_risk_bar.dart';
import '../widgets/medical_info_card.dart';
import '../widgets/nutri_nova_cards.dart';
import '../widgets/photo_gallery_lightbox.dart';

enum _TaramaMode { product, medicine }

void _openLabelPreview(
  BuildContext context, {
  String? url,
  Uint8List? bytes,
}) {
  final images = <ImageProvider>[];
  if (url != null && url.startsWith('http')) {
    images.add(NetworkImage(url));
  } else if (bytes != null && bytes.isNotEmpty) {
    images.add(MemoryImage(bytes));
  }
  if (images.isEmpty) return;
  unawaited(openPhotoGallery(context, images: images));
}

/// Barkod / etiket tarama + alerjen / çocuk uygunluğu özeti.
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({
    super.key,
    this.isGuest = false,
    this.embedded = false,
    this.isTabActive = true,
  });

  final bool isGuest;
  /// Alt menü sekmesi: geri tuşu yok, kamera yalnız sekme aktifken açık.
  final bool embedded;
  final bool isTabActive;

  static Future<void> open(
    BuildContext context, {
    bool isGuest = false,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BarcodeScannerScreen(isGuest: isGuest),
      ),
    );
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  /// Both Ürün and İlaç: 1D (EAN/UPC) + 2D (QR / Data Matrix). Product packs
  /// often show a karekod, not an EAN stripe, in the viewfinder.
  static const _scanFormats = <BarcodeFormat>[
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.qrCode,
    BarcodeFormat.dataMatrix,
    BarcodeFormat.pdf417,
    BarcodeFormat.aztec,
    BarcodeFormat.code128,
  ];

  final _picker = ImagePicker();
  final _webPoller = WebLiveBarcodePoller();
  final _nameQuery = TextEditingController();

  MobileScannerController? _camera;
  StreamSubscription<BarcodeCapture>? _barcodeSub;
  bool _handling = false;
  bool _loading = false;
  bool _cameraError = false;
  bool _ingredientsOpen = false;
  String? _status;
  String? _error;
  String? _pendingBarcode;
  String? _lastDetectedCode;
  DateTime? _lastDetectedAt;
  Uint8List? _labelPreview;
  ProductLookupResult? _result;
  MedicineLookupResult? _medicine;
  _TaramaMode _mode = _TaramaMode.product;
  List<ProductNameHit> _nameHits = const [];
  List<MedicineNameHit> _medicineHits = const [];
  bool _nameSearching = false;
  String? _nameSearchError;
  Timer? _medicineHintTimer;
  Timer? _seekingHintTimer;
  Timer? _decoderPollTimer;
  bool _showStepBackHint = false;
  bool _showSeekingHint = false;
  bool _decoderFailed = false;
  bool _torchAvailable = false;
  bool _torchOn = false;
  String? _flashGtin;
  String? _flashRaw;
  String? _lastScanRaw;

  bool get _isMedicine => _mode == _TaramaMode.medicine;

  bool get _hasFoundResult => _isMedicine
      ? _medicine?.isFound == true
      : _result?.product?.isFound == true;

  List<BarcodeFormat> get _activeFormats => _scanFormats;

  MobileScannerController _newController() => MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: kIsWeb ? 250 : 200,
        autoStart: false,
        formats: _scanFormats,
        cameraResolution: const Size(1920, 1080),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera = _newController();
    _listenBarcodes();
    unawaited(TitckSkrsIndex.ensureLoaded());
    if (widget.embedded && widget.isTabActive) {
      persistWebSessionTab('tarama');
    }
    if (widget.isTabActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isTabActive) unawaited(_startCamera());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!widget.isTabActive || _loading || _hasFoundResult) {
      return;
    }
    unawaited(_startCamera());
  }

  @override
  void didUpdateWidget(covariant BarcodeScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.embedded && widget.isTabActive) {
      persistWebSessionTab('tarama');
    }
    if (oldWidget.isTabActive == widget.isTabActive) return;
    if (widget.isTabActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isTabActive) unawaited(_startCamera());
      });
    } else {
      unawaited(_stopCamera());
    }
  }

  void _listenBarcodes() {
    _barcodeSub?.cancel();
    final cam = _camera;
    if (cam == null) return;
    _barcodeSub = cam.barcodes.listen(
      _onDetect,
      onError: (_, __) {},
      cancelOnError: false,
    );
  }

  Future<void> _startCamera({bool force = false}) async {
    if (!widget.isTabActive || _loading) return;
    if (!force && _hasFoundResult) return;
    _camera ??= _newController();
    _listenBarcodes();
    try {
      if (_camera!.value.isRunning) {
        if (mounted) setState(() => _cameraError = false);
        _onCameraLive();
        return;
      }
      await _camera!.start();
      if (_camera!.value.isRunning) {
        if (mounted) setState(() => _cameraError = false);
        _onCameraLive();
        return;
      }
      if (kIsWeb) {
        await _camera!.start(cameraDirection: CameraFacing.front);
        if (_camera!.value.isRunning) {
          if (mounted) setState(() => _cameraError = false);
          _onCameraLive();
          return;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _cameraError = true);
    _webPoller.stop();
  }

  void _onCameraLive() {
    if (!kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      prepareLiveVideosForScan();
      boostLiveCameraResolution();
      _webPoller.start(
        (hit) => _acceptBarcode(hit.text, format: hit.format),
        medicineMode: true,
        onPreviewQuality: (blurry) {
          if (!mounted || _handling || _loading) return;
          if (blurry == _showStepBackHint) return;
          setState(() => _showStepBackHint = blurry);
        },
      );
      debugPrint('Web tarama: ZXing 1D+2D poller start');
      _medicineHintTimer?.cancel();
      _seekingHintTimer?.cancel();
      _showStepBackHint = false;
      _showSeekingHint = false;
      _probeTorch();
      _probeDecoderStatus();
      _medicineHintTimer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        _probeTorch();
        _probeDecoderStatus();
      });
      _seekingHintTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted || _handling || _loading || _hasFoundResult) return;
        setState(() => _showSeekingHint = true);
      });
      _decoderPollTimer?.cancel();
      if (kIsWeb) {
        _decoderPollTimer = Timer.periodic(
          const Duration(milliseconds: 900),
          (_) => _probeDecoderStatus(),
        );
      }
      if (mounted) setState(() {});
    });
  }

  void _probeDecoderStatus() {
    if (!kIsWeb || !mounted) return;
    final status = webDecoderStatus();
    final failed = status == 'failed';
    if (failed == _decoderFailed) return;
    setState(() => _decoderFailed = failed);
    if (failed) _decoderPollTimer?.cancel();
  }

  void _probeTorch() {
    if (!kIsWeb || !mounted) return;
    final available = isMedicineTorchAvailable();
    final on = isMedicineTorchOn();
    if (available == _torchAvailable && on == _torchOn) return;
    setState(() {
      _torchAvailable = available;
      _torchOn = on;
    });
  }

  void _toggleTorch() {
    if (!kIsWeb) return;
    final ok = toggleMedicineTorch(!_torchOn);
    if (!ok) {
      _probeTorch();
      return;
    }
    setState(() => _torchOn = !_torchOn);
    Timer(const Duration(milliseconds: 250), () {
      if (mounted) _probeTorch();
    });
  }

  void _onScannerTap(TapDownDetails details, Size size) {
    if (!kIsWeb || size.width <= 0 || size.height <= 0) return;
    tapMedicineFocus(
      details.localPosition.dx / size.width,
      details.localPosition.dy / size.height,
    );
  }

  Future<void> _stopCamera() async {
    _webPoller.stop();
    _medicineHintTimer?.cancel();
    _seekingHintTimer?.cancel();
    _decoderPollTimer?.cancel();
    try {
      await _camera?.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webPoller.stop();
    _medicineHintTimer?.cancel();
    _seekingHintTimer?.cancel();
    _decoderPollTimer?.cancel();
    _nameQuery.dispose();
    unawaited(_barcodeSub?.cancel());
    unawaited(_camera?.dispose());
    super.dispose();
  }

  Future<void> _lookup(
    String raw, {
    Uint8List? labelBytes,
    String? ocrText,
    String? productHint,
    String? brandHint,
  }) async {
    final code = raw.trim();
    final hasPhoto = labelBytes != null && labelBytes.isNotEmpty;
    if (!hasPhoto && code.isEmpty) {
      _handling = false;
      return;
    }
    setState(() {
      _handling = true;
      _loading = true;
      _error = null;
      _pendingBarcode = code.isEmpty ? null : code;
      _status = hasPhoto
          ? 'Etiket inceleniyor…'
          : 'Etiket bilgisi tamamlanıyor…';
      _ingredientsOpen = true;
      _flashGtin = null;
      _flashRaw = null;
      _showSeekingHint = false;
      if (hasPhoto) _labelPreview = labelBytes;
    });
    _webPoller.stop();
    try {
      await _camera?.stop();
    } catch (_) {}

    try {
      final result = await ProductRepository.lookup(
        code,
        labelImageBytes: labelBytes,
        ocrText: ocrText?.trim(),
        productHint: productHint,
        brandHint: brandHint,
      ).timeout(
        const Duration(seconds: 50),
        onTimeout: () => ProductLookupResult(
          status: ProductLookupStatus.notFound,
          barcode: code.isEmpty ? null : code,
          error: GeminiService.modelUnavailableMessage,
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
        _handling = false;
        _status = null;
        _pendingBarcode = result.barcode ?? code;
        final found = result.product?.isFound == true;
        if (found) {
          _error = result.product!.hasUsableIngredients
              ? null
              : result.error;
        } else {
          _error = result.error ??
              (result.needsKey
                  ? ProductRepository.needsKeyMessage
                  : 'Ürün bulunamadı. Barkodu tekrar deneyin veya isteğe bağlı etiket fotoğrafı ekleyin.');
        }
      });
      if (result.product?.isFound != true && widget.isTabActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              widget.isTabActive &&
              _result?.product?.isFound != true) {
            unawaited(_startCamera());
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _handling = false;
        _status = null;
        _error = GeminiService.modelUnavailableMessage;
      });
      if (widget.isTabActive) unawaited(_startCamera());
    } finally {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _handling = false;
          _status = null;
        });
      }
    }
  }

  bool _isSameMedicineRecord(MedicineRecord a, MedicineRecord b) {
    if (a.id != null && b.id != null && a.id == b.id) return true;
    final ac = (a.barcode ?? '').trim();
    final bc = (b.barcode ?? '').trim();
    if (ac.length >= 4 && ac == bc) return true;
    final an = a.medicineName.trim().toLowerCase();
    final bn = b.medicineName.trim().toLowerCase();
    return an.length >= 2 && an == bn;
  }

  /// Ad geldi, resmi KT yoksa TİTCK KÜB/KT’yi kartı bozmadan bağla.
  Future<void> _enrichMedicineLeaflet() async {
    final current = _medicine;
    final rec = current?.record;
    if (rec == null || !rec.needsLeaflet) return;
    final updated = await MedicineRepository.attachOfficialProspectus(rec);
    if (!mounted || !updated.hasOfficialProspectus) return;
    final shown = _medicine?.record;
    if (shown == null || !_isSameMedicineRecord(shown, rec)) return;
    setState(() {
      _medicine = MedicineLookupResult(
        record: updated,
        barcode: current?.barcode ?? updated.barcode,
        fromCache: current?.fromCache ?? false,
        error: current?.error,
        needsPhoto: current?.needsPhoto ?? false,
        needsKey: current?.needsKey ?? false,
      );
    });
  }

  Future<void> _lookupMedicine(
    String raw, {
    Uint8List? labelBytes,
    String? ocrText,
  }) async {
    final parsed = Gs1Barcode.lookupCode(raw);
    final code = (parsed ?? raw).trim();
    final hasPhoto = labelBytes != null && labelBytes.isNotEmpty;
    if (!hasPhoto && code.isEmpty) {
      _handling = false;
      return;
    }
    setState(() {
      _handling = true;
      _loading = true;
      _error = null;
      _pendingBarcode = code.isEmpty ? null : code;
      _status = hasPhoto
          ? 'Küpür / prospektüs inceleniyor…'
          : 'Karekod ile prospektüs aranıyor…';
      _flashGtin = null;
      _flashRaw = null;
      _showStepBackHint = false;
      _showSeekingHint = false;
      if (hasPhoto) _labelPreview = labelBytes;
    });
    _webPoller.stop();
    try {
      await _camera?.stop();
    } catch (_) {}

    try {
      final result = await MedicineRepository.lookup(
        barcode: code,
        imageBytes: labelBytes,
        ocrText: ocrText?.trim(),
      ).timeout(
        const Duration(seconds: 50),
        onTimeout: () => MedicineLookupResult(
          barcode: code.isEmpty ? null : code,
          error: GeminiService.modelUnavailableMessage,
        ),
      );
      if (!mounted) return;
      setState(() {
        _medicine = result;
        _loading = false;
        _handling = false;
        _status = null;
        _pendingBarcode = result.barcode ?? code;
        _error = result.isFound
            ? null
            : (result.error ??
                (result.needsKey
                    ? MedicineRepository.needsKeyMessage
                    : MedicineRepository.needsPhotoMessage));
      });
      if (result.isFound) unawaited(_enrichMedicineLeaflet());
      if (!result.isFound && widget.isTabActive) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && widget.isTabActive && _medicine?.isFound != true) {
            unawaited(_startCamera());
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _handling = false;
        _status = null;
        _error = GeminiService.modelUnavailableMessage;
      });
      if (widget.isTabActive) unawaited(_startCamera());
    } finally {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _handling = false;
          _status = null;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final raw = (b.rawValue ?? b.displayValue)?.trim();
      if (raw == null || raw.isEmpty) continue;
      _acceptBarcode(raw, format: b.format.name);
      return;
    }
  }

  void _logScanHit(String raw, String format) {
    final gtin = Gs1Barcode.lookupCode(raw);
    final forms = Gs1Barcode.lookupCandidates(raw)
        .map((c) => '${c.form}:${c.value}')
        .take(6)
        .join(',');
    final clipped = raw.replaceAll(RegExp(r'[\x00-\x1f]'), '');
    final preview = gtin ??
        (clipped.length <= 20 ? clipped : '${clipped.substring(0, 20)}…');
    debugPrint(
      'Tarama hit format=$format payload=$preview len=${raw.length} forms=$forms',
    );
  }

  String _lookupKey(String raw) {
    final t = raw.trim();
    return Gs1Barcode.lookupCode(t) ?? t;
  }

  String _flashPreview(String raw) {
    final clipped = raw.replaceAll(RegExp(r'[\x00-\x1f]'), '').trim();
    if (clipped.length <= 36) return clipped;
    return '${clipped.substring(0, 36)}…';
  }

  void _acceptBarcode(String raw, {String format = ''}) {
    final original = raw.trim();
    if (!mounted || original.isEmpty || _handling || _loading || _hasFoundResult) {
      return;
    }
    _logScanHit(original, format);
    final code = _lookupKey(original);
    if (!_isMedicine && _result != null && _lastDetectedCode == code) return;
    if (_isMedicine && _medicine != null && _lastDetectedCode == code) return;
    final now = DateTime.now();
    if (_lastDetectedCode == code &&
        _lastDetectedAt != null &&
        now.difference(_lastDetectedAt!) < const Duration(milliseconds: 1600)) {
      return;
    }
    _lastDetectedCode = code;
    _lastDetectedAt = now;
    _lastScanRaw = original;
    _handling = true;
    _webPoller.stop();
    _medicineHintTimer?.cancel();
    _seekingHintTimer?.cancel();
    setState(() {
      _flashRaw = _flashPreview(original);
      _flashGtin = Gs1Barcode.lookupCode(original) ?? code;
      _showStepBackHint = false;
      _showSeekingHint = false;
    });
    Future.microtask(() {
      if (!mounted) return;
      unawaited(_lookupAfterFlash(code));
    });
  }

  Future<void> _lookupAfterFlash(String code) async {
    // Okundu paints first; TITCK/Gemini stay off this animation frame.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    if (_isMedicine) {
      await _lookupMedicine(_lastScanRaw ?? code);
    } else {
      await _lookup(code);
    }
  }

  Future<void> _captureFromLiveCamera() async {
    if (_handling || _loading) return;
    _handling = true;
    persistWebSessionTab('tarama');
    if (kIsWeb && _camera?.value.isRunning != true) {
      await _startCamera(force: true);
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
    prepareLiveVideosForScan();
    Uint8List? rawBytes;
    try {
      rawBytes = await captureLiveCameraJpeg();
    } catch (_) {
      rawBytes = null;
    }
    if (rawBytes == null || rawBytes.isEmpty) {
      _handling = false;
      if (!mounted) return;
      setState(() {
        _error =
            'Kameradan kare alınamadı. Barkodu çerçeveye hizalayın veya galeriden seçin.';
      });
      if (widget.isTabActive) unawaited(_startCamera());
      return;
    }
    OptimizedImage? optimized;
    try {
      optimized = await ImageOptimizeService.forLabelScan(rawBytes);
    } catch (_) {}
    final bytes = optimized?.bytes ?? rawBytes;
    String? fromFrame;
    if (kIsWeb) {
      final hit = await decodeWebBarcodeImage(bytes);
      if (hit != null) {
        _logScanHit(hit.text, hit.format.isEmpty ? 'still' : hit.format);
        fromFrame = hit.text;
      }
    } else {
      fromFrame = await MlkitBarcode.scanBytes(bytes);
      if (fromFrame != null) {
        _logScanHit(fromFrame, 'mlkit');
      }
    }
    final code = _lookupKey(fromFrame ?? _pendingBarcode ?? '');
    if (_isMedicine) {
      await _lookupMedicine(code, labelBytes: bytes);
    } else {
      await _lookup(code, labelBytes: bytes);
    }
  }

  Future<void> _pickLabel({required bool camera}) async {
    if (_handling) return;
    persistWebSessionTab('tarama');
    final liveScannerVisible = kIsWeb &&
        camera &&
        widget.isTabActive &&
        _camera?.value.isRunning == true &&
        _result == null &&
        _medicine == null;
    if (liveScannerVisible) {
      await _captureFromLiveCamera();
      return;
    }
    try {
      await _camera?.stop();
    } catch (_) {}
    _webPoller.stop();
    try {
      final file = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: CameraDevice.rear,
        requestFullMetadata: false,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) {
        if (widget.isTabActive) unawaited(_startCamera());
        return;
      }
      if (!mounted) return;

      setState(() {
        _handling = true;
        _loading = true;
        _status = _isMedicine
            ? 'Küpür / prospektüs inceleniyor…'
            : 'Etiket inceleniyor…';
        _error = null;
      });

      final rawBytes = await file.readAsBytes();
      String? fromImage;
      if (kIsWeb) {
        final hit = await decodeWebBarcodeImage(rawBytes);
        if (hit != null) {
          _logScanHit(hit.text, hit.format.isEmpty ? 'still' : hit.format);
          fromImage = hit.text;
        }
      } else {
        fromImage = await _barcodeFromImage(file);
      }
      var ocr = '';
      if (!kIsWeb && file.path.isNotEmpty) {
        ocr = await LabelOcr.readFromPath(file.path);
      }
      OptimizedImage? optimized;
      try {
        optimized = await ImageOptimizeService.forLabelScan(rawBytes);
      } catch (_) {}
      final bytes = optimized?.bytes ?? rawBytes;

      final code = _lookupKey(fromImage ?? _pendingBarcode ?? '');
      if (_isMedicine) {
        await _lookupMedicine(
          code,
          labelBytes: bytes,
          ocrText: ocr.isNotEmpty ? ocr : null,
        );
      } else {
        await _lookup(
          code,
          labelBytes: bytes,
          ocrText: ocr.isNotEmpty ? ocr : null,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _handling = false;
        _status = null;
        _error = 'Görsel okunamadı. Kamerayı tekrar deneyin veya galeriden seçin.';
      });
      if (widget.isTabActive) unawaited(_startCamera());
    }
  }

  Future<String?> _barcodeFromImage(XFile file) async {
    if (kIsWeb) return null;
    final path = file.path;
    if (path.isEmpty) return null;
    final ml = await MlkitBarcode.scanPath(path);
    if (ml != null && ml.trim().isNotEmpty) return ml.trim();
    MobileScannerController? probe;
    try {
      probe = MobileScannerController(formats: _activeFormats);
      final capture = await probe.analyzeImage(path);
      final barcodes = capture?.barcodes ?? const <Barcode>[];
      String? first;
      for (final b in barcodes) {
        final raw = (b.rawValue ?? b.displayValue)?.trim() ?? '';
        if (raw.isEmpty) continue;
        first ??= raw;
        if (b.format == BarcodeFormat.dataMatrix ||
            b.format == BarcodeFormat.qrCode ||
            b.format == BarcodeFormat.pdf417 ||
            b.format == BarcodeFormat.aztec) {
          return raw;
        }
      }
      return first;
    } catch (_) {
      return null;
    } finally {
      await probe?.dispose();
    }
  }

  Future<void> _resetScan({bool recreateCamera = false}) async {
    _webPoller.stop();
    _medicineHintTimer?.cancel();
    _seekingHintTimer?.cancel();
    _decoderPollTimer?.cancel();
    MobileScannerController? old;
    if (recreateCamera) {
      await _barcodeSub?.cancel();
      _barcodeSub = null;
      try {
        await _camera?.stop();
      } catch (_) {}
      old = _camera;
    }
    setState(() {
      _result = null;
      _medicine = null;
      _error = null;
      _status = null;
      _loading = false;
      _handling = false;
      _ingredientsOpen = false;
      _pendingBarcode = null;
      _lastDetectedCode = null;
      _lastDetectedAt = null;
      _lastScanRaw = null;
      _labelPreview = null;
      _nameHits = const [];
      _medicineHits = const [];
      _nameSearching = false;
      _nameSearchError = null;
      _showStepBackHint = false;
      _showSeekingHint = false;
      _decoderFailed = false;
      _torchAvailable = false;
      _torchOn = false;
      _flashGtin = null;
      _flashRaw = null;
      if (recreateCamera) {
        _camera = _newController();
      }
    });
    if (recreateCamera) {
      _listenBarcodes();
      try {
        await old?.dispose();
      } catch (_) {}
    }
    _nameQuery.clear();
    if (widget.isTabActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isTabActive) unawaited(_startCamera());
      });
    }
  }

  Future<void> _setMode(_TaramaMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await _resetScan(recreateCamera: true);
  }

  Future<void> _searchByName() async {
    if (_isMedicine) {
      await _searchMedicineByName();
      return;
    }
    final q = _nameQuery.text.trim();
    FocusManager.instance.primaryFocus?.unfocus();
    if (q.length < 2) {
      setState(() {
        _nameHits = const [];
        _medicineHits = const [];
        _nameSearchError = 'En az 2 karakter yazın.';
      });
      return;
    }
    if (_nameSearching || _loading) return;
    setState(() {
      _nameSearching = true;
      _nameSearchError = null;
      _medicineHits = const [];
    });
    try {
      var hits = await ProductRepository.searchByName(q);
      if (!mounted) return;
      if (hits.isEmpty && GeminiService.canCall) {
        setState(() {
          _nameHits = const [];
          _nameSearchError =
              'Önbellekte yok; bilgi amaçlı özet hazırlanıyor…';
        });
        final geminiHit = await ProductRepository.searchNameWithGemini(q);
        if (!mounted) return;
        if (geminiHit != null) {
          hits = [geminiHit];
        }
      }
      if (!mounted) return;
      setState(() {
        _nameHits = hits;
        _nameSearching = false;
        _nameSearchError = hits.isEmpty
            ? 'Bu ada yakın ürün bulunamadı. Barkodu tarayın veya etiket fotoğrafı ekleyin.'
            : null;
      });
      if (hits.length == 1 && hits.first.source == 'llm') {
        await _selectNameHit(hits.first);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nameSearching = false;
        _nameHits = const [];
        _nameSearchError =
            'Arama tamamlanamadı. Bağlantıyı kontrol edip tekrar deneyin.';
      });
    }
  }

  Future<void> _searchMedicineByName() async {
    final q = _nameQuery.text.trim();
    FocusManager.instance.primaryFocus?.unfocus();
    if (q.length < 2) {
      setState(() {
        _medicineHits = const [];
        _nameHits = const [];
        _nameSearchError = 'En az 2 karakter yazın.';
      });
      return;
    }
    if (_nameSearching || _loading) return;
    setState(() {
      _nameSearching = true;
      _nameSearchError = null;
      _nameHits = const [];
    });
    try {
      final cacheHits = await MedicineRepository.searchByName(q);
      if (!mounted) return;
      setState(() {
        _medicineHits = cacheHits;
        if (cacheHits.length < 3) {
          _nameSearchError = cacheHits.isEmpty
              ? 'Önbellekte yok; bilgi amaçlı özet hazırlanıyor…'
              : 'Az sonuç; bilgi amaçlı özet hazırlanıyor…';
        }
      });

      if (cacheHits.length < 3) {
        final llm = await MedicineRepository.lookupByName(q);
        if (!mounted) return;
        final rec = llm.record;
        var hits = List<MedicineNameHit>.from(cacheHits);
        if (rec != null && rec.isFound) {
          final key = rec.medicineName.trim().toLowerCase();
          final exists = hits.any(
            (h) => h.name.trim().toLowerCase() == key,
          );
          if (!exists) {
            hits = [
              ...hits,
              MedicineNameHit(
                name: rec.medicineName.trim().isEmpty
                    ? q
                    : rec.medicineName.trim(),
                activeIngredient: rec.activeIngredient.trim(),
                record: rec,
                source: llm.fromCache ? 'cache' : 'llm',
              ),
            ];
          }
        }
        setState(() {
          _medicineHits = hits;
          _nameSearching = false;
          if (hits.isEmpty) {
            final err = llm.error ?? GeminiService.lastError;
            if (llm.needsKey) {
              _nameSearchError = MedicineRepository.needsKeyMessage;
            } else if (GeminiService.isTransportError(err)) {
              _nameSearchError = err ??
                  'Analiz isteği gönderilemedi. Bağlantıyı kontrol edin.';
            } else {
              _nameSearchError = err ??
                  'Bu ada yakın ilaç bulunamadı. İsterseniz küpür fotoğrafı ekleyebilirsiniz (isteğe bağlı).';
            }
          } else {
            _nameSearchError = null;
          }
        });
        return;
      }

      setState(() {
        _nameSearching = false;
        _nameSearchError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nameSearching = false;
        if (_medicineHits.isEmpty) {
          _nameSearchError =
              'Arama tamamlanamadı. Bağlantıyı kontrol edip tekrar deneyin.';
        } else {
          _nameSearchError = null;
        }
      });
    }
  }

  Future<void> _selectNameHit(ProductNameHit hit) async {
    if (_loading || _handling) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _lookup(
      hit.cacheKey,
      productHint: hit.name,
      brandHint: hit.brand,
    );
  }

  Future<void> _selectMedicineHit(MedicineNameHit hit) async {
    if (_loading || _handling) return;
    final rec = hit.record;
    FocusManager.instance.primaryFocus?.unfocus();
    if (rec != null && rec.isComplete) {
      _webPoller.stop();
      try {
        await _camera?.stop();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _medicine = MedicineLookupResult(
          record: rec,
          barcode: rec.barcode,
          fromCache: hit.source == 'cache',
        );
        _error = null;
        _nameHits = const [];
        _medicineHits = const [];
        _nameSearchError = null;
        _nameSearching = false;
      });
      // Özet tam olsa bile resmi KT yoksa TİTCK’yi arka planda dene.
      unawaited(_enrichMedicineLeaflet());
      return;
    }
    final name = rec?.hasUsefulName == true
        ? rec!.medicineName.trim()
        : hit.name.trim();
    if (name.length < 2 && (rec?.barcode ?? '').trim().length < 4) return;
    setState(() {
      _handling = true;
      _loading = true;
      _error = null;
      _status = 'İlaç bilgisi aranıyor…';
    });
    _webPoller.stop();
    try {
      await _camera?.stop();
    } catch (_) {}
    final seed = rec ??
        MedicineRecord(
          medicineName: name,
          source: 'titck',
        );
    try {
      final result = await MedicineRepository.lookupFromHit(
        name: name,
        barcode: (rec?.barcode ?? '').trim(),
        hint: rec,
      ).timeout(
        const Duration(seconds: 70),
        onTimeout: () => MedicineLookupResult(
          record: seed.isFound ? seed : null,
          barcode: seed.barcode,
          error: seed.isFound
              ? null
              : GeminiService.modelUnavailableMessage,
        ),
      );
      if (!mounted) return;
      setState(() {
        _medicine = result.isFound
            ? result
            : (seed.isFound
                ? MedicineLookupResult(
                    record: seed,
                    barcode: seed.barcode,
                  )
                : result);
        _loading = false;
        _handling = false;
        _status = null;
        _error = (result.isFound || seed.isFound) ? null : result.error;
        _nameHits = const [];
        _medicineHits = const [];
        _nameSearchError = null;
      });
      if (_medicine?.isFound == true) unawaited(_enrichMedicineLeaflet());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (seed.isFound) {
          _medicine = MedicineLookupResult(
            record: seed,
            barcode: seed.barcode,
          );
          _error = null;
        } else {
          _error = 'Arama hatası: $e';
        }
        _loading = false;
        _handling = false;
        _status = null;
      });
      if (seed.isFound) unawaited(_enrichMedicineLeaflet());
    }
  }

  Future<void> _showPhotoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: MetoColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isMedicine
                      ? 'Küpür / prospektüs fotoğrafı'
                      : 'Etiket fotoğrafı',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                L10nText(
                  _isMedicine
                      ? 'İlaç kutusunun arka yüzünü (küpür) veya prospektüsü yakından net çekin. Ön yüz yetmez.'
                      : 'İÇİNDEKİLER / INGREDIENTS yazısının yakından net fotoğrafını çekin. Paketin ön yüzü yetmez.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MetoColors.mutedFg,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined,
                      color: MetoColors.primary),
                  title: L10nText(
                    kIsWeb ? 'Fotoğraf çek' : 'Kamera ile çek',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (kIsWeb) {
                      unawaited(_captureFromLiveCamera());
                    } else {
                      unawaited(_pickLabel(camera: true));
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined,
                      color: MetoColors.primary),
                  title: const L10nText('Galeriden seç'),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(_pickLabel(camera: false));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final foundProduct =
        !_loading && !_isMedicine && _result?.product?.isFound == true;
    final foundMedicine =
        !_loading && _isMedicine && _medicine?.isFound == true;
    final foundAny = foundProduct || foundMedicine;

    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        automaticallyImplyLeading: !widget.embedded,
        title: L10nText(
          _isMedicine ? kMedicineAnalysisTitle : kProductAnalysisTitle,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        leading: widget.embedded
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildModeSwitch(),
          const SizedBox(height: 12),
          if (!foundAny) ...[
            MedicalInfoCard(
              title: _isMedicine
                  ? 'İlaç prospektüs / küpür analizi'
                  : 'Ürün / içerik analizi',
              body: _isMedicine
                  ? kMedicineAnalysisDisclaimer
                  : kProductAnalysisDisclaimer,
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 12),
            _buildNameSearchBar(),
            if (_loading || _nameSearching) ...[
              const SizedBox(height: 8),
              _ExaminingLoader(status: _visibleSearchStatus),
            ],
            if (_nameHits.isNotEmpty ||
                _medicineHits.isNotEmpty ||
                (_nameSearchError != null &&
                    _nameSearchError!.trim().isNotEmpty &&
                    !_nameSearching)) ...[
              const SizedBox(height: 8),
              _buildNameSearchResults(),
            ],
            const SizedBox(height: 12),
            _buildScannerCard(),
            const SizedBox(height: 12),
            ..._photoActionButtons(),
          ],
          if (!_loading && _error != null && !foundAny) ...[
            const SizedBox(height: 16),
            _NotFoundCard(
              message: _error!,
              onRetry: _resetScan,
            ),
          ],
          if (foundProduct) ...[
            if (kIsWeb &&
                widget.isTabActive &&
                _camera != null &&
                !_cameraError)
              Offstage(
                offstage: true,
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: MobileScanner(
                    controller: _camera!,
                    fit: BoxFit.cover,
                    onDetect: _onDetect,
                  ),
                ),
              ),
            _ProductResultCard(
              product: _result!.product!,
              fromCache: _result!.status == ProductLookupStatus.cached,
              previewBytes: _labelPreview,
              ingredientsOpen: _ingredientsOpen,
              hint: _error,
              onToggleIngredients: () {
                setState(() => _ingredientsOpen = !_ingredientsOpen);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _resetScan,
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                minimumSize: const Size.fromHeight(48),
                textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              child: const L10nText('Yeni tarama'),
            ),
          ],
          if (foundMedicine) ...[
            if (kIsWeb &&
                widget.isTabActive &&
                _camera != null &&
                !_cameraError)
              Offstage(
                offstage: true,
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: MobileScanner(
                    controller: _camera!,
                    fit: BoxFit.cover,
                    onDetect: _onDetect,
                  ),
                ),
              ),
            _MedicineResultCard(
              medicine: _medicine!.record!,
              fromCache: _medicine!.fromCache,
              previewBytes: _labelPreview,
              isGuest: widget.isGuest,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _resetScan,
              style: FilledButton.styleFrom(
                backgroundColor: MetoColors.primary,
                minimumSize: const Size.fromHeight(48),
                textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
              ),
              child: const L10nText('Yeni tarama'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _photoActionButtons() {
    return [
      FilledButton.icon(
        onPressed: _loading
            ? null
            : (kIsWeb ? _captureFromLiveCamera : _showPhotoSheet),
        icon: const Icon(Icons.photo_camera_outlined),
        label: L10nText(
          kIsWeb
              ? (_isMedicine
                  ? 'Küpür / prospektüs fotoğrafı'
                  : 'Etiket fotoğrafı')
              : (_isMedicine
                  ? 'Küpür fotoğrafı çek / galeriden seç'
                  : 'Etiket fotoğrafı çek / galeriden seç'),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: MetoColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      if (kIsWeb) ...[
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed:
              _loading ? null : () => unawaited(_pickLabel(camera: false)),
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: const L10nText('Galeriden seç'),
        ),
      ],
    ];
  }

  Widget _buildModeSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: MetoColors.muted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetoColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'Ürün',
              selected: !_isMedicine,
              onTap: _loading
                  ? null
                  : () => unawaited(_setMode(_TaramaMode.product)),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'İlaç',
              selected: _isMedicine,
              onTap: _loading
                  ? null
                  : () => unawaited(_setMode(_TaramaMode.medicine)),
            ),
          ),
        ],
      ),
    );
  }

  String get _visibleSearchStatus {
    final status = _status?.trim();
    if (status != null && status.isNotEmpty) return status;
    if (_isMedicine) return 'İlaç bilgisi aranıyor…';
    if (_nameSearching) return 'Ürün bilgisi aranıyor…';
    return 'Etiket bilgisi aranıyor…';
  }

  Widget _buildNameSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MetoColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      child: Row(
        children: [
          const Icon(Icons.search, size: 20, color: MetoColors.mutedFg),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _nameQuery,
              enabled: !_loading,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => unawaited(_searchByName()),
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: MetoColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: _isMedicine ? 'İlaç adı ile ara' : 'Ürün adı ile ara',
                hintStyle: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: MetoColors.mutedFg,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          if (_nameQuery.text.isNotEmpty)
            IconButton(
              onPressed: _loading
                  ? null
                  : () {
                      _nameQuery.clear();
                      setState(() {
                        _nameHits = const [];
                        _medicineHits = const [];
                        _nameSearchError = null;
                      });
                    },
              icon: const Icon(Icons.close, size: 18, color: MetoColors.mutedFg),
              visualDensity: VisualDensity.compact,
              tooltip: 'Temizle',
            ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: (_loading || _nameSearching) ? null : _searchByName,
            style: FilledButton.styleFrom(
              backgroundColor: MetoColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: const Size(0, 40),
              textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
            child: _nameSearching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const L10nText('Ara'),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSearchResults() {
    if (_isMedicine) return _buildMedicineNameSearchResults();
    if (_nameSearching && _nameHits.isEmpty) {
      return L10nText(
        'Ada göre aranıyor…',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: MetoColors.mutedFg,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_nameSearchError != null && _nameSearchError!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: L10nText(
              _nameSearchError!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MetoColors.mutedFg,
                height: 1.35,
              ),
            ),
          ),
        for (final hit in _nameHits)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: MetoColors.card,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _loading ? null : () => unawaited(_selectNameHit(hit)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MetoColors.border),
                  ),
                  child: Row(
                    children: [
                      _NameHitThumb(url: hit.imageUrl),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hit.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                height: 1.25,
                                color: MetoColors.foreground,
                              ),
                            ),
                            if ((hit.brand ?? '').trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                hit.brand!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ],
                            Text(
                              hit.source == 'cache'
                                  ? 'Önbellek'
                                  : hit.source == 'llm'
                                      ? 'Bilgi amaçlı özet'
                                      : 'Open Food Facts',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: MetoColors.mutedFg,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMedicineNameSearchResults() {
    if (_nameSearching && _medicineHits.isEmpty) {
      return L10nText(
        'İlaç adı aranıyor…',
        style: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: MetoColors.mutedFg,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_nameSearchError != null && _nameSearchError!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: L10nText(
              _nameSearchError!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MetoColors.mutedFg,
                height: 1.35,
              ),
            ),
          ),
        for (final hit in _medicineHits)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: MetoColors.card,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _loading
                    ? null
                    : () => unawaited(_selectMedicineHit(hit)),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: MetoColors.border),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: ColoredBox(
                            color: Color(0xFFF1F5F9),
                            child: Icon(
                              Icons.medication_outlined,
                              color: MetoColors.mutedFg,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hit.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                height: 1.25,
                                color: MetoColors.foreground,
                              ),
                            ),
                            if (hit.activeIngredient.trim().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                hit.activeIngredient.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: MetoColors.mutedFg,
                                ),
                              ),
                            ],
                            Text(
                              hit.source == 'cache'
                                  ? 'Önbellek'
                                  : hit.source == 'titck'
                                      ? 'TİTCK SKRS'
                                      : 'Bilgi amaçlı özet',
                              style: GoogleFonts.nunito(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: MetoColors.mutedFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: MetoColors.mutedFg,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildScannerCard() {
    final keepScanner = widget.isTabActive &&
        !_cameraError &&
        _camera != null &&
        !_hasFoundResult;
    final showHint = keepScanner && !_loading;
    final hintText = _showStepBackHint
        ? 'Biraz uzaklaşın, netlensin (20–40 cm)'
        : 'Kodu 20–40 cm uzaktan çerçevede tutun';
    final flashText = (_flashRaw ?? _flashGtin ?? '').trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 400,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: MetoColors.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final frameW = constraints.maxWidth * 0.86;
            final frameH = constraints.maxHeight * 0.86;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (keepScanner)
                  MobileScanner(
                    controller: _camera!,
                    fit: BoxFit.cover,
                    onDetect: _onDetect,
                    errorBuilder: (context, error, child) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted &&
                            !_cameraError &&
                            _camera?.value.isRunning != true) {
                          setState(() => _cameraError = true);
                        }
                      });
                      return const SizedBox.shrink();
                    },
                  )
                else
                  ColoredBox(
                    color: MetoColors.primaryDark,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            L10nText(
                              _cameraError
                                  ? 'Kameraya erişilemedi. Adres çubuğundan kamera izni verin veya etiket fotoğrafı çekin.'
                                  : _hasFoundResult
                                      ? 'Yeni tarama için aşağıdaki düğmeyi kullanın.'
                                      : widget.isTabActive
                                          ? 'Kamera açılıyor… Kodu 20–40 cm uzaktan çerçevede tutun.'
                                          : 'Kamera bu sekmede açılır.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            if (_cameraError && !_hasFoundResult) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() => _cameraError = false);
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) unawaited(_startCamera());
                                  });
                                },
                                child: const L10nText(
                                  'Kamerayı tekrar dene',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                if (keepScanner)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTapDown: (details) => _onScannerTap(
                        details,
                        Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: frameW,
                      height: frameH,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (keepScanner && _decoderFailed)
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE2B91C1C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Karekod okuyucu yüklenemedi',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (keepScanner &&
                    _showSeekingHint &&
                    flashText.isEmpty &&
                    !_loading)
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Kamera açık, kod aranıyor…',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showHint)
                  Positioned(
                    left: 12,
                    right: _torchAvailable ? 52 : 12,
                    bottom: 10,
                    child: IgnorePointer(
                      child: L10nText(
                        hintText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (keepScanner && _torchAvailable)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: IconButton(
                      tooltip: _torchOn ? 'Flaşı kapat' : 'Flaş',
                      onPressed: _toggleTorch,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                      icon: Icon(
                        _torchOn ? Icons.flash_on : Icons.flash_off,
                      ),
                    ),
                  ),
                if (flashText.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 10,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE2166B4A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Okundu: $flashText',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? MetoColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1.1,
              color: selected ? Colors.white : MetoColors.primaryDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _NameHitThumb extends StatelessWidget {
  const _NameHitThumb({this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final src = (url ?? '').trim();
    const size = 44.0;
    Widget child = const ColoredBox(
      color: Color(0xFFF1F5F9),
      child: Icon(Icons.inventory_2_outlined, color: MetoColors.mutedFg, size: 22),
    );
    if (src.startsWith('http')) {
      child = Image.network(
        src,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const ColoredBox(
          color: Color(0xFFF1F5F9),
          child: Icon(
            Icons.inventory_2_outlined,
            color: MetoColors.mutedFg,
            size: 22,
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: size, height: size, child: child),
    );
  }
}

class _NotFoundCard extends StatelessWidget {
  const _NotFoundCard({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MetoColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, color: MetoColors.mutedFg, size: 36),
          const SizedBox(height: 8),
          L10nText(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const L10nText('Tekrar dene'),
          ),
        ],
      ),
    );
  }
}

class _MedicineResultCard extends StatelessWidget {
  const _MedicineResultCard({
    required this.medicine,
    required this.fromCache,
    this.previewBytes,
    this.isGuest = false,
  });

  final MedicineRecord medicine;
  final bool fromCache;
  final Uint8List? previewBytes;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MedicineIdentityHeader(
          medicine: medicine,
          fromCache: fromCache,
          previewBytes: previewBytes,
        ),
        const SizedBox(height: 14),
        if (medicine.hasProspectusDetails) ...[
          FilledButton.icon(
            onPressed: () => _MedicineProspectusPage.open(
              context,
              medicine: medicine,
              previewBytes: previewBytes,
              isGuest: isGuest,
            ),
            icon: const Icon(Icons.menu_book_rounded),
            label: const L10nText('Prospektüs görüntüle'),
            style: FilledButton.styleFrom(
              backgroundColor: MetoColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: GoogleFonts.nunito(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (medicine.hasOfficialProspectus || medicine.hasUsefulName)
          _OfficialProspectusButton(
            medicine: medicine,
            isGuest: isGuest,
            prominent: !medicine.hasProspectusDetails,
          ),
        const SizedBox(height: 16),
        _MedicineProspectusSections(medicine: medicine),
      ],
    );
  }
}

class _OfficialProspectusButton extends StatefulWidget {
  const _OfficialProspectusButton({
    required this.medicine,
    this.isGuest = false,
    this.prominent = false,
  });

  final MedicineRecord medicine;
  final bool isGuest;
  final bool prominent;

  @override
  State<_OfficialProspectusButton> createState() =>
      _OfficialProspectusButtonState();
}

class _OfficialProspectusButtonState extends State<_OfficialProspectusButton> {
  late MedicineRecord _medicine;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _medicine = widget.medicine;
  }

  @override
  void didUpdateWidget(_OfficialProspectusButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.medicine.prospectusUrl != oldWidget.medicine.prospectusUrl ||
        widget.medicine.medicineName != oldWidget.medicine.medicineName) {
      _medicine = widget.medicine;
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    var rec = _medicine;
    if (!rec.hasOfficialProspectus && rec.needsLeaflet) {
      setState(() => _busy = true);
      rec = await MedicineRepository.attachOfficialProspectus(rec);
      if (!mounted) return;
      setState(() {
        _medicine = rec;
        _busy = false;
      });
    }
    if (!mounted) return;
    if (rec.hasOfficialProspectus) {
      await ProspectusViewer.open(
        context,
        url: rec.prospectusUrl!.trim(),
        title: 'Resmi kullanma talimatı (TİTCK)',
        isGuest: widget.isGuest,
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Prospektüs bulunamadı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = _busy
        ? 'Resmi kullanma talimatı aranıyor…'
        : 'Resmi kullanma talimatı (TİTCK)';
    if (widget.prominent) {
      return FilledButton.icon(
        onPressed: _busy ? null : _open,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.menu_book_rounded),
        label: L10nText(label),
        style: FilledButton.styleFrom(
          backgroundColor: MetoColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: MetoColors.primary.withValues(alpha: 0.7),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.nunito(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _busy ? null : _open,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.open_in_new_rounded, size: 18),
      label: L10nText(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: MetoColors.primaryDark,
        side: const BorderSide(color: MetoColors.border),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _MedicineProspectusPage extends StatefulWidget {
  const _MedicineProspectusPage({
    required this.medicine,
    this.previewBytes,
    this.isGuest = false,
  });

  final MedicineRecord medicine;
  final Uint8List? previewBytes;
  final bool isGuest;

  static Future<void> open(
    BuildContext context, {
    required MedicineRecord medicine,
    Uint8List? previewBytes,
    bool isGuest = false,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _MedicineProspectusPage(
          medicine: medicine,
          previewBytes: previewBytes,
          isGuest: isGuest,
        ),
      ),
    );
  }

  @override
  State<_MedicineProspectusPage> createState() => _MedicineProspectusPageState();
}

class _MedicineProspectusPageState extends State<_MedicineProspectusPage> {
  late MedicineRecord _medicine;
  bool _leafletLoading = false;

  @override
  void initState() {
    super.initState();
    _medicine = widget.medicine;
    if (_medicine.needsLeaflet) {
      _leafletLoading = true;
      unawaited(_fetchLeaflet());
    }
  }

  Future<void> _fetchLeaflet() async {
    final updated = await MedicineRepository.attachOfficialProspectus(_medicine);
    if (!mounted) return;
    setState(() {
      _medicine = updated;
      _leafletLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        backgroundColor: MetoColors.card,
        foregroundColor: MetoColors.foreground,
        elevation: 0,
        title: L10nText(
          'Prospektüs',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _MedicineIdentityHeader(
            medicine: _medicine,
            fromCache: _medicine.fromCache,
            previewBytes: widget.previewBytes,
          ),
          const SizedBox(height: 16),
          if (_leafletLoading) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: L10nText('Resmi kullanma talimatı aranıyor…'),
            ),
          ] else if (!_medicine.hasProspectusDetails &&
              !_medicine.hasOfficialProspectus) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: L10nText('Prospektüs bulunamadı'),
            ),
          ],
          _MedicineProspectusSections(medicine: _medicine),
          if (_medicine.hasOfficialProspectus || _medicine.hasUsefulName) ...[
            const SizedBox(height: 16),
            _OfficialProspectusButton(
              medicine: _medicine,
              isGuest: widget.isGuest,
            ),
          ],
        ],
      ),
    );
  }
}

class _MedicineIdentityHeader extends StatelessWidget {
  const _MedicineIdentityHeader({
    required this.medicine,
    required this.fromCache,
    this.previewBytes,
  });

  final MedicineRecord medicine;
  final bool fromCache;
  final Uint8List? previewBytes;

  @override
  Widget build(BuildContext context) {
    final imageUrl = medicine.imageUrl?.trim();
    final hasNetworkImage =
        imageUrl != null && imageUrl.startsWith('http');
    final hasPreview = previewBytes != null && previewBytes!.isNotEmpty;
    final hasImage = hasNetworkImage || hasPreview;
    final name = medicine.medicineName.trim().isNotEmpty
        ? medicine.medicineName.trim()
        : 'İsimsiz ilaç';
    final barcode = (medicine.barcode ?? '').trim();
    final ingredient = medicine.activeIngredient.trim();

    Widget image({required double height}) {
      final child = hasNetworkImage
          ? Image.network(
              imageUrl,
              height: height,
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => hasPreview
                  ? Image.memory(
                      previewBytes!,
                      height: height,
                      width: double.infinity,
                      fit: BoxFit.contain,
                    )
                  : const SizedBox.shrink(),
            )
          : Image.memory(
              previewBytes!,
              height: height,
              width: double.infinity,
              fit: BoxFit.contain,
            );
      return Material(
        color: MetoColors.selectedBg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openLabelPreview(
            context,
            url: hasNetworkImage ? imageUrl : null,
            bytes: hasPreview ? previewBytes : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MetoColors.border),
        boxShadow: [
          BoxShadow(
            color: MetoColors.primary.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            image(height: 168),
            const SizedBox(height: 14),
          ] else ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: MetoColors.selectedBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.medication_outlined,
                color: MetoColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: MetoColors.selectedBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'BİLGİ AMAÇLI ÖZET',
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: MetoColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
              color: MetoColors.foreground,
            ),
          ),
          if (ingredient.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Etken madde',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: MetoColors.mutedFg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ingredient,
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: MetoColors.primaryDark,
                height: 1.35,
              ),
            ),
          ],
          if (barcode.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Barkod: $barcode${fromCache ? ' · önbellek' : ''}',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MetoColors.mutedFg,
              ),
            ),
          ] else if (fromCache) ...[
            const SizedBox(height: 8),
            Text(
              'önbellek',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MetoColors.mutedFg,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MedicineProspectusSections extends StatelessWidget {
  const _MedicineProspectusSections({required this.medicine});

  final MedicineRecord medicine;

  static const _missing = 'Bilinmiyor';

  @override
  Widget build(BuildContext context) {
    final indications = MedicineRecord.isUnknownText(medicine.indications)
        ? ''
        : medicine.indications.trim();
    final usage = MedicineRecord.isUnknownText(medicine.usageText)
        ? ''
        : medicine.usageText.trim();
    final warnings = MedicineRecord.isUnknownText(medicine.safetyWarnings)
        ? ''
        : medicine.safetyWarnings.trim();
    final effects = medicine.sideEffects
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !MedicineRecord.isUnknownText(e))
        .toList();
    final interactions = medicine.drugInteractions
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !MedicineRecord.isUnknownText(e))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProspectusSectionCard(
          title: 'Ne işe yarar',
          icon: Icons.health_and_safety_outlined,
          accent: MetoColors.primary,
          tint: MetoColors.selectedBg,
          child: _ProspectusBodyText(
            indications.isNotEmpty ? indications : _missing,
            muted: indications.isEmpty,
          ),
        ),
        const SizedBox(height: 10),
        _ProspectusSectionCard(
          title: 'Nasıl kullanılır',
          icon: Icons.menu_book_outlined,
          accent: MetoColors.primaryDark,
          tint: const Color(0xFFE8F5EE),
          child: _ProspectusBodyText(
            usage.isNotEmpty ? usage : _missing,
            muted: usage.isEmpty,
          ),
        ),
        const SizedBox(height: 10),
        _ProspectusSectionCard(
          title: 'Yan etkiler',
          icon: Icons.list_alt_outlined,
          accent: const Color(0xFFB45309),
          tint: const Color(0xFFFFFBEB),
          child: _ProspectusBulletList(
            items: effects,
            accent: const Color(0xFFB45309),
          ),
        ),
        const SizedBox(height: 10),
        _ProspectusSectionCard(
          title: 'Etkileşime girecek ilaçlar',
          icon: Icons.medication_outlined,
          accent: MetoColors.primary,
          tint: const Color(0xFFECF8F1),
          child: _ProspectusBulletList(
            items: interactions,
            accent: MetoColors.primaryDark,
          ),
        ),
        const SizedBox(height: 10),
        _ProspectusSectionCard(
          title: 'Uyarılar',
          icon: Icons.warning_amber_rounded,
          accent: const Color(0xFF991B1B),
          tint: const Color(0xFFFEF2F2),
          child: _ProspectusBodyText(
            warnings.isNotEmpty ? warnings : _missing,
            muted: warnings.isEmpty,
            emphasized: warnings.isNotEmpty,
          ),
        ),
        const SizedBox(height: 12),
        const MedicalInfoCard(
          title: 'İlaç prospektüs / küpür analizi',
          body: kMedicineAnalysisDisclaimer,
          icon: Icons.info_outline,
        ),
      ],
    );
  }
}

class _ProspectusSectionCard extends StatelessWidget {
  const _ProspectusSectionCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.tint,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Color tint;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MetoColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MetoColors.border),
        boxShadow: [
          BoxShadow(
            color: MetoColors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: tint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: accent, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: L10nText(
                            title,
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w800,
                              color: MetoColors.foreground,
                              fontSize: 15,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProspectusBodyText extends StatelessWidget {
  const _ProspectusBodyText(
    this.text, {
    this.muted = false,
    this.emphasized = false,
  });

  final String text;
  final bool muted;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return L10nText(
      text,
      style: GoogleFonts.nunito(
        fontSize: 14,
        height: 1.5,
        fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
        color: muted ? MetoColors.mutedFg : MetoColors.foreground,
      ),
    );
  }
}

class _ProspectusBulletList extends StatelessWidget {
  const _ProspectusBulletList({
    required this.items,
    required this.accent,
  });

  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _ProspectusBodyText(
        _MedicineProspectusSections._missing,
        muted: true,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: L10nText(
                    e,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                      color: MetoColors.foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ProductResultCard extends StatelessWidget {
  const _ProductResultCard({
    required this.product,
    required this.fromCache,
    required this.ingredientsOpen,
    required this.onToggleIngredients,
    this.previewBytes,
    this.hint,
  });

  final ProductRecord product;
  final bool fromCache;
  final bool ingredientsOpen;
  final VoidCallback onToggleIngredients;
  final Uint8List? previewBytes;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final safety = product.safety;
    final ingredientsBlob = [
      product.ingredients,
      safety.ingredientsSummary,
    ].whereType<String>().join('\n');
    final additives = ENumberExplanations.forDisplay(
      additives: safety.additives,
      ingredients: ingredientsBlob,
    );
    final ingredientsKnown = product.knowsIngredientList;
    final risk = AdditiveRiskLevel.fromAdditives(
      additives,
      ingredientsKnown: ingredientsKnown,
    );
    final density = risk.densityScore;
    final category = (safety.categoryLabel ?? '').trim();
    final imageUrl = product.imageUrl?.trim();
    final hasNetworkImage =
        imageUrl != null && imageUrl.startsWith('http');
    final hasPreview = previewBytes != null && previewBytes!.isNotEmpty;
    final hasImage = hasNetworkImage || hasPreview;
    final showScore = ingredientsKnown &&
        density != null &&
        !risk.isUnknown;
    final sugarBand = NutrientBand.fromSugarPer100g(safety.sugarsPer100g);
    final saltBand = NutrientBand.fromSaltPer100g(safety.saltPer100g);
    final showSugar = safety.sugarsPer100g != null;
    final showSalt = safety.saltPer100g != null;

    Widget productImage({required double size}) {
      final child = hasNetworkImage
          ? Image.network(
              imageUrl,
              height: size,
              width: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => hasPreview
                  ? Image.memory(
                      previewBytes!,
                      height: size,
                      width: size,
                      fit: BoxFit.contain,
                    )
                  : const SizedBox.shrink(),
            )
          : Image.memory(
              previewBytes!,
              height: size,
              width: size,
              fit: BoxFit.contain,
            );
      return Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openLabelPreview(
            context,
            url: hasNetworkImage ? imageUrl : null,
            bytes: hasPreview ? previewBytes : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MetoColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage) ...[
                productImage(size: 108),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      product.productName?.trim().isNotEmpty == true
                          ? product.productName!
                          : 'İsimsiz ürün',
                      style: GoogleFonts.nunito(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                        color: MetoColors.foreground,
                      ),
                    ),
                    if (showScore) ...[
                      const SizedBox(height: 8),
                      L10nText(
                        'Katkı yoğunluğu',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: MetoColors.mutedFg,
                        ),
                      ),
                      Text(
                        '$density / 10',
                        style: GoogleFonts.nunito(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          color: AdditiveRiskCard.markerColor(risk),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Barkod: ${product.barcode}'
                      '${fromCache ? ' · önbellek' : ''}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: MetoColors.mutedFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const MedicalInfoCard(
          title: 'Ürün / içerik analizi',
          body: kProductAnalysisDisclaimer,
          icon: Icons.info_outline,
        ),
        if (hint != null && hint!.trim().isNotEmpty && !product.hasUsableIngredients) ...[
          const SizedBox(height: 10),
          L10nText(
            hint!,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MetoColors.mutedFg,
              height: 1.35,
            ),
          ),
        ],
        const SizedBox(height: 12),
        AdditiveRiskCard(level: risk),
        const SizedBox(height: 10),
        // NOVA/Nutri yoksa da kart her zaman durur (gri Bilinmiyor).
        NutriNovaCards(safety: safety, ingredients: ingredientsBlob),
        if (showSugar) ...[
          const SizedBox(height: 10),
          NutrientAmountCard(
            title: 'Şeker Miktarı',
            gramsPer100g: safety.sugarsPer100g,
            missingLabel: 'etikette belirtilmemiş',
            band: sugarBand,
            detailTemplate:
                'Etiket bilgisine göre 100 g’da yaklaşık {g} g şeker bildirilmiş. Tıbbi tavsiye değildir.',
          ),
        ],
        if (showSalt) ...[
          const SizedBox(height: 10),
          NutrientAmountCard(
            title: 'Tuz Miktarı',
            gramsPer100g: safety.saltPer100g,
            missingLabel: 'etikette belirtilmemiş',
            band: saltBand,
            detailTemplate:
                'Etiket bilgisine göre 100 g’da yaklaşık {g} g tuz bildirilmiş. Tıbbi tavsiye değildir.',
          ),
        ],
        if (safety.allergens.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ResultInfoCard(
            title: 'Etikete göre olası alerjenler',
            bg: const Color(0xFFFEF2F2),
            fg: const Color(0xFF991B1B),
            icon: Icons.warning_amber_rounded,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final a in safety.allergens)
                  Chip(
                    label: Text(a.labelTr),
                    backgroundColor: const Color(0xFFFEE2E2),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    labelStyle: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ],
        if (safety.warnings.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              color: MetoColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: MetoColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                L10nText(
                  'Etikete göre notlar',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: MetoColors.foreground,
                  ),
                ),
                const SizedBox(height: 8),
                for (final w in safety.warnings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Color(0xFFB45309),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: L10nText(
                            w,
                            style: const TextStyle(fontSize: 13, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: MetoColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: MetoColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onToggleIngredients,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: L10nText(
                          'İçindekiler',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Icon(
                        ingredientsOpen
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: MetoColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              if (ingredientsOpen)
                L10nText(
                  ProductRecord.isUsableIngredientText(product.ingredients)
                      ? product.ingredients!
                      : 'Bilinmiyor. İsterseniz etiket fotoğrafı ekleyerek tamamlayabilirsiniz.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: MetoColors.mutedFg,
                  ),
                ),
            ],
          ),
        ),
        if (additives.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ResultInfoCard(
            title: 'Bileşen listesinde yer alan katkılar',
            bg: const Color(0xFFFFFBEB),
            fg: const Color(0xFF92400E),
            icon: Icons.science_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final a in additives)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      ENumberExplanations.displayLine(a),
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF78350F),
                      ),
                    ),
                  ),
                const L10nText(
                  'Bu kodlar etiket / açık veri kaynaklarında yer alıyor; tıbbi tavsiye değildir.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: MetoColors.mutedFg,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultInfoCard extends StatelessWidget {
  const _ResultInfoCard({
    required this.title,
    required this.bg,
    required this.fg,
    required this.icon,
    required this.child,
  });

  final String title;
  final Color bg;
  final Color fg;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: fg, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: L10nText(
                  title,
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    color: fg,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ExaminingLoader extends StatefulWidget {
  const _ExaminingLoader({this.status});

  final String? status;

  @override
  State<_ExaminingLoader> createState() => _ExaminingLoaderState();
}

class _ExaminingLoaderState extends State<_ExaminingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = 0.55 + (_pulse.value * 0.45);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
          decoration: BoxDecoration(
            color: MetoColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MetoColors.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            children: [
              Opacity(
                opacity: t,
                child: Icon(
                  Icons.document_scanner_outlined,
                  size: 40,
                  color: MetoColors.primary.withValues(alpha: t),
                ),
              ),
              const SizedBox(height: 12),
              L10nText(
                (widget.status != null && widget.status!.trim().isNotEmpty)
                    ? widget.status!
                    : 'İlaç bilgisi aranıyor…',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  color: MetoColors.primary,
                  backgroundColor: MetoColors.primary.withValues(alpha: 0.15),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
