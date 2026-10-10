/// Aile Koçu ders/ilaç hatırlatma zamanları (ekran saati, TZ yok).

/// [timeHhmm] örn. `15:30`. [weekdays] DateTime.weekday (1=Pzt … 7=Paz).
/// Boş [weekdays] = her gün. Geçmiş saatler atlanır; tam ders saati.
List<DateTime> aileKocuLessonNotifyAts({
  required String timeHhmm,
  required List<int> weekdays,
  required DateTime now,
  int horizonDays = 21,
}) {
  final parts = timeHhmm.split(':');
  if (parts.length < 2) return const [];
  final hh = int.tryParse(parts[0].trim()) ?? 0;
  final mm = int.tryParse(parts[1].trim()) ?? 0;
  final selected = weekdays.toSet();
  final start = DateTime(now.year, now.month, now.day);
  final out = <DateTime>[];
  for (var add = 0; add < horizonDays; add++) {
    final day = DateTime(start.year, start.month, start.day + add);
    if (selected.isNotEmpty && !selected.contains(day.weekday)) continue;
    final at = DateTime(day.year, day.month, day.day, hh, mm);
    if (!at.isAfter(now)) continue;
    out.add(at);
  }
  return out;
}

/// Ders bildirimi kimliği: aynı ders + gün ofseti (eski Object.hash çarpışmasın).
int aileKocuLessonNotifId(String lessonId, int dayOffset) {
  final base = _stablePositive('lesson|$lessonId') % 9000;
  return 410000000 + base * 32 + (dayOffset % 32);
}

/// Eski Object.hash(offset) kimlikleri — iptal için.
int aileKocuLessonNotifIdLegacyOffset(String lessonId, int dayOffset) =>
    Object.hash('lesson', lessonId, dayOffset) & 0x7fffffff;

int _stablePositive(String s) {
  var h = 2166136261;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 16777619) & 0x7fffffff;
  }
  return h;
}
