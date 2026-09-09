import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/destek_sorgu_data.dart';
import '../utils/async_timeout.dart';

class DestekSorguKayit {
  const DestekSorguKayit({
    required this.productId,
    this.quotePrice,
    required this.sutPrice,
    this.deliveryDate,
    required this.reportEndDate,
  });

  final String productId;
  final double? quotePrice;
  final double sutPrice;
  final DateTime? deliveryDate;
  final DateTime reportEndDate;
}

SupabaseClient get _db => Supabase.instance.client;

Future<List<DestekSorguUrun>> loadDestekSorguUrunler() async {
  try {
    final rows = await withNetworkTimeout(
      _db
          .from('destek_sorgu_urunler')
          .select()
          .eq('is_active', true)
          .order('category_sort')
          .order('sort_order'),
    );
    if (rows is! List || rows.isEmpty) return kDestekSorguFallback;
    final items = rows
        .whereType<Map>()
        .map((r) => DestekSorguUrun.fromJson(Map<String, dynamic>.from(r)))
        .where((e) => e.id.isNotEmpty)
        .toList();
    final cpapOk = items.any((e) => e.id == 'cpap' && e.sutPrice == 3265.92);
    final bezOk = items.any((e) => e.id == 'bez-yetiskin' && e.sutPrice == 6.31);
    if (!cpapOk || !bezOk) return kDestekSorguFallback;
    return items;
  } catch (_) {
    return kDestekSorguFallback;
  }
}

Future<DestekSorguKayit?> loadDestekSorguKayit(String productId) async {
  final uid = _db.auth.currentUser?.id;
  if (uid == null || productId.isEmpty) return null;
  try {
    final row = await withNetworkTimeout(
      _db
          .from('destek_sorgu_kayitlar')
          .select()
          .eq('user_id', uid)
          .eq('product_id', productId)
          .maybeSingle(),
    );
    if (row is! Map) return null;
    final end = DateTime.tryParse(row['report_end_date']?.toString() ?? '');
    if (end == null) return null;
    return DestekSorguKayit(
      productId: productId,
      quotePrice: (row['quote_price'] as num?)?.toDouble(),
      sutPrice: (row['sut_price'] as num?)?.toDouble() ?? 0,
      deliveryDate: DateTime.tryParse(row['delivery_date']?.toString() ?? ''),
      reportEndDate: end,
    );
  } catch (_) {
    return null;
  }
}

Future<void> saveDestekSorguKayit(DestekSorguKayit kayit) async {
  final uid = _db.auth.currentUser?.id;
  if (uid == null) {
    throw StateError('Kaydı buluta yazmak için giriş yapın.');
  }
  await withNetworkTimeout(
    _db.from('destek_sorgu_kayitlar').upsert({
      'user_id': uid,
      'product_id': kayit.productId,
      'quote_price': kayit.quotePrice,
      'sut_price': kayit.sutPrice,
      'delivery_date': kayit.deliveryDate?.toIso8601String().split('T').first,
      'report_end_date': kayit.reportEndDate.toIso8601String().split('T').first,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,product_id'),
  );
}
