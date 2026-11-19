import 'hak_dosyasi.dart';

enum KuralSonuc { saglaniyor, saglanmiyor, bilinmiyor }

enum HakUygunluk { buyukIhtimalle, sartlaraBagli, uygunDegil }

/// Profil cevaplarından türetilmiş alanları ekler (kisi_basi_gelir).
Map<String, dynamic> cevaplarWithDerived(Map<String, dynamic> cevaplar) {
  final out = Map<String, dynamic>.from(cevaplar);
  final gelir = _asNum(out['hane_gelir']);
  final kisi = _asNum(out['hane_kisi']);
  if (gelir != null && kisi != null && kisi != 0) {
    out['kisi_basi_gelir'] = gelir / kisi;
  }
  return out;
}

/// Tek kuralı değerlendir. Alan yoksa [KuralSonuc.bilinmiyor].
KuralSonuc degerlendir(HakKural k, Map<String, dynamic> cevaplar) {
  final alan = k.alan.trim();
  if (alan.isEmpty) return KuralSonuc.bilinmiyor;

  final map = cevaplarWithDerived(cevaplar);
  if (!map.containsKey(alan) || map[alan] == null) {
    return KuralSonuc.bilinmiyor;
  }

  final sol = map[alan];
  final sag = k.deger;
  final op = k.op.trim();

  try {
    final ok = switch (op) {
      'in' => _evalIn(sol, sag),
      '==' => _eq(sol, sag),
      '!=' => !_eq(sol, sag),
      '>=' => _cmp(sol, sag) >= 0,
      '<=' => _cmp(sol, sag) <= 0,
      '>' => _cmp(sol, sag) > 0,
      '<' => _cmp(sol, sag) < 0,
      _ => null,
    };
    if (ok == null) return KuralSonuc.bilinmiyor;
    return ok ? KuralSonuc.saglaniyor : KuralSonuc.saglanmiyor;
  } catch (_) {
    return KuralSonuc.bilinmiyor;
  }
}

/// Kurallı kriterlere göre uygunluk. Kurallı kriter yoksa null.
HakUygunluk? uygunlukKural(HakDosyasi d, Map<String, dynamic> cevaplar) {
  final kurallar = [
    for (final k in d.kimler)
      if (k.kural != null && k.kural!.alan.trim().isNotEmpty) k.kural!,
  ];
  if (kurallar.isEmpty) return null;

  var anyFail = false;
  var anyUnknown = false;
  var allOk = true;

  for (final k in kurallar) {
    final s = degerlendir(k, cevaplar);
    switch (s) {
      case KuralSonuc.saglanmiyor:
        anyFail = true;
        allOk = false;
      case KuralSonuc.bilinmiyor:
        anyUnknown = true;
        allOk = false;
      case KuralSonuc.saglaniyor:
        break;
    }
  }

  if (anyFail) return HakUygunluk.uygunDegil;
  if (allOk) return HakUygunluk.buyukIhtimalle;
  if (anyUnknown) return HakUygunluk.sartlaraBagli;
  return HakUygunluk.sartlaraBagli;
}

bool _evalIn(dynamic sol, dynamic sag) {
  List list;
  if (sag is List) {
    list = sag;
  } else if (sag is String) {
    list = sag.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  } else {
    list = [sag];
  }
  for (final e in list) {
    if (_eq(sol, e)) return true;
  }
  return false;
}

bool _eq(dynamic a, dynamic b) {
  if (a is bool || b is bool) {
    return _asBool(a) == _asBool(b);
  }
  final na = _asNum(a);
  final nb = _asNum(b);
  if (na != null && nb != null) return na == nb;
  return a?.toString() == b?.toString();
}

int _cmp(dynamic a, dynamic b) {
  final na = _asNum(a);
  final nb = _asNum(b);
  if (na != null && nb != null) return na.compareTo(nb);
  return a.toString().compareTo(b.toString());
}

num? _asNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is bool) return v ? 1 : 0;
  return num.tryParse(v.toString().trim().replaceAll(',', '.'));
}

bool _asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().trim().toLowerCase() ?? '';
  return s == 'true' || s == '1' || s == 'evet';
}
