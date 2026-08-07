import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Play Console + App Store Connect ürün kimlikleri (birebir aynı olmalı).
abstract final class StoreProductIds {
  static const kredi1 = 'kredi_1';
  static const kredi5 = 'kredi_5';
  static const kredi10 = 'kredi_10';
  static const kredi20 = 'kredi_20';

  static const all = <String>{kredi1, kredi5, kredi10, kredi20};

  static String? forAdet(int adet) => switch (adet) {
        1 => kredi1,
        5 => kredi5,
        10 => kredi10,
        20 => kredi20,
        _ => null,
      };

  static int? adetForProduct(String id) => switch (id) {
        kredi1 => 1,
        kredi5 => 5,
        kredi10 => 10,
        kredi20 => 20,
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
    final available = await _iap.isAvailable();
    if (!available) {
      onError?.call('$storeName faturalandırma kullanılamıyor.');
      return;
    }

    await _sub?.cancel();
    _sub = _iap.purchaseStream.listen(
      (purchases) async {
        for (final p in purchases) {
          if (p.status == PurchaseStatus.pending) continue;
          if (p.status == PurchaseStatus.error) {
            onError?.call(p.error?.message ?? 'Ödeme hatası');
            if (p.pendingCompletePurchase) {
              await _iap.completePurchase(p);
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
              await _iap.completePurchase(p);
            }
          }
        }
      },
      onError: (e) => onError?.call('$e'),
    );

    final resp = await _iap.queryProductDetails(StoreProductIds.all);
    _products
      ..clear()
      ..addEntries(
        resp.productDetails.map((e) => MapEntry(e.id, e)),
      );
    _ready = true;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<bool> buyKrediPaket(int adet) async {
    if (!isSupported) return false;
    final id = StoreProductIds.forAdet(adet);
    if (id == null) return false;
    var product = _products[id];
    if (product == null) {
      final resp = await _iap.queryProductDetails({id});
      if (resp.productDetails.isEmpty) return false;
      product = resp.productDetails.first;
      _products[id] = product;
    }
    // Tüketilebilir ürün — puan yükleme (consumable).
    final param = PurchaseParam(productDetails: product);
    return _iap.buyConsumable(
      purchaseParam: param,
      autoConsume: true,
    );
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
