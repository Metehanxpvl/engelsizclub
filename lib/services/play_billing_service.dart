import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'google_play_availability.dart';

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

/// Android: Google Play Billing · iOS: App Store In-App Purchase.
class StoreBillingService {
  StoreBillingService._();
  static final StoreBillingService instance = StoreBillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _ready = false;
  final Map<String, ProductDetails> _products = {};

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get isSupported => isAndroid || isIos;
  bool get isReady => _ready;

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
    if (!isSupported) return;
    if (_ready && _sub != null) return;
    try {
      if (isAndroid) {
        final playOk = await isGooglePlayAvailable();
        if (!playOk) {
          debugPrint('IAP: Google Play kullanılamıyor, atlanıyor.');
          return;
        }
      }

      var available = false;
      try {
        available = await _iap
            .isAvailable()
            .timeout(const Duration(seconds: 5), onTimeout: () => false);
      } catch (e) {
        debugPrint('IAP isAvailable: $e');
        return;
      }
      if (!available) return;

      await _sub?.cancel();
      _sub = _iap.purchaseStream.listen(
        (purchases) async {
          for (final p in purchases) {
            if (p.status == PurchaseStatus.pending) continue;
            if (p.status == PurchaseStatus.error) {
              onError?.call(p.error?.message ?? 'Ödeme hatası');
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
                await onPurchased(p, adet);
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
        onError: (e) => debugPrint('IAP purchaseStream: $e'),
      );

      try {
        final resp = await _iap.queryProductDetails(StoreProductIds.all);
        _products
          ..clear()
          ..addEntries(
            resp.productDetails.map((e) => MapEntry(e.id, e)),
          );
      } catch (e) {
        debugPrint('IAP queryProductDetails: $e');
      }
      _ready = true;
    } catch (e) {
      debugPrint('IAP init: $e');
      _ready = false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<bool> buyKrediPaket(int adet) async {
    if (!isSupported) return false;
    if (isAndroid) {
      final playOk = await isGooglePlayAvailable();
      if (!playOk) return false;
    }
    try {
      final candidates = StoreProductIds.candidatesForAdet(adet);
      if (candidates.isEmpty) return false;
      ProductDetails? product;
      for (final id in candidates) {
        product = _products[id];
        if (product != null) break;
      }
      if (product == null) {
        final resp = await _iap.queryProductDetails(candidates.toSet());
        if (resp.productDetails.isEmpty) return false;
        for (final p in resp.productDetails) {
          _products[p.id] = p;
        }
        for (final id in candidates) {
          product = _products[id];
          if (product != null) break;
        }
        product ??= resp.productDetails.first;
      }
      final param = PurchaseParam(productDetails: product);
      return _iap.buyConsumable(
        purchaseParam: param,
        autoConsume: true,
      );
    } catch (e) {
      debugPrint('IAP buyKrediPaket: $e');
      return false;
    }
  }

  /// Play / App Store’dan gelen güncel fiyat metni (yoksa null).
  String? storePriceForAdet(int adet) {
    for (final id in StoreProductIds.candidatesForAdet(adet)) {
      final price = _products[id]?.price;
      if (price != null && price.isNotEmpty) return price;
    }
    return null;
  }
}

/// Eski ad — geriye uyumluluk.
typedef PlayBillingService = StoreBillingService;
typedef PlayProductIds = StoreProductIds;
