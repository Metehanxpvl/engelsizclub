import 'package:hive_flutter/hive_flutter.dart';

import 'models/aile_kocu_models.dart';

const kBoxLessons = 'ak_lessons';
const kBoxMedicines = 'ak_medicines';
const kBoxChildNotes = 'ak_child_notes';
const kBoxPersonalNotes = 'ak_personal_notes';
const kBoxSettings = 'ak_settings';

bool _hiveReady = false;

Future<void> initAileKocuHive() async {
  if (_hiveReady) return;
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(41)) Hive.registerAdapter(LessonAdapter());
  if (!Hive.isAdapterRegistered(42)) Hive.registerAdapter(MedicineAdapter());
  if (!Hive.isAdapterRegistered(43)) Hive.registerAdapter(ChildNoteAdapter());
  if (!Hive.isAdapterRegistered(44)) {
    Hive.registerAdapter(PersonalNoteAdapter());
  }
  if (!Hive.isAdapterRegistered(45)) {
    Hive.registerAdapter(AileKocuSettingsAdapter());
  }
  await Future.wait([
    Hive.openBox<Lesson>(kBoxLessons),
    Hive.openBox<Medicine>(kBoxMedicines),
    Hive.openBox<ChildNote>(kBoxChildNotes),
    Hive.openBox<PersonalNote>(kBoxPersonalNotes),
    Hive.openBox<AileKocuSettings>(kBoxSettings),
  ]);
  _hiveReady = true;
}

Box<Lesson> get lessonsBox => Hive.box<Lesson>(kBoxLessons);
Box<Medicine> get medicinesBox => Hive.box<Medicine>(kBoxMedicines);
Box<ChildNote> get childNotesBox => Hive.box<ChildNote>(kBoxChildNotes);
Box<PersonalNote> get personalNotesBox =>
    Hive.box<PersonalNote>(kBoxPersonalNotes);
Box<AileKocuSettings> get settingsBox =>
    Hive.box<AileKocuSettings>(kBoxSettings);

AileKocuSettings loadSettings() {
  final box = settingsBox;
  if (box.isEmpty) {
    final s = AileKocuSettings();
    box.put('main', s);
    return s;
  }
  return box.get('main') ?? AileKocuSettings();
}

Future<void> saveSettings(AileKocuSettings s) async {
  await settingsBox.put('main', s);
}

String dayLabel(int weekday) {
  const names = {
    1: 'PAZARTESİ',
    2: 'SALI',
    3: 'ÇARŞAMBA',
    4: 'PERŞEMBE',
    5: 'CUMA',
    6: 'CUMARTESİ',
    7: 'PAZAR',
  };
  return names[weekday] ?? '$weekday';
}

String todayKey([DateTime? d]) {
  final x = d ?? DateTime.now();
  final m = x.month.toString().padLeft(2, '0');
  final day = x.day.toString().padLeft(2, '0');
  return '${x.year}-$m-$day';
}

/// Bu haftanın [weekday] gününün tarihi (1=Pzt … 7=Paz).
DateTime dateOfWeekdayThisWeek(int weekday) {
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  return monday.add(Duration(days: weekday - 1));
}

/// Örn: Emre'nin Haftası · Emre'nin İlaçları
String childPageTitle(String suffix) {
  final name = loadSettings().childName.trim();
  final n = name.isEmpty ? 'Çocuk' : name;
  return "$n'nin $suffix";
}
