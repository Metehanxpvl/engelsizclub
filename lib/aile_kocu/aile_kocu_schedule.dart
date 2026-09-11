/// Aile Koçu yerel bildirim payload’ları (`lesson|`, `med|`, `pnote|`, `test`).
/// FCM / diğer kanallara dokunmamak için yalnızca bu önekler iptal edilir.
bool isAileKocuScheduledPayload(String? payload) {
  final p = (payload ?? '').trim();
  if (p.isEmpty) return false;
  if (p == 'test') return true;
  return p.startsWith('lesson|') ||
      p.startsWith('med|') ||
      p.startsWith('pnote|');
}

bool isAileKocuPayloadFor({
  required String? payload,
  required String kind,
  required String itemId,
}) {
  final p = payload ?? '';
  if (itemId.isEmpty) return false;
  return p.startsWith('$kind|$itemId|') || p == '$kind|$itemId';
}

/// Aynı HH:mm birden fazla kez kaydedilmişse tek hatırlatma.
List<String> uniqueHhmmTimes(Iterable<String> times) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in times) {
    final t = raw.trim();
    if (t.isEmpty || !seen.add(t)) continue;
    out.add(t);
  }
  return out;
}
