import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../meto_theme.dart';
import '../aile_kocu_store.dart';
import '../child_photo.dart';
import '../models/aile_kocu_models.dart';
import '../notification_service.dart';
import '../widgets/ak_swipe_delete.dart';
import 'ders_ekle_screen.dart';

class DerslerScreen extends StatefulWidget {
  const DerslerScreen({super.key});

  @override
  State<DerslerScreen> createState() => _DerslerScreenState();
}

class _DerslerScreenState extends State<DerslerScreen> {
  Future<void> _refreshNotifs() async {
    final s = loadSettings();
    for (final lesson in lessonsBox.values) {
      await AileKocuNotificationService.instance.rescheduleLesson(
        lessonId: lesson.id,
        childName: s.childName,
        title: lesson.name,
        timeHhmm: lesson.time,
        weekdays: lesson.days,
        photoPath: s.photoPath,
      );
    }
  }

  Future<void> _add() async {
    final r = await Navigator.push<Lesson>(
      context,
      MaterialPageRoute(builder: (_) => const DersEkleScreen()),
    );
    if (r != null) {
      await _refreshNotifs();
      if (!mounted) return;
      setState(() {});
      final n = AileKocuNotificationService.instance;
      await n.ensurePermissions();
      if (!mounted) return;
      if (!n.notificationsAllowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ders kaydedildi ama bildirim izni kapalı. Ayarlar’dan açın.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleDone(Lesson lesson, int weekday) async {
    // Aynı ders Pzt/Çar/Cum'da görünür; tamamlandı yalnızca o günün tarihi için.
    final key = todayKey(dateOfWeekdayThisWeek(weekday));
    final map = Map<String, bool>.from(lesson.doneDates);
    map[key] = !(map[key] ?? false);
    final updated = Lesson(
      id: lesson.id,
      name: lesson.name,
      days: List<int>.from(lesson.days),
      time: lesson.time,
      location: lesson.location,
      note: lesson.note,
      doneDates: map,
    );
    await lessonsBox.put(updated.id, updated);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = loadSettings();
    final photo = childPhotoProvider(s.photoPath);
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        title: Text(childPageTitle('Haftası')),
        backgroundColor: MetoColors.card,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: MetoColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('Yeni Ders'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: photo,
                  child: photo == null
                      ? const Icon(Icons.child_care, color: Colors.blue)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    childPageTitle('Haftası'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: lessonsBox.listenable(),
              builder: (context, Box<Lesson> box, _) {
                final byDay = <int, List<Lesson>>{};
                for (final l in box.values) {
                  for (final d in l.days) {
                    byDay.putIfAbsent(d, () => []).add(l);
                  }
                }
                if (byDay.isEmpty) {
                  return const Center(
                    child: Text('Henüz ders yok. + ile ekleyin.'),
                  );
                }
                final days = byDay.keys.toList()..sort();
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
                  itemCount: days.length,
                  itemBuilder: (context, i) {
                    final day = days[i];
                    final list = byDay[day]!
                      ..sort((a, b) => a.time.compareTo(b.time));
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            dayLabel(day),
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: Colors.blue.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        for (final lesson in list)
                          AkSwipeToDelete(
                            itemKey: 'lesson_${lesson.id}_$day',
                            confirmMessage:
                                '"${lesson.name}" dersi silinsin mi?',
                            onDelete: () async {
                              final id = lesson.id;
                              await lessonsBox.delete(id);
                              unawaited(() async {
                                try {
                                  await AileKocuNotificationService.instance
                                      .cancelLesson(id)
                                      .timeout(const Duration(seconds: 3));
                                } catch (e) {
                                  debugPrint('Ders bildirimi iptal: $e');
                                }
                              }());
                            },
                            child: Builder(
                              builder: (context) {
                                final dayKey =
                                    todayKey(dateOfWeekdayThisWeek(day));
                                final done =
                                    lesson.doneDates[dayKey] == true;
                                return Card(
                                  child: ListTile(
                                    title: Text(
                                      '${lesson.time}  ${lesson.name}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (lesson.location.isNotEmpty)
                                          '@ ${lesson.location}',
                                        if (done) 'YAPILDI',
                                      ].join(' · '),
                                    ),
                                    trailing: IconButton(
                                      icon: Icon(
                                        done
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: done
                                            ? Colors.green
                                            : MetoColors.mutedFg,
                                        size: 32,
                                      ),
                                      onPressed: () =>
                                          _toggleDone(lesson, day),
                                    ),
                                    onTap: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => DersEkleScreen(
                                            existing: lesson,
                                          ),
                                        ),
                                      );
                                      await _refreshNotifs();
                                      setState(() {});
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
