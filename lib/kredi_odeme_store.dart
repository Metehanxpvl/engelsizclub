import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

class KrediOdemeBildirimi {
  const KrediOdemeBildirimi({
    required this.id,
    required this.paketAdet,
    required this.paketFiyat,
    required this.gonderenAd,
    required this.notText,
    required this.referansKodu,
    required this.status,
    required this.credited,
    required this.createdAt,
  });

  final String id;
  final int paketAdet;
  final String paketFiyat;
  final String gonderenAd;
  final String notText;
  final String referansKodu;
  final String status; // beklemede | onaylandi | reddedildi
  final bool credited;
  final DateTime createdAt;

  bool get isBeklemede => status == 'beklemede';
  bool get isOnaylandi => status == 'onaylandi';
  bool get isReddedildi => status == 'reddedildi';

  String get statusLabel => switch (status) {
        'onaylandi' => 'Onaylandı',
        'reddedildi' => 'Reddedildi',
        _ => 'İnceleniyor',
      };

  factory KrediOdemeBildirimi.fromJson(Map<String, dynamic> json) =>
      KrediOdemeBildirimi(
        id: json['id']?.toString() ?? '',
        paketAdet: (json['paket_adet'] as num?)?.toInt() ?? 0,
        paketFiyat: json['paket_fiyat']?.toString() ?? '',
        gonderenAd: json['gonderen_ad']?.toString() ?? '',
        notText: json['not_text']?.toString() ?? '',
        referansKodu: json['referans_kodu']?.toString() ?? '',
        status: json['status']?.toString() ?? 'beklemede',
        credited: json['credited'] == true,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}

String generateKrediReferans() {
  final n = Random().nextInt(900000) + 100000;
  return 'EC$n';
}

Future<KrediOdemeBildirimi> submitKrediOdemeBildirimi({
  required String email,
  required int paketAdet,
  required String paketFiyat,
  required String gonderenAd,
  String notText = '',
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) {
    throw StateError('Ödeme bildirimi için giriş yapmalısınız.');
  }
  final ad = gonderenAd.trim();
  if (ad.isEmpty) {
    throw StateError('Gönderen adını yazın.');
  }

  final ref = generateKrediReferans();
  final payload = <String, dynamic>{
    'owner_id': user.id,
    'owner_email': email.trim().toLowerCase(),
    'paket_adet': paketAdet,
    'paket_fiyat': paketFiyat,
    'gonderen_ad': ad,
    'not_text': notText.trim(),
    'referans_kodu': ref,
    'status': 'beklemede',
    'credited': false,
  };

  final row = await client
      .from('kredi_odemeleri')
      .insert(payload)
      .select()
      .single();
  return KrediOdemeBildirimi.fromJson(Map<String, dynamic>.from(row));
}

Future<List<KrediOdemeBildirimi>> loadKrediOdemeleri() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return const [];
  try {
    final rows = await client
        .from('kredi_odemeleri')
        .select()
        .eq('owner_id', user.id)
        .order('created_at', ascending: false)
        .limit(20);
    return (rows as List)
        .whereType<Map>()
        .map((e) => KrediOdemeBildirimi.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  } catch (_) {
    return const [];
  }
}

/// Onaylanmış ama henüz hesaba işlenmemiş ödemelerin kredi toplamını döner
/// ve credited=true işaretler.
Future<int> claimApprovedKrediOdemeleri() async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return 0;

  try {
    final rows = await client
        .from('kredi_odemeleri')
        .select()
        .eq('owner_id', user.id)
        .eq('status', 'onaylandi')
        .eq('credited', false);

    final list = (rows as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (list.isEmpty) return 0;

    var total = 0;
    for (final row in list) {
      total += (row['paket_adet'] as num?)?.toInt() ?? 0;
      final id = row['id']?.toString();
      if (id == null || id.isEmpty) continue;
      // credited güncellemesi RLS ile engelli olabilir — RPC yoksa
      // kullanıcı update yapamaz. Service role gerekir.
      // Bu yüzden bir UPDATE policy ekleyeceğiz: sadece credited false→true
      // ve status zaten onaylandi iken.
      try {
        await client
            .from('kredi_odemeleri')
            .update({'credited': true})
            .eq('id', id)
            .eq('owner_id', user.id)
            .eq('status', 'onaylandi')
            .eq('credited', false);
      } catch (_) {}
    }
    return total;
  } catch (_) {
    return 0;
  }
}
