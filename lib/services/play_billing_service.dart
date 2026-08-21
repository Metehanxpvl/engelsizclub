import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'google_play_availability.dart';

/// Play Console + App Store Connect ürün kimlikleri (birebir aynı olmalı).
abstract final class StoreProductIds {
  static const kredi1 = 'kredi_1';
  static const kredi5 = 'kredi_5';
  static const kredi10 = 'kredi_10';
  static const kredi30 = 'kredi_30';
  static const kredi50 = 'kredi_50';
  static const kredi100 = 'kredi_100';

  static const all = <String>{
    kredi1,
    kredi5,
    kredi10,
    kredi30,
    kredi50,
    kredi100,
  };

  static String? forAdet(int adet) => switch (adet) {
        1 => kredi1,
        5 => kredi5,
        10 => kredi10,
        30 => kredi30,
        50 => kredi50,
        100 => kredi100,
        _ => null,
      };

  static int? adetForProduct(String id) => switch (id) {
        kredi1 => 1,
        kredi5 => 5,
        kredi10 => 10,
        'kredi_20' => 20, // eski ürün (liste dışı) — bekleyen satın alma
        kredi30 => 30,
        kredi50 => 50,
        kredi100 => 100,
        _ => null,
      };
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
    return 'Ödeme yalnızca Android (Google Play) veya iOS (App Store) '
        'uygulamasında yapılır. Mağaza, payınıza düşen tutarı hesabınıza yatırır.';
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
      final id = StoreProductIds.forAdet(adet);
      if (id == null) return false;
      var product = _products[id];
      if (product == null) {
        final resp = await _iap.queryProductDetails({id});
        if (resp.productDetails.isEmpty) return false;
        product = resp.productDetails.first;
        _products[id] = product;
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
    final id = StoreProductIds.forAdet(adet);
    if (id == null) return null;
    return _products[id]?.price;
  }
}

/// Eski ad — geriye uyumluluk.
typedef PlayBillingService = StoreBillingService;
typedef PlayProductIds = StoreProductIds;
