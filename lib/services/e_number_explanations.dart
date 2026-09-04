import '../models/product_safety.dart';

/// Yaygın AB E-kodları — etiket bilgisi, tıbbi iddia değil.
class ENumberInfo {
  const ENumberInfo(this.nameTr, this.functionTr, {this.flag});

  final String nameTr;
  final String functionTr;
  /// `child` | `dye` | `caution` | null
  final String? flag;

  String get phrase => '$nameTr ($functionTr)';
}

/// Bileşen listesindeki E-kodları için yerel Türkçe açıklama.
class ENumberExplanations {
  ENumberExplanations._();

  static String normalizeCode(String raw) {
    var s = raw.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'[\s_\-]'), '');
    s = s.replaceAll('(', '').replaceAll(')', '');
    if (s.startsWith('e')) {
      return s;
    }
    if (RegExp(r'^\d{3,4}[a-z]{0,3}$').hasMatch(s)) {
      return 'e$s';
    }
    return s;
  }

  /// `E500`, `E150d`
  static String formatCode(String raw) {
    final n = normalizeCode(raw);
    if (n.length < 2 || !n.startsWith('e')) {
      return raw.trim().toUpperCase();
    }
    final rest = n.substring(1);
    final m = RegExp(r'^(\d{3,4})([a-z]*)$').firstMatch(rest);
    if (m == null) return 'E${rest.toUpperCase()}';
    return 'E${m.group(1)}${m.group(2)}';
  }

  static ENumberInfo? lookup(String raw) {
    final n = normalizeCode(raw);
    if (n.isEmpty) return null;
    final direct = _map[n];
    if (direct != null) return direct;
    final base = RegExp(r'^(e\d{3,4})').firstMatch(n)?.group(1);
    if (base != null && base != n) return _map[base];
    return null;
  }

  static AdditiveHit enrich(AdditiveHit hit) {
    final code = normalizeCode(hit.code);
    if (code.isEmpty) return hit;
    final info = lookup(code);
    final label = hit.labelTr.trim();
    final isBareCode = label.isEmpty ||
        normalizeCode(label) == code ||
        label.toUpperCase() == formatCode(code);
    if (info == null) {
      if (isBareCode) {
        return AdditiveHit(
          code: code,
          labelTr: 'katkı maddesi (bileşen listesinde yer alıyor)',
          flag: hit.flag,
        );
      }
      return AdditiveHit(code: code, labelTr: label, flag: hit.flag);
    }
    return AdditiveHit(
      code: code,
      labelTr: info.phrase,
      flag: hit.flag ?? info.flag,
    );
  }

  /// `E500 — sodyum karbonatlar (asitlik düzenleyici)`
  static String displayLine(AdditiveHit hit) {
    final enriched = enrich(hit);
    return '${formatCode(enriched.code)} — ${enriched.labelTr}';
  }

  /// E500, E-330, E 150d, en:e322 — etiket / OFF / Gemini metni.
  static final eCodePattern = RegExp(
    r'(?:^|[^a-z0-9])e\s*[-.]?\s*(\d{3,4}[a-z]{0,3})',
    caseSensitive: false,
  );

  static Iterable<String> extractECodes(String? text) sync* {
    final s = (text ?? '').toLowerCase();
    if (s.trim().isEmpty) return;
    for (final match in eCodePattern.allMatches(s)) {
      final g = match.group(1);
      if (g == null || g.isEmpty) continue;
      yield 'e$g';
    }
  }

  /// Rapor + içindekiler: E-kodları ve E’siz yazılmış katkılar (lesitin, aroma…).
  static List<AdditiveHit> forDisplay({
    required List<AdditiveHit> additives,
    String? ingredients,
  }) {
    final map = <String, AdditiveHit>{};
    void put(AdditiveHit hit) {
      final key = hit.code.trim().isNotEmpty
          ? normalizeCode(hit.code)
          : hit.labelTr.trim().toLowerCase();
      if (key.isEmpty) return;
      map.putIfAbsent(key, () => hit);
    }

    for (final a in additives) {
      var raw = a.code.trim();
      if (raw.isEmpty) raw = a.labelTr.trim();
      if (raw.isEmpty) continue;
      final normalized = normalizeCode(raw);
      if (normalized.startsWith('e') &&
          RegExp(r'^e\d{3,4}[a-z]{0,3}$').hasMatch(normalized)) {
        put(enrich(
          AdditiveHit(code: normalized, labelTr: a.labelTr, flag: a.flag),
        ));
        continue;
      }
      final codes = extractECodes('$raw ${a.labelTr}').toList();
      if (codes.isNotEmpty) {
        for (final code in codes) {
          put(enrich(AdditiveHit(code: code, labelTr: '')));
        }
        continue;
      }
      put(AdditiveHit(code: raw, labelTr: a.labelTr, flag: a.flag));
    }
    for (final code in extractECodes(ingredients)) {
      put(enrich(AdditiveHit(code: code, labelTr: '')));
    }
    for (final named in extractNamedAdditives(
      ingredients,
      existingCodes: map.keys,
    )) {
      put(named);
    }
    return map.values.toList();
  }

  /// Etikette E-kodu yazılmayan katkılar (Ayçiçek lesitini, aroma…).
  /// Emülgatör + lesitin = tek katkı; aroma + vanilin = tek aroma.
  /// Aynı işlevin E-kodu zaten varsa ikinci kez sayılmaz.
  static List<AdditiveHit> extractNamedAdditives(
    String? text, {
    Iterable<String> existingCodes = const [],
  }) {
    final folded = _fold(text ?? '');
    if (folded.isEmpty) return const [];
    final have = {
      for (final c in existingCodes) normalizeCode(c),
    };
    bool hasPrefix(String prefix) => have.any((c) => c.startsWith(prefix));
    final out = <AdditiveHit>[];

    if (_hasWord(folded, 'lesitin') || _hasWord(folded, 'lecithin')) {
      if (!have.contains('e322')) {
        out.add(enrich(const AdditiveHit(code: 'e322', labelTr: 'lesitin')));
      }
    } else if (!hasPrefix('e47') &&
        !hasPrefix('e322') &&
        (_hasWord(folded, 'emulgator') || _hasWord(folded, 'emulsifier'))) {
      out.add(
        const AdditiveHit(code: 'named:emulgator', labelTr: 'emülgatör'),
      );
    }

    if (_hasWord(folded, 'vanilin') || _hasWord(folded, 'vanillin')) {
      out.add(const AdditiveHit(code: 'named:vanilin', labelTr: 'vanilin'));
    } else if (_hasWord(folded, 'aroma') ||
        _hasWord(folded, 'flavour') ||
        _hasWord(folded, 'flavoring')) {
      out.add(const AdditiveHit(code: 'named:aroma', labelTr: 'aroma'));
    }

    if (!hasPrefix('e95') &&
        (_hasWord(folded, 'tatlandirici') || _hasWord(folded, 'sweetener'))) {
      out.add(
        const AdditiveHit(code: 'named:tatlandirici', labelTr: 'tatlandırıcı'),
      );
    }
    if (!hasPrefix('e1') &&
        (_hasWord(folded, 'renk verici') ||
            _hasWord(folded, 'renklendirici') ||
            _hasWord(folded, 'colorant'))) {
      out.add(
        const AdditiveHit(code: 'named:renk', labelTr: 'renklendirici'),
      );
    }
    if (!hasPrefix('e40') &&
        !hasPrefix('e41') &&
        (_hasWord(folded, 'kivam arttirici') ||
            _hasWord(folded, 'kivam artirici') ||
            _hasWord(folded, 'thickener') ||
            _hasWord(folded, 'stabilizator') ||
            _hasWord(folded, 'stabilizer'))) {
      out.add(
        const AdditiveHit(code: 'named:kivam', labelTr: 'kıvam artırıcı'),
      );
    }
    return out;
  }

  static bool _hasWord(String folded, String word) {
    // lesitini / aromasi gibi Türkçe ekleri de tut.
    return RegExp('(?:^|[^a-z0-9])${RegExp.escape(word)}').hasMatch(folded);
  }

  static String _fold(String s) {
    return s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
  }

  /// Gösterim için düzey: E-kodları + içindekiler. Alan yoksa da bar üretir.
  static AdditiveRiskLevel riskForDisplay({
    required List<AdditiveHit> additives,
    String? ingredients,
    bool ingredientsKnown = false,
  }) {
    return AdditiveRiskLevel.fromAdditives(
      forDisplay(additives: additives, ingredients: ingredients),
      ingredientsKnown: ingredientsKnown,
    );
  }

  static const _map = <String, ENumberInfo>{
    // Renklendiriciler
    'e100': ENumberInfo('kurkumin', 'renklendirici'),
    'e101': ENumberInfo('riboflavin', 'renklendirici'),
    'e102': ENumberInfo('tartrazin', 'renklendirici', flag: 'dye'),
    'e104': ENumberInfo('kinolin sarısı', 'renklendirici', flag: 'dye'),
    'e110': ENumberInfo('sunset yellow (günbatımı sarısı)', 'renklendirici',
        flag: 'dye'),
    'e120': ENumberInfo('karmin / koşineal', 'renklendirici'),
    'e122': ENumberInfo('azorubin (karmosin)', 'renklendirici', flag: 'dye'),
    'e124': ENumberInfo('ponceau 4R', 'renklendirici', flag: 'dye'),
    'e129': ENumberInfo('allura kırmızı AC', 'renklendirici', flag: 'dye'),
    'e131': ENumberInfo('patent mavisi V', 'renklendirici', flag: 'dye'),
    'e132': ENumberInfo('indigotin', 'renklendirici', flag: 'dye'),
    'e133': ENumberInfo('brilliant blue FCF', 'renklendirici', flag: 'dye'),
    'e140': ENumberInfo('klorofiller', 'renklendirici'),
    'e141': ENumberInfo('bakır klorofiller', 'renklendirici'),
    'e150a': ENumberInfo('sade karamel', 'renklendirici'),
    'e150c': ENumberInfo('amonyak karameli', 'renklendirici'),
    'e150d': ENumberInfo('sülfit amonyak karameli', 'renklendirici'),
    'e153': ENumberInfo('bitkisel karbon', 'renklendirici'),
    'e160a': ENumberInfo('karotenler', 'renklendirici'),
    'e160c': ENumberInfo('paprika ekstraktı', 'renklendirici'),
    'e160e': ENumberInfo('beta-apo-8′-karotenal', 'renklendirici'),
    'e162': ENumberInfo('pancar kırmızısı (betanin)', 'renklendirici'),
    'e163': ENumberInfo('antosiyaninler', 'renklendirici'),
    'e170': ENumberInfo('kalsiyum karbonat', 'renklendirici / asitlik düzenleyici'),
    'e171': ENumberInfo('titanyum dioksit', 'renklendirici'),
    'e172': ENumberInfo('demir oksitler', 'renklendirici'),

    // Koruyucular
    'e200': ENumberInfo('sorbik asit', 'koruyucu'),
    'e202': ENumberInfo('potasyum sorbat', 'koruyucu'),
    'e210': ENumberInfo('benzoik asit', 'koruyucu'),
    'e211': ENumberInfo('sodyum benzoat', 'koruyucu', flag: 'caution'),
    'e212': ENumberInfo('potasyum benzoat', 'koruyucu'),
    'e220': ENumberInfo('kükürt dioksit', 'koruyucu'),
    'e221': ENumberInfo('sodyum sülfit', 'koruyucu'),
    'e223': ENumberInfo('sodyum metabisülfit', 'koruyucu'),
    'e224': ENumberInfo('potasyum metabisülfit', 'koruyucu'),
    'e249': ENumberInfo('potasyum nitrit', 'koruyucu', flag: 'caution'),
    'e250': ENumberInfo('sodyum nitrit', 'koruyucu', flag: 'caution'),
    'e251': ENumberInfo('sodyum nitrat', 'koruyucu', flag: 'caution'),
    'e252': ENumberInfo('potasyum nitrat', 'koruyucu', flag: 'caution'),
    'e260': ENumberInfo('asetik asit', 'koruyucu / asitlik düzenleyici'),
    'e262': ENumberInfo('sodyum asetatlar', 'koruyucu / asitlik düzenleyici'),
    'e270': ENumberInfo('laktik asit', 'asitlik düzenleyici'),
    'e280': ENumberInfo('propiyonik asit', 'koruyucu'),
    'e282': ENumberInfo('kalsiyum propiyonat', 'koruyucu'),
    'e290': ENumberInfo('karbondioksit', 'gaz / asitlik düzenleyici'),
    'e296': ENumberInfo('malik asit', 'asitlik düzenleyici'),
    'e297': ENumberInfo('fumarik asit', 'asitlik düzenleyici'),

    // Antioksidanlar / asitlik
    'e300': ENumberInfo('askorbik asit (C vitamini)', 'antioksidan'),
    'e301': ENumberInfo('sodyum askorbat', 'antioksidan'),
    'e302': ENumberInfo('kalsiyum askorbat', 'antioksidan'),
    'e304': ENumberInfo('askorbil palmitat', 'antioksidan'),
    'e306': ENumberInfo('tokoferol açısından zengin ekstrakt', 'antioksidan'),
    'e307': ENumberInfo('alfa-tokoferol', 'antioksidan'),
    'e320': ENumberInfo('BHA (bütillenmiş hidroksianisol)', 'antioksidan'),
    'e321': ENumberInfo('BHT (bütillenmiş hidroksitoluen)', 'antioksidan'),
    'e322': ENumberInfo('lesitin', 'emülgatör'),
    'e325': ENumberInfo('sodyum laktat', 'asitlik düzenleyici'),
    'e330': ENumberInfo('sitrik asit', 'asitlik düzenleyici'),
    'e331': ENumberInfo('sodyum sitratlar', 'asitlik düzenleyici'),
    'e332': ENumberInfo('potasyum sitratlar', 'asitlik düzenleyici'),
    'e333': ENumberInfo('kalsiyum sitratlar', 'asitlik düzenleyici'),
    'e334': ENumberInfo('tartarik asit', 'asitlik düzenleyici'),
    'e336': ENumberInfo('potasyum tartratlar', 'asitlik düzenleyici'),
    'e338': ENumberInfo('fosforik asit', 'asitlik düzenleyici'),
    'e339': ENumberInfo('sodyum fosfatlar', 'asitlik düzenleyici'),
    'e340': ENumberInfo('potasyum fosfatlar', 'asitlik düzenleyici'),
    'e341': ENumberInfo('kalsiyum fosfatlar', 'asitlik düzenleyici / topaklanmayı önleyici'),
    'e385': ENumberInfo('kalsiyum disodyum EDTA', 'şelat ajanı'),

    // Kıvam / emülgatör
    'e400': ENumberInfo('aljinik asit', 'kıvam artırıcı'),
    'e401': ENumberInfo('sodyum aljinat', 'kıvam artırıcı'),
    'e406': ENumberInfo('agar', 'jelleştirici'),
    'e407': ENumberInfo('karragenan', 'kıvam artırıcı'),
    'e410': ENumberInfo('keçiboynuzu gamı', 'kıvam artırıcı'),
    'e412': ENumberInfo('guar gamı', 'kıvam artırıcı'),
    'e414': ENumberInfo('arap zamkı', 'kıvam artırıcı'),
    'e415': ENumberInfo('ksantan gamı', 'kıvam artırıcı'),
    'e418': ENumberInfo('gellan gamı', 'jelleştirici'),
    'e420': ENumberInfo('sorbitol', 'tatlandırıcı / nem tutucu'),
    'e421': ENumberInfo('mannitol', 'tatlandırıcı'),
    'e422': ENumberInfo('gliserol', 'nem tutucu'),
    'e440': ENumberInfo('pektin', 'jelleştirici'),
    'e450': ENumberInfo('difosfatlar', 'asitlik düzenleyici / emülgatör'),
    'e451': ENumberInfo('trifosfatlar', 'asitlik düzenleyici'),
    'e452': ENumberInfo('polifosfatlar', 'asitlik düzenleyici'),
    'e460': ENumberInfo('selüloz', 'dolgu maddesi'),
    'e466': ENumberInfo('karboksimetil selüloz (CMC)', 'kıvam artırıcı'),
    'e471': ENumberInfo('yağ asitlerinin mono- ve digliseritleri', 'emülgatör'),
    'e472a': ENumberInfo('asetik asit esterleri (mono/digliserit)', 'emülgatör'),
    'e472b': ENumberInfo('laktik asit esterleri (mono/digliserit)', 'emülgatör'),
    'e472c': ENumberInfo('sitrik asit esterleri (mono/digliserit)', 'emülgatör'),
    'e472e': ENumberInfo('DATEM (diacetil tartarik asit esterleri)', 'emülgatör'),
    'e475': ENumberInfo('poliggliserol esterleri', 'emülgatör'),
    'e476': ENumberInfo('poliggliserol polirisinoleat (PGPR)', 'emülgatör'),
    'e481': ENumberInfo('sodyum stearoil-2-laktat', 'emülgatör'),
    'e491': ENumberInfo('sorbitan monostearat', 'emülgatör'),

    // Asitlik düzenleyici / tuzlar
    'e500': ENumberInfo('sodyum karbonatlar', 'asitlik düzenleyici'),
    'e500i': ENumberInfo('sodyum karbonat', 'asitlik düzenleyici'),
    'e500ii': ENumberInfo('sodyum bikarbonat', 'asitlik düzenleyici / kabartıcı'),
    'e501': ENumberInfo('potasyum karbonatlar', 'asitlik düzenleyici'),
    'e503': ENumberInfo('amonyum karbonatlar', 'asitlik düzenleyici / kabartıcı'),
    'e504': ENumberInfo('magnezyum karbonatlar', 'asitlik düzenleyici'),
    'e507': ENumberInfo('hidroklorik asit', 'asitlik düzenleyici'),
    'e508': ENumberInfo('potasyum klorür', 'tat / asitlik düzenleyici'),
    'e509': ENumberInfo('kalsiyum klorür', 'sertleştirici'),
    'e511': ENumberInfo('magnezyum klorür', 'sertleştirici'),
    'e516': ENumberInfo('kalsiyum sülfat', 'sertleştirici'),
    'e524': ENumberInfo('sodyum hidroksit', 'asitlik düzenleyici'),
    'e551': ENumberInfo('silikon dioksit', 'topaklanmayı önleyici'),
    'e553b': ENumberInfo('talk', 'topaklanmayı önleyici'),
    'e554': ENumberInfo('sodyum alüminyum silikat', 'topaklanmayı önleyici'),

    // Lezzet artırıcılar
    'e620': ENumberInfo('glutamik asit', 'lezzet artırıcı'),
    'e621': ENumberInfo('monosodyum glutamat (MSG)', 'lezzet artırıcı',
        flag: 'caution'),
    'e627': ENumberInfo('disodyum guanilat', 'lezzet artırıcı'),
    'e631': ENumberInfo('disodyum inosinat', 'lezzet artırıcı'),
    'e635': ENumberInfo('disodyum ribonükleotitler', 'lezzet artırıcı'),

    // Tatlandırıcılar
    'e950': ENumberInfo('asesülfam K', 'tatlandırıcı', flag: 'child'),
    'e951': ENumberInfo('aspartam', 'tatlandırıcı', flag: 'child'),
    'e952': ENumberInfo('siklomatlar', 'tatlandırıcı', flag: 'child'),
    'e953': ENumberInfo('izomalt', 'tatlandırıcı'),
    'e954': ENumberInfo('sakarin', 'tatlandırıcı', flag: 'child'),
    'e955': ENumberInfo('sukraloz', 'tatlandırıcı', flag: 'child'),
    'e957': ENumberInfo('taumatin', 'tatlandırıcı'),
    'e959': ENumberInfo('neohesperidin DC', 'tatlandırıcı'),
    'e960': ENumberInfo('steviol glikozitler', 'tatlandırıcı'),
    'e961': ENumberInfo('neotam', 'tatlandırıcı', flag: 'child'),
    'e962': ENumberInfo('aspartam-asesülfam tuzu', 'tatlandırıcı', flag: 'child'),
    'e965': ENumberInfo('maltitol', 'tatlandırıcı'),
    'e966': ENumberInfo('laktitol', 'tatlandırıcı'),
    'e967': ENumberInfo('ksilitol', 'tatlandırıcı'),
    'e968': ENumberInfo('eritritol', 'tatlandırıcı'),
    'e969': ENumberInfo('advantam', 'tatlandırıcı', flag: 'child'),

    // Diğer yaygın
    'e901': ENumberInfo('balmumu', 'parlatıcı'),
    'e903': ENumberInfo('karnauba mumu', 'parlatıcı'),
    'e904': ENumberInfo('şellak', 'parlatıcı'),
    'e941': ENumberInfo('azot', 'ambalaj gazı'),
    'e948': ENumberInfo('oksijen', 'ambalaj gazı'),
    'e1105': ENumberInfo('lizozim', 'koruyucu'),
    'e1200': ENumberInfo('polidekstroz', 'dolgu / lif'),
    'e1400': ENumberInfo('dekstrin', 'modifiye nişasta'),
    'e1404': ENumberInfo('oksidize nişasta', 'modifiye nişasta'),
    'e1412': ENumberInfo('distarç fosfat', 'modifiye nişasta'),
    'e1414': ENumberInfo('asetillenmiş distarç fosfat', 'modifiye nişasta'),
    'e1422': ENumberInfo('asetillenmiş distarç adipat', 'modifiye nişasta'),
    'e1440': ENumberInfo('hidroksipropil nişasta', 'modifiye nişasta'),
    'e1442': ENumberInfo('hidroksipropil distarç fosfat', 'modifiye nişasta'),
    'e1450': ENumberInfo('nişasta sodyum oktenil süksinat', 'modifiye nişasta / emülgatör'),
  };
}
