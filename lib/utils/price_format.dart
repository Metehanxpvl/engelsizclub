/// Fiyat metnini Türkçe binlik ayracıyla biçimlendirir ve "TL" ekler.
/// Örn: "10000" → "10.000 TL", "₺1.250,50" → "1.250,50 TL"
String formatPriceTl(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty || t == '—' || t == '-') return t;

  var core = t
      .replaceAll('₺', ' ')
      .replaceAll(RegExp(r'\bTRY\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\bTL\b', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (core.isEmpty) return t;
  if (!RegExp(r'\d').hasMatch(core)) return t;

  final formatted = core.replaceAllMapped(
    RegExp(r'\d+(?:[.,]\d+)?'),
    (m) => _formatTrNumber(m.group(0)!),
  );
  return '$formatted TL';
}

String _formatTrNumber(String raw) {
  final hasComma = raw.contains(',');
  final hasDot = raw.contains('.');

  String intPart;
  String? fracPart;

  if (hasComma && hasDot) {
    // 1.250,50 veya 1,250.50
    if (raw.lastIndexOf(',') > raw.lastIndexOf('.')) {
      final parts = raw.split(',');
      intPart = parts.first.replaceAll('.', '');
      fracPart = parts.length > 1 ? parts.sublist(1).join() : null;
    } else {
      final parts = raw.split('.');
      intPart = parts.first.replaceAll(',', '');
      fracPart = parts.length > 1 ? parts.sublist(1).join() : null;
    }
  } else if (hasComma) {
    final parts = raw.split(',');
    // "49,90" ondalık; "1,250" büyük ihtimalle binlik (EN)
    if (parts.length == 2 && parts[1].length <= 2) {
      intPart = parts[0].replaceAll(RegExp(r'[^\d]'), '');
      fracPart = parts[1];
    } else {
      intPart = raw.replaceAll(RegExp(r'[^\d]'), '');
      fracPart = null;
    }
  } else if (hasDot) {
    final parts = raw.split('.');
    if (parts.length == 2 && parts[1].length <= 2 && parts[0].length <= 3) {
      // "49.90" ondalık varsayımı
      intPart = parts[0].replaceAll(RegExp(r'[^\d]'), '');
      fracPart = parts[1];
    } else {
      intPart = raw.replaceAll(RegExp(r'[^\d]'), '');
      fracPart = null;
    }
  } else {
    intPart = raw.replaceAll(RegExp(r'[^\d]'), '');
    fracPart = null;
  }

  if (intPart.isEmpty) return raw;
  final grouped = _groupThousands(intPart);
  if (fracPart == null || fracPart.isEmpty) return grouped;
  return '$grouped,$fracPart';
}

String _groupThousands(String digits) {
  final buf = StringBuffer();
  final n = digits.length;
  for (var i = 0; i < n; i++) {
    if (i > 0 && (n - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return buf.toString();
}
