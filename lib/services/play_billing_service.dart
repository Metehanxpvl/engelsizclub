import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'google_play_availability.dart';

/// Satın alma başlatma sonucu — sahte başarı yok; yalnızca StoreKit/Play yanıtı.
enum StoreBuyResult {
  started,
  productNotFound,
  storeUnavailable,
  failed,
}

/// Google Play: `point_*` · App Store Connect: `puan_*` (eski: `point_*` / `kredi_*`)
abstract final class StoreProductIds {
  static const androidPoint1 = 'point_1';
  static const androidPoint5 = 'point_5';
  static const androidPoint10 = 'point_10';
  static const androidPoint30 = 'point_30';
  static const androidPoint50 = 'point_50';
  static const androidPoint100 = 'point_100';

  static const iosPuan1 = 'puan_1';
  static const iosPuan5 = 'puan_5';
  static const iosPuan10 = 'puan_10';
  static const iosPuan30 = 'puan_30';
  static const iosPuan50 = 'puan_50';
  static const iosPuan100 = 'puan_100';

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// iOS incelemesinde ASC’de `point_*` veya `puan_*` hangisi varsa bulunsun.
  static Set<String> get all => _isIos
      ? {
          iosPuan1,
          iosPuan5,
          iosPuan10,
          iosPuan30,
          iosPuan50,
          iosPuan100,
          androidPoint1,
          androidPoint5,
          androidPoint10,
          androidPoint30,
          androidPoint50,
          androidPoint100,
          'kredi_1',
          'kredi_5',
          'kredi_10',
          'kredi_30',
          'kredi_50',
          'kredi_100',
        }
      : {
          androidPoint1,
          androidPoint5,
          androidPoint10,
          androidPoint30,
          androidPoint50,
          androidPoint100,
        };

  static List<String> candidatesForAdet(int adet) {
    final puan = switch (adet) {
      1 => iosPuan1,
      5 => iosPuan5,
      10 => iosPuan10,
      30 => iosPuan30,
      50 => iosPuan50,
      100 => iosPuan100,
      _ => null,
    };
    final point = switch (adet) {
      1 => androidPoint1,
      5 => androidPoint5,
      10 => androidPoint10,
      30 => androidPoint30,
      50 => androidPoint50,
      100 => androidPoint100,
      _ => null,
    };
    if (_isIos) {
      return [
        if (puan != null) puan,
        if (point != null) point,
        if (adet == 1 ||
            adet == 5 ||
            adet == 10 ||
            adet == 30 ||
            adet == 50 ||
            adet == 100)
          'kredi_$adet',
      ];
    }
    return [if (point != null) point];
  }

  static String? forAdet(int adet) {
    final list = candidatesForAdet(adet);
    return list.isEmpty ? null : list.first;
  }

  static int? adetForProduct(String id) => switch (id) {
        androidPoint1 || iosPuan1 || 'kredi_1' => 1,
        androidPoint5 || iosPuan5 || 'kredi_5' => 5,
        androidPoint10 || iosPuan10 || 'kredi_10' => 10,
        'kredi_20' => 20, // eski ürün — bekleyen satın alma
        androidPoint30 || iosPuan30 || 'kredi_30' => 30,
        androidPoint50 || iosPuan50 || 'kredi_50' => 50,
        androidPoint100 || iosPuan100 || 'kredi_100' => 100,
        _ => null,
      };

  /// Mağaza kurulumu hata mesajları için.
  static String get configuredIdsHint => _isIos
      ? 'puan_1 veya point_1 … puan_100 / point_100'
      : 'point_1, point_5, point_10, point_30, point_50, point_100';
}

/// Android: Google Play Billing · iOS: App Store In-App Purchase (StoreKit 2).
class StoreBillingService {
  StoreBillingService._();
  static final StoreBillingService instance = StoreBillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _ready = false;
  final Map<String, ProductDetails> _products = {};
  Future<void> Function(PurchaseDetails purchase, int krediAdet)? _onPurchased;
  void Function(String message)? _onError;

