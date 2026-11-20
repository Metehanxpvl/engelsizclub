import 'package:supabase_flutter/supabase_flutter.dart';

import '../uzman_kosesi_profiles_store.dart';
import 'kurum_is_ilan_models.dart';

/// OCR / görsel okuma sonucundan kurum iş ilanı formu taslağı.
class KurumIlanTaslak {
  const KurumIlanTaslak({
    this.kurumAdi = '',
    this.telefon = '',
    this.il = '',
    this.ilce = '',
    this.arananMeslek = '',
    this.calismaSekli = const [],
    this.aciklama = '',
    this.photoUrl = '',
    this.okunamayanAlanlar = const [],
  });

  final String kurumAdi;
  final String telefon;
  final String il;
  final String ilce;
  final String arananMeslek;
  final List<String> calismaSekli;
  final String aciklama;
  final String photoUrl;
  final List<String> okunamayanAlanlar;
}

String _str(dynamic v) => (v?.toString() ?? '').trim();

List<String> _stringList(dynamic raw) {
  if (raw is List) {
    return [
      for (final e in raw)
        if (_str(e).isNotEmpty) _str(e),
    ];
  }
  final s = _str(raw);
  if (s.isEmpty) return const [];
  return [s];
}

/// [baslik] meslek listesinde (büyük/küçük harf duyarsız) varsa onu döner.
String matchArananMeslek(String baslik) {
  final needle = baslik.trim();
  if (needle.isEmpty) return '';
  final norm = uzmanKosesNormYer(needle);
  for (final m in uzmanKosesMeslekSecenekleri()) {
    if (uzmanKosesNormYer(m) == norm) return m;
  }
  // Basit toLowerCase yedek (Türkçe karakter farkı olmadan)
  final lower = needle.toLowerCase();
  for (final m in uzmanKosesMeslekSecenekleri()) {
    if (m.toLowerCase() == lower) return m;
  }
  return '';
}

/// Çalışma tipi seçeneklerinden eşleşeni bulur; yoksa boş.
List<String> matchCalismaSekli(String calismaTipi) {
  final needle = calismaTipi.trim();
  if (needle.isEmpty) return const [];
  final norm = uzmanKosesNormYer(needle);
  for (final o in kKurumIsCalismaSekliSecenekleri) {
    if (uzmanKosesNormYer(o) == norm || o.toLowerCase() == needle.toLowerCase()) {
      return [o];
    }
  }
  return const [];
}

/// Açıklama gövdesi: Pozisyon satırı + OCR metni + isteğe bağlı e-posta.
String buildAciklamaFromOcr({
  required String baslik,
  required String aciklama,
  required String eposta,
}) {
  final parts = <String>[];
  final b = baslik.trim();
  if (b.isNotEmpty) parts.add('Pozisyon: $b');
  final a = aciklama.trim();
  if (a.isNotEmpty) parts.add(a);
  final e = eposta.trim();
  if (e.isNotEmpty) parts.add('E-posta: $e');
  return parts.join('\n\n');
}

/// Edge function `fields` + yüklenen görsel URL → form taslağı.
KurumIlanTaslak kurumIlanTaslakFromOcrFields({
  required Map<String, dynamic> fields,
  required String photoUrl,
}) {
  final baslik = _str(fields['baslik']);
  final eposta = _str(fields['iletisim_eposta']);
  return KurumIlanTaslak(
    kurumAdi: _str(fields['kurum_adi']),
    telefon: _str(fields['iletisim_telefon']),
    il: _str(fields['il']),
    ilce: _str(fields['ilce']),
    arananMeslek: matchArananMeslek(baslik),
    calismaSekli: matchCalismaSekli(_str(fields['calisma_tipi'])),
    aciklama: buildAciklamaFromOcr(
      baslik: baslik,
      aciklama: _str(fields['aciklama']),
      eposta: eposta,
    ),
    photoUrl: photoUrl.trim(),
    okunamayanAlanlar: _stringList(fields['okunamayan_alanlar']),
  );
}

String? _errorFromPayload(dynamic data) {
  if (data is Map) {
    final err = _str(data['error']);
    if (err.isNotEmpty) return err;
  }
  if (data is String && data.trim().isNotEmpty) return data.trim();
  return null;
}

/// `ilan-gorsel-oku` edge function çağırır; hata metnini [StateError] olarak fırlatır.
Future<KurumIlanTaslak> okuKurumIlanGorseli({
  required String imageUrl,
}) async {
  final url = imageUrl.trim();
  if (url.isEmpty) {
    throw StateError('Görsel adresi boş.');
  }

  late final FunctionResponse res;
  try {
    res = await Supabase.instance.client.functions.invoke(
      'ilan-gorsel-oku',
      body: {'imageUrl': url},
    );
  } on FunctionException catch (e) {
    final fromDetails = _errorFromPayload(e.details);
    if (fromDetails != null) throw StateError(fromDetails);
    final reason = (e.reasonPhrase ?? '').trim();
    throw StateError(
      reason.isNotEmpty ? reason : 'Görsel okunamadı (HTTP ${e.status}).',
    );
  }

  final err = _errorFromPayload(res.data);
  if (err != null) throw StateError(err);

  final data = res.data;
  if (data is Map) {
    final fieldsRaw = data['fields'];
    if (fieldsRaw is! Map) {
      throw StateError('Görsel okuma sonucu beklenen formatta değil.');
    }
    return kurumIlanTaslakFromOcrFields(
      fields: Map<String, dynamic>.from(fieldsRaw),
      photoUrl: url,
    );
  }

  if (res.status >= 400) {
    throw StateError('Görsel okunamadı (HTTP ${res.status}).');
  }
  throw StateError('Görsel okuma yanıtı alınamadı.');
}
