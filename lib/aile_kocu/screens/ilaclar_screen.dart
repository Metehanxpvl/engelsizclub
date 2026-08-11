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
import 'ilac_ekle_screen.dart';

class IlaclarScreen extends StatefulWidget {
  const IlaclarScreen({super.key});

  @override
  State<IlaclarScreen> createState() => _IlaclarScreenState();
}

class _IlaclarScreenState extends State<IlaclarScreen> {
  Future<void> _refreshNotifs() async {
    final s = loadSettings();
    for (final m in medicinesBox.values) {
      await AileKocuNotificationService.instance.rescheduleMedicine(
        medicineId: m.id,
        childName: s.childName,
        title: m.name,
        dosage: m.dosage,
        times: m.times,
        weekdays: m.days,
        photoPath: s.photoPath,
        endDate: m.endDate,
      );
    }
  }

  int _streak(Medicine m) {
    var streak = 0;
    var day = DateTime.now();
    for (var i = 0; i < 60; i++) {
      final key = todayKey(day);
      final allTaken = m.times.every((t) => m.takenDatesMap['$key|$t'] == true);
      if (!allTaken) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Future<void> _markTaken(Medicine m, String time) async {
    final key = '${todayKey()}|$time';
    final map = Map<String, bool>.from(m.takenDatesMap);
    map[key] = true;
    m.takenDatesMap = map;
    await medicinesBox.put(m.id, m);
    final streak = _streak(m);
    if (!mounted) return;
    setState(() {});
    if (streak >= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            streak == 1
                ? 'Bugün içildi ✅'
                : '$streak gündür aksatmadın 👏',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = loadSettings();
    final photo = childPhotoProvider(s.photoPath);
    final wd = DateTime.now().weekday;
    return Scaffold(
      backgroundColor: MetoColors.background,
      appBar: AppBar(
        title: Text(childPageTitle('İlaçları')),
        backgroundColor: MetoColors.card,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final r = await Navigator.push<Medicine>(
            context,
            MaterialPageRoute(builder: (_) => const IlacEkleScreen()),
          );
          if (r != null) {
            await _refreshNotifs();
            if (!mounted) return;
            setState(() {});
            if (kIsWeb) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'İlaç kaydedildi. Saat bildirimi yalnızca Android / iOS uygulamasında çalışır.',
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '"${r.name}" için hatırlatıcı kuruldu '
                    '(${r.times.join(', ')})',
                  ),
                ),
              );
            }
          }
        },
        backgroundColor: Colors.red.shade600,
        icon: const Icon(Icons.add),
        label: const Text('Yeni İlaç'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.red.shade100,
                  backgroundImage: photo,
                  child: photo == null
                      ? Icon(Icons.medical_services, color: Colors.red.shade700)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    childPageTitle('İlaçları'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'BUGÜN',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: medicinesBox.listenable(),
              builder: (context, Box<Medicine> box, _) {
                final todayItems = <({Medicine m, String t})>[];
                for (final m in box.values) {
                  final activeDays = m.days.isEmpty || m.days.contains(wd);
                  if (!activeDays) continue;
                  if (m.endDate != null &&
                      DateTime.now().isAfter(
                        m.endDate!.add(const Duration(days: 1)),
                      )) {
                    continue;
                  }
                  for (final t in m.times) {
                    todayItems.add((m: m, t: t));
                  }
                }
                todayItems.sort((a, b) => a.t.compareTo(b.t));
                if (todayItems.isEmpty) {
                  return const Center(child: Text('Bugün ilaç yok.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: todayItems.length,
                  itemBuilder: (context, i) {
                    final item = todayItems[i];
                    final taken =
                        item.m.takenDatesMap['${todayKey()}|${item.t}'] == true;
                    return AkSwipeToDelete(
                      itemKey: 'med_${item.m.id}_${item.t}',
                      confirmMessage:
                          '"${item.m.name}" ilacı tamamen silinsin mi?',
                      onDelete: () async {
                        final id = item.m.id;
                        final times = List<String>.from(item.m.times);
                        // Önce Hive — UI anında güncellensin; bildirimler arka planda.
                        await medicinesBox.delete(id);
                        unawaited(() async {
                          try {
                            await AileKocuNotificationService.instance
                                .cancelMedicine(id, times: times)
                                .timeout(const Duration(seconds: 3));
                          } catch (e) {
                            debugPrint('İlaç bildirimi iptal: $e');
                          }
                        }());
                      },
                      child: Card(
                        child: ListTile(
                          title: Text(
                            '${item.t}  ${item.m.name}  ${item.m.dosage}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            taken ? 'İÇTİ ✅' : 'Bekliyor',
                            style: TextStyle(
                              color: taken ? Colors.green : MetoColors.mutedFg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: taken
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : FilledButton(
                                  onPressed: () =>
                                      _markTaken(item.m, item.t),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                  ),
                                  child: const Text('İÇTİM'),
                                ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    IlacEkleScreen(existing: item.m),
                              ),
                            );
                            await _refreshNotifs();
                            setState(() {});
                          },
                        ),
                      ),
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
