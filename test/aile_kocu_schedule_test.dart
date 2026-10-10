import 'package:engelsizclub/aile_kocu/aile_kocu_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lesson notify is at class time, not two hours early', () {
    final now = DateTime(2026, 10, 1, 10, 0); // Thursday
    final ats = aileKocuLessonNotifyAts(
      timeHhmm: '15:30',
      weekdays: const [4],
      now: now,
    );
    expect(ats, isNotEmpty);
    expect(ats.first, DateTime(2026, 10, 1, 15, 30));
    expect(
      ats.every((t) => t.hour == 15 && t.minute == 30),
      isTrue,
    );
  });

  test('five weekdays schedule on five different dates', () {
    final now = DateTime(2026, 9, 27, 8, 0); // Sunday
    final ats = aileKocuLessonNotifyAts(
      timeHhmm: '14:00',
      weekdays: const [1, 2, 3, 4, 5],
      now: now,
      horizonDays: 7,
    );
    expect(ats.length, 5);
    expect(ats.map((t) => t.weekday).toSet(), {1, 2, 3, 4, 5});
    expect(ats.map((t) => t.day).toSet().length, 5);
    expect(
      ats.map((t) => DateTime(t.year, t.month, t.day)).toSet().length,
      5,
    );
  });

  test('past lesson today is skipped, later weekdays stay', () {
    final now = DateTime(2026, 10, 1, 16, 0); // Thursday 16:00
    final ats = aileKocuLessonNotifyAts(
      timeHhmm: '15:00',
      weekdays: const [1, 2, 3, 4, 5],
      now: now,
      horizonDays: 8,
    );
    expect(ats.first.weekday, 5);
    expect(ats.where((t) => t.day == 1 && t.month == 10), isEmpty);
  });

  test('lesson notification ids differ per day offset', () {
    const id = 'lesson-abc';
    expect(aileKocuLessonNotifId(id, 0), isNot(aileKocuLessonNotifId(id, 1)));
    expect(aileKocuLessonNotifId(id, 4), isNot(aileKocuLessonNotifId(id, 5)));
  });
}
