/// GS1 Data Matrix / QR on medicine packs → GTIN/EAN for `medicines` lookup.
///
/// Turkish boxes almost always carry AI `(01)` GTIN-14 in a square 2D symbol
/// (sometimes a QR). The payload is not an EAN-13 stripe.
class Gs1Barcode {
  Gs1Barcode._();

  static final _ai01Paren = RegExp(r'\(01\)(\d{14})');
  static final _plainGtin = RegExp(r'^\d{8}$|^\d{12,14}$');
  static final _digitalLink01 = RegExp(r'(?:/01/|[?&#]01=)(\d{8,14})');

  /// e-KT / digital leaflet URL from a scanned QR (not a GS1 resolver).
  /// GTIN is still taken from [lookupCode]; this is only the page to open.
  static String? prospectusHttpUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final uri = Uri.tryParse(s);
    if (uri == null) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    if (host == 'id.gs1.org' ||
        host == 'gs1.org' ||
        host.endsWith('.gs1.org')) {
      return null;
    }
    return uri.toString();
  }

  /// Cache / Gemini key: AI `01` GTIN if present, else raw if it looks like
  /// GTIN-8/12/13/14 or EAN.
  static String? lookupCode(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final paren = _ai01Paren.firstMatch(s);
    if (paren != null) return canonicalGtin(paren.group(1)!);

    final digital = _digitalLink01.firstMatch(s);
    if (digital != null) return canonicalGtin(digital.group(1)!);

    var body = s;
    if (body.startsWith(']') && body.length > 3) {
      body = body.substring(3);
    }
    // FNC1 is ASCII 232 (U+00E8); some decoders also emit GS at the start.
    body = body.replaceFirst(RegExp(r'^[\u00E8\u00EA\u001D\u001E]+'), '');

    final fromAi = _gtinFromAi01(body);
    if (fromAi != null) return canonicalGtin(fromAi);

    final compact = s.replaceAll(RegExp(r'[\s-]'), '');
    if (_plainGtin.hasMatch(compact)) return canonicalGtin(compact);

    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 8 || (digits.length >= 12 && digits.length <= 14)) {
      return canonicalGtin(digits);
    }
    return null;
  }

  /// GTIN-14 with leading 0 → EAN-13 (typical retail / ITS packing).
  static String canonicalGtin(String digits) {
    if (digits.length == 14 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    return digits;
  }

  /// GS1 check digit for the body (no check digit yet).
  static int checkDigit(String body) {
    var sum = 0;
    for (var i = 0; i < body.length; i++) {
      final n = int.parse(body[body.length - 1 - i]);
      sum += i.isEven ? n * 3 : n;
    }
    return (10 - (sum % 10)) % 10;
  }

  /// Index keys: GTIN-14, EAN-13 (drop leading 0). Same product only —
  /// no truncated / recalculated check-digit aliases.
  static List<String> cacheKeys(String code) {
    final c = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (c.isEmpty) return const [];
    final keys = <String>{c};
    if (c.length == 14 && c.startsWith('0')) keys.add(c.substring(1));
    if (c.length == 13) keys.add('0$c');
    if (c.length == 12) {
      keys.add('0$c');
      keys.add('00$c');
    }
    if (c.length == 8) keys.add(c);
    return keys.toList();
  }

  /// Exact GTIN forms only: the scanned digits plus 13↔14 / UPC leading-zero
  /// padding. Never drop or rewrite a check digit (that maps vitamins onto
  /// a nearby TİTCK drug).
  static List<GtinForm> lookupCandidates(String raw) {
    final parsed = lookupCode(raw);
    final digits = (parsed ?? raw).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 8 || digits.length > 14) return const [];
    final seen = <String>{};
    final out = <GtinForm>[];
    void add(String value, String form) {
      final v = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (v.length < 8 || v.length > 14) return;
      if (!seen.add(v)) return;
      out.add(GtinForm(value: v, form: form));
    }

    add(digits, 'raw');
    add(canonicalGtin(digits), 'canonical');
    if (digits.length == 12) {
      add('0$digits', 'ean13_pad');
      add('00$digits', 'gtin14_pad');
    }
    if (digits.length == 13) {
      add('0$digits', 'gtin14_pad');
    }
    if (digits.length == 14 && digits.startsWith('0')) {
      add(digits.substring(1), 'ean13_drop0');
    }
    return out;
  }

  /// Map keys for an exact GTIN hit (padding variants of the same number).
  static List<String> exactLookupKeys(String raw) {
    final keys = <String>{};
    for (final cand in lookupCandidates(raw)) {
      keys.addAll(cacheKeys(cand.value));
    }
    return keys.toList();
  }

  static List<String> lookupKeys(String raw) => exactLookupKeys(raw);

  static String? _gtinFromAi01(String body) {
    final parts = body.split(RegExp(r'[\u001D\u001E\u00E8]'));
    for (final part in parts) {
      final hit = _leading01(part);
      if (hit != null) return hit;
    }
    return _leading01(body);
  }

  static String? _leading01(String part) {
    if (part.startsWith('01') && part.length >= 16) {
      final gtin = part.substring(2, 16);
      if (RegExp(r'^\d{14}$').hasMatch(gtin)) return gtin;
    }
    return null;
  }
}

class GtinForm {
  const GtinForm({required this.value, required this.form});

  final String value;
  final String form;
}