  /// Son `queryProductDetails` ile gelmeyen kimlikler (inceleme / kurulum).
  List<String> lastNotFoundIds = const [];
  String? lastError;

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get isSupported => isAndroid || isIos;
  bool get isReady => _ready;
  bool get hasAnyProduct => _products.isNotEmpty;

  String get storeName {
    if (isIos) return 'App Store';
    if (isAndroid) return 'Google Play';
    return 'Uygulama mağazası';
  }

  String get storeShort {
    if (isIos) return 'App Store';
    if (isAndroid) return 'Play';
    return 'mağaza';
  }

  /// Kullanıcıya: ödeme mağazadan alınır, net tutar sizin hesaplarınıza yatar.
  String get payoutExplanation {
    if (isIos) {
      return 'Ödeme App Store üzerinden alınır. Apple, payınıza düşen tutarı '
          'App Store Connect’teki banka hesabınıza yatırır.';
    }
    if (isAndroid) {
      return 'Ödeme Google Play üzerinden alınır. Google, payınıza düşen tutarı '
          'Play Console’daki banka hesabınıza yatırır.';
    }
    return 'Ödeme uygulama mağazası üzerinden alınır. Mağaza, payınıza düşen tutarı hesabınıza yatırır.';
  }

  Future<void> init({
    required Future<void> Function(PurchaseDetails purchase, int krediAdet)
        onPurchased,
    void Function(String message)? onError,
  }) async {
    _onPurchased = onPurchased;
    _onError = onError;
    if (!isSupported) return;
    if (_ready && _sub != null && _products.isNotEmpty) return;
    try {
      if (isAndroid) {
        final playOk = await isGooglePlayAvailable();
        if (!playOk) {
          debugPrint('IAP: Google Play kullanılamıyor, atlanıyor.');
          lastError = 'Google Play kullanılamıyor';
          return;
        }
      }

      var available = false;
      for (var attempt = 0; attempt < 3 && !available; attempt++) {
        try {
          available = await _iap
              .isAvailable()
              .timeout(const Duration(seconds: 8), onTimeout: () => false);
        } catch (e) {
          debugPrint('IAP isAvailable: $e');
          lastError = e.toString();
        }
        if (!available && attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
        }
      }
      if (!available) {
        lastError = lastError ?? 'Mağaza şu an kullanılamıyor';
        return;
      }

      await _ensurePurchaseStream();
      await _refreshProducts();
      _ready = true;
    } catch (e) {
      debugPrint('IAP init: $e');
      lastError = e.toString();
      _ready = false;
    }
  }

  Future<void> _ensurePurchaseStream() async {
    if (_sub != null) return;
    _sub = _iap.purchaseStream.listen(
      (purchases) async {
        for (final p in purchases) {
          if (p.status == PurchaseStatus.pending) continue;
          if (p.status == PurchaseStatus.canceled) {
            if (p.pendingCompletePurchase) {
              try {
                await _iap.completePurchase(p);
              } catch (e) {
                debugPrint('IAP completePurchase: $e');
              }
            }
            continue;
          }
          if (p.status == PurchaseStatus.error) {
            final msg = p.error?.message ?? 'Ödeme hatası';
            lastError = msg;
            _onError?.call(msg);
            if (p.pendingCompletePurchase) {
              try {
                await _iap.completePurchase(p);
              } catch (e) {
                debugPrint('IAP completePurchase: $e');
              }
            }
            continue;
          }
          if (p.status == PurchaseStatus.purchased ||
              p.status == PurchaseStatus.restored) {
            final adet = StoreProductIds.adetForProduct(p.productID);
            if (adet != null) {
              await _onPurchased?.call(p, adet);
            }
            if (p.pendingCompletePurchase) {
              try {
                await _iap.completePurchase(p);
              } catch (e) {
                debugPrint('IAP completePurchase: $e');
              }
            }
          }
        }
      },
      onError: (e) {
        lastError = e.toString();
        debugPrint('IAP purchaseStream: $e');
        _onError?.call(e.toString());
      },
    );
  }

