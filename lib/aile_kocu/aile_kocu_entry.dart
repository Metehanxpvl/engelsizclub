import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../meto_theme.dart';
import 'aile_kocu_store.dart';
import 'notification_service.dart';
import 'screens/aile_kocu_ayarlar.dart';
import 'screens/cocuk_notlari_screen.dart';
import 'screens/dersler_screen.dart';
import 'screens/ilaclar_screen.dart';
import 'screens/notlarim_screen.dart';

/// Aile Koçum hub — 4 sekme + ayarlar. %100 offline (Hive).
class AileKocuHubPage extends StatefulWidget {
  const AileKocuHubPage({super.key});

  @override
  State<AileKocuHubPage> createState() => _AileKocuHubPageState();
}

class _AileKocuHubPageState extends State<AileKocuHubPage> {
  int _index = 0;

  static const _pages = <Widget>[
    DerslerScreen(),
    IlaclarScreen(),
    CocukNotlariScreen(),
    NotlarimScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Dersler',
          ),
          NavigationDestination(
            icon: Icon(Icons.medical_services_outlined),
            selectedIcon: Icon(Icons.medical_services),
            label: 'İlaçlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.child_care_outlined),
            selectedIcon: Icon(Icons.child_care),
            label: 'Çocuk',
          ),
          NavigationDestination(
            icon: Icon(Icons.note_alt_outlined),
            selectedIcon: Icon(Icons.note_alt),
            label: 'Notlarım',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: FloatingActionButton.small(
          heroTag: 'ak_settings',
          backgroundColor: MetoColors.card,
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AileKocuAyarlarScreen()),
            );
            setState(() {});
          },
          child: const Icon(Icons.settings, color: MetoColors.foreground),
        ),
      ),
    );
  }
}

/// Uygulama açılışında / Aile Koçu girişinde: Hive + (mobilde) alarm yeniden planla.
Future<void> bootstrapAileKocuReminders() async {
  try {
    await initAileKocuHive();
  } catch (e, st) {
    debugPrint('AileKoçu Hive init: $e\n$st');
    return;
  }
  // Bildirimler yalnızca mobil
  if (kIsWeb) return;
  try {
    await AileKocuNotificationService.instance.init();
    await AileKocuNotificationService.instance.refreshExactAlarmMode();
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
    for (final l in lessonsBox.values) {
      await AileKocuNotificationService.instance.rescheduleLesson(
        lessonId: l.id,
        childName: s.childName,
        title: l.name,
        timeHhmm: l.time,
        weekdays: l.days,
        photoPath: s.photoPath,
      );
    }
  } catch (e, st) {
    debugPrint('AileKoçu hatırlatıcı bootstrap: $e\n$st');
  }
}

/// Daha Fazlası’ndan açılır: Hive init + tıbbi uyarı (1 kez) + hub.
Future<void> openAileKocu(BuildContext context) async {
  try {
    await initAileKocuHive();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Aile Koçum açılamadı: $e')),
      );
    }
    return;
  }
  // Mobilde alarmları yenile (web’de no-op)
  unawaited(bootstrapAileKocuReminders());

  final settings = loadSettings();
  if (!settings.disclaimerAccepted && context.mounted) {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Önemli Bilgilendirme'),
        content: const Text(
          'Bu uygulama tıbbi tavsiye değildir. Lütfen doktorunuza danışın.\n\n'
          'Aile Koçum verileri yalnızca bu cihazda saklanır; buluta gönderilmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    settings.disclaimerAccepted = true;
    await saveSettings(settings);
  }

  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const AileKocuHubPage()),
  );
}
