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
import '../services/image_optimize_service.dart';
import '../services/label_ocr.dart';
import '../services/product_disclaimer.dart';
import '../utils/web_camera_frame.dart';
import '../utils/web_session_tab.dart';
import '../widgets/additive_risk_bar.dart';
import '../widgets/medical_info_card.dart';
import '../widgets/nutri_nova_cards.dart';

enum _TaramaMode { product, medicine }

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
  static const _scanFormats = <BarcodeFormat>[
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
    BarcodeFormat.qrCode,
    BarcodeFormat.code128,
    BarcodeFormat.code39,
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

  bool get _isMedicine => _mode == _TaramaMode.medicine;

  bool get _hasFoundResult => _isMedicine
      ? _medicine?.isFound == true
      : _result?.product?.isFound == true;

  MobileScannerController _newController() => MobileScannerController(
        facing: CameraFacing.back,
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: 200,
        autoStart: false,
        formats: _scanFormats,
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _camera = _newController();
    _listenBarcodes();
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
      _webPoller.start(_acceptBarcode);
    });
  }

  Future<void> _stopCamera() async {
    _webPoller.stop();
    try {
      await _camera?.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _webPoller.stop();
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
    if (_loading) return;
    setState(() {
      _handling = true;
      _loading = true;
      _error = null;
      _pendingBarcode = code.isEmpty ? null : code;
      _status = hasPhoto
          ? 'Etiket inceleniyor…'
          : 'Etiket bilgisi tamamlanıyor…';
      _ingredientsOpen = true;
      if (hasPhoto) _labelPreview = labelBytes;
    });
    _webPoller.stop();
    try {
      await _camera?.stop();
    } catch (_) {}

    final result = await ProductRepository.lookup(
      code,
      labelImageBytes: labelBytes,
      ocrText: ocrText?.trim(),
      productHint: productHint,
      brandHint: brandHint,
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
  }

  Future<void> _lookupMedicine(
    String raw, {
    Uint8List? labelBytes,
    String? ocrText,
  }) async {
    final code = raw.trim();
    final hasPhoto = labelBytes != null && labelBytes.isNotEmpty;
    if (!hasPhoto && code.isEmpty) {
      _handling = false;
      return;
    }
    if (_loading) return;
    setState(() {
      _handling = true;
      _loading = true;
      _error = null;
      _pendingBarcode = code.isEmpty ? null : code;
      _status = hasPhoto
          ? 'Küpür / prospektüs inceleniyor…'
          : 'İlaç önbelleği kontrol ediliyor…';
      if (hasPhoto) _labelPreview = labelBytes;
    });
    _webPoller.stop();
    try {
      await _camera?.stop();
    } catch (_) {}

    final result = await MedicineRepository.lookup(
      barcode: code,
      imageBytes: labelBytes,
      ocrText: ocrText?.trim(),
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
    if (!result.isFound && widget.isTabActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isTabActive && _medicine?.isFound != true) {
          unawaited(_startCamera());
        }
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final raw = (b.rawValue ?? b.displayValue)?.trim();
      if (raw != null && raw.isNotEmpty) {
        _acceptBarcode(raw);
        return;
      }
    }
  }

  void _acceptBarcode(String raw) {
    final code = raw.trim();
    if (code.isEmpty || _handling || _loading || _hasFoundResult) {
      return;
    }
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
    _handling = true;
    if (_isMedicine) {
      unawaited(_lookupMedicine(code));
    } else {
      unawaited(_lookup(code));
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
    final code = _pendingBarcode ?? '';
    if (_isMedicine) {
      await _lookupMedicine(code, labelBytes: bytes);
    } else {
      await _lookup(code, labelBytes: bytes);
    }
  }

  Future<void> _pickLabel({required bool camera}) async {
    if (_handling) return;
    persistWebSessionTab('tarama');
    if (kIsWeb && camera) {
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

      final fromImage = await _barcodeFromImage(file);
      var ocr = '';
      if (!kIsWeb && file.path.isNotEmpty) {
        ocr = await LabelOcr.readFromPath(file.path);
      }
      final rawBytes = await file.readAsBytes();
      OptimizedImage? optimized;
      try {
        optimized = await ImageOptimizeService.forLabelScan(rawBytes);
      } catch (_) {}
      final bytes = optimized?.bytes ?? rawBytes;

      final code = fromImage ?? _pendingBarcode ?? '';
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
    MobileScannerController? probe;
    try {
      probe = MobileScannerController();
      final capture = await probe.analyzeImage(path);
      final raw = capture?.barcodes
          .map((b) => b.rawValue?.trim() ?? '')
          .firstWhere((s) => s.isNotEmpty, orElse: () => '');
      return (raw == null || raw.isEmpty) ? null : raw;
    } catch (_) {
      return null;
    } finally {
      await probe?.dispose();
    }
  }

  Future<void> _resetScan() async {
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
      _labelPreview = null;
      _nameHits = const [];
      _medicineHits = const [];
      _nameSearching = false;
      _nameSearchError = null;
    });
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
    await _resetScan();
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
    if (rec == null || !rec.isFound) return;
    FocusManager.instance.primaryFocus?.unfocus();
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
            if (_nameSearching ||
                _nameHits.isNotEmpty ||
                _medicineHits.isNotEmpty ||
                (_nameSearchError != null &&
                    _nameSearchError!.trim().isNotEmpty)) ...[
              const SizedBox(height: 8),
              _buildNameSearchResults(),
            ],
            const SizedBox(height: 12),
            _buildScannerCard(),
            const SizedBox(height: 12),
            ..._photoActionButtons(prominent: true),
          ],
          if (_loading) ...[
            const SizedBox(height: 16),
            _ExaminingLoader(status: _status),
          ],
          if (!_loading && _error != null && !foundAny) ...[
            const SizedBox(height: 16),
            _NotFoundCard(
              message: _error!,
              askPhoto: _isMedicine
                  ? _medicine?.needsKey != true
                  : _result?.needsKey != true,
              photoLabel: _isMedicine
                  ? 'Küpür / prospektüs fotoğrafı'
                  : 'Daha net için etiket fotoğrafı',
              onRetry: _resetScan,
              onPhoto: kIsWeb ? _captureFromLiveCamera : _showPhotoSheet,
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
            ..._photoActionButtons(prominent: false),
            const SizedBox(height: 8),
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
            ),
            const SizedBox(height: 16),
            ..._photoActionButtons(prominent: false),
            const SizedBox(height: 8),
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

  List<Widget> _photoActionButtons({required bool prominent}) {
    final photo = prominent
        ? FilledButton.icon(
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
          )
        : OutlinedButton.icon(
            onPressed: _loading
                ? null
                : (kIsWeb
                    ? _captureFromLiveCamera
                    : () => unawaited(_pickLabel(camera: true))),
            icon: const Icon(Icons.photo_camera_outlined),
            label: L10nText(
              _isMedicine
                  ? 'Daha net için küpür fotoğrafı'
                  : 'Daha net için etiket fotoğrafı',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: MetoColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          );
    final gallery = TextButton.icon(
      onPressed: _loading ? null : () => unawaited(_pickLabel(camera: false)),
      icon: const Icon(Icons.photo_library_outlined, size: 18),
      label: const L10nText('Galeriden seç'),
    );
    if (prominent) {
      return [
        photo,
        if (kIsWeb) ...[
          const SizedBox(height: 4),
          gallery,
        ],
      ];
    }
    return [
      photo,
      const SizedBox(height: 4),
      gallery,
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: MetoColors.border),
        ),
        child: Stack(
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
                                      ? (_isMedicine
                                          ? 'Kamera açılıyor… Küpürü çerçeveye hizalayın veya fotoğraf çekin.'
                                          : 'Kamera açılıyor… Barkodu çerçeveye hizalayın.')
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
            IgnorePointer(
              child: Center(
                child: Container(
                  width: 220,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white70, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            if (showHint)
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: IgnorePointer(
                  child: L10nText(
                    _isMedicine
                        ? 'Küpürü çerçeveye hizalayın veya fotoğraf çekin'
                        : 'Barkodu çerçeveye hizalayın',
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
          ],
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
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w800,
              fontSize: 15,
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
    this.askPhoto = false,
    this.onPhoto,
    this.photoLabel = 'Daha net için etiket fotoğrafı',
  });

  final String message;
  final VoidCallback onRetry;
  final bool askPhoto;
  final VoidCallback? onPhoto;
  final String photoLabel;

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
          if (askPhoto && onPhoto != null)
            TextButton.icon(
              onPressed: onPhoto,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: L10nText(photoLabel),
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
    final usage = medicine.usageText.trim();
    final warnings = medicine.safetyWarnings.trim();
    final effects = medicine.sideEffects
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final interactions = medicine.drugInteractions
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

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
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFFF8FAFC),
          child: child,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage) ...[
                image(height: 180),
                const SizedBox(height: 12),
              ],
              Text(
                name,
                style: GoogleFonts.nunito(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                  color: MetoColors.foreground,
                ),
              ),
              if (ingredient.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Etken madde: $ingredient',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MetoColors.primaryDark,
                    height: 1.35,
                  ),
                ),
              ],
              if (barcode.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Barkod: $barcode${fromCache ? ' · önbellek' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: MetoColors.mutedFg,
                  ),
                ),
              ] else if (fromCache) ...[
                const SizedBox(height: 4),
                const Text(
                  'önbellek',
                  style: TextStyle(fontSize: 11, color: MetoColors.mutedFg),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        const MedicalInfoCard(
          title: 'İlaç prospektüs / küpür analizi',
          body: kMedicineAnalysisDisclaimer,
          icon: Icons.info_outline,
        ),
        if (usage.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ResultInfoCard(
            title: 'Kullanım özeti',
            bg: const Color(0xFFF0FDF4),
            fg: MetoColors.primaryDark,
            icon: Icons.menu_book_outlined,
            child: L10nText(
              usage,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: MetoColors.foreground,
              ),
            ),
          ),
        ],
        if (effects.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ResultInfoCard(
            title: 'Yan etkiler',
            bg: const Color(0xFFFFFBEB),
            fg: const Color(0xFF92400E),
            icon: Icons.list_alt_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in effects)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            )),
                        Expanded(
                          child: L10nText(
                            e,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (interactions.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ResultInfoCard(
            title: 'İlaç etkileşimleri',
            bg: const Color(0xFFEFF6FF),
            fg: const Color(0xFF1E40AF),
            icon: Icons.medication_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in interactions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E40AF),
                            )),
                        Expanded(
                          child: L10nText(
                            e,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          _ResultInfoCard(
            title: 'Kritik uyarılar',
            bg: const Color(0xFFFEF2F2),
            fg: const Color(0xFF991B1B),
            icon: Icons.warning_amber_rounded,
            child: L10nText(
              warnings,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    final ingredientsKnown = product.hasUsableIngredients ||
        ProductRecord.isUsableIngredientText(safety.ingredientsSummary);
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
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: const Color(0xFFF8FAFC),
          child: child,
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
        NutriNovaCards(safety: safety),
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
                  (product.ingredients == null ||
                          product.ingredients!.trim().isEmpty)
                      ? 'İçindekiler henüz net değil. Aşağıdan isteğe bağlı etiket fotoğrafı ekleyebilirsiniz.'
                      : product.ingredients!,
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
                'Etiket bilgisi tamamlanıyor',
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
              if (widget.status != null && widget.status!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                L10nText(
                  widget.status!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MetoColors.mutedFg,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