  Future<void> _refreshProducts() async {
    try {
      final resp = await _iap
          .queryProductDetails(StoreProductIds.all)
          .timeout(const Duration(seconds: 12));
      lastNotFoundIds = List<String>.from(resp.notFoundIDs);
      if (resp.error != null) {
        lastError = resp.error!.message;
        debugPrint('IAP queryProductDetails error: ${resp.error}');
      }
      if (resp.productDetails.isNotEmpty) {
        _products
          ..clear()
          ..addEntries(
            resp.productDetails.map((e) => MapEntry(e.id, e)),
          );
      } else if (_products.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        final retry = await _iap
            .queryProductDetails(StoreProductIds.all)
            .timeout(const Duration(seconds: 12));
        lastNotFoundIds = List<String>.from(retry.notFoundIDs);
        _products
          ..clear()
          ..addEntries(
            retry.productDetails.map((e) => MapEntry(e.id, e)),
          );
      }
      debugPrint(
        'IAP products: ${_products.keys.toList()} notFound: $lastNotFoundIds',
      );
    } catch (e) {
      debugPrint('IAP queryProductDetails: $e');
      lastError = e.toString();
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _ready = false;
  }

  ProductDetails? _productForAdet(int adet) {
    for (final id in StoreProductIds.candidatesForAdet(adet)) {
      final found = _products[id];
      if (found != null) return found;
    }
    return null;
  }

  bool productAvailableForAdet(int adet) => _productForAdet(adet) != null;

  Future<StoreBuyResult> buyKrediPaket(int adet) async {
    lastError = null;
    if (!isSupported) {
      lastError = 'Bu platformda mağaza ödemesi yok';
      return StoreBuyResult.storeUnavailable;
    }
    if (isAndroid) {
      final playOk = await isGooglePlayAvailable();
      if (!playOk) {
        lastError = 'Google Play kullanılamıyor';
        return StoreBuyResult.storeUnavailable;
      }
    }
    try {
      var available = false;
      try {
        available = await _iap
            .isAvailable()
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
      } catch (e) {
        lastError = e.toString();
      }
      if (!available) {
        lastError = lastError ?? 'Mağaza şu an kullanılamıyor';
        return StoreBuyResult.storeUnavailable;
      }

      await _ensurePurchaseStream();

      final candidates = StoreProductIds.candidatesForAdet(adet);
      if (candidates.isEmpty) {
        lastError = 'Bu paket için ürün kimliği yok';
        return StoreBuyResult.productNotFound;
      }

      var product = _productForAdet(adet);
      if (product == null) {
        final resp = await _iap
            .queryProductDetails(candidates.toSet())
            .timeout(const Duration(seconds: 12));
        lastNotFoundIds = List<String>.from(resp.notFoundIDs);
        for (final p in resp.productDetails) {
          _products[p.id] = p;
        }
        product = _productForAdet(adet) ??
            (resp.productDetails.isEmpty ? null : resp.productDetails.first);
      }
      if (product == null) {
        lastError =
            'Ürün mağazada yok (${candidates.join(', ')}). App Store Connect’te Consumable oluşturup bu sürümle incelemeye ekleyin.';
        return StoreBuyResult.productNotFound;
      }

      final param = PurchaseParam(productDetails: product);
      final started = await _iap.buyConsumable(
        purchaseParam: param,
        autoConsume: true,
      );
      if (!started) {
        lastError = 'Satın alma penceresi açılamadı';
        return StoreBuyResult.failed;
      }
      return StoreBuyResult.started;
    } catch (e) {
      debugPrint('IAP buyKrediPaket: $e');
      lastError = e.toString();
      return StoreBuyResult.failed;
    }
  }

  /// Play / App Store’dan gelen güncel fiyat metni (yoksa null).
  String? storePriceForAdet(int adet) {
    final price = _productForAdet(adet)?.price;
    if (price != null && price.isNotEmpty) return price;
    return null;
  }
}

/// Eski ad — geriye uyumluluk.
typedef PlayBillingService = StoreBillingService;
typedef PlayProductIds = StoreProductIds;
