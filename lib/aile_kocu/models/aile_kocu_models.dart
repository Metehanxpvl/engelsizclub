import 'package:hive/hive.dart';

/// Hive typeIds: 41–44 (çakışmasın diye yüksek aralık)

class Lesson {
  Lesson({
    required this.id,
    required this.name,
    required this.days,
    required this.time,
    this.location = '',
    this.note = '',
    this.doneDates = const {},
  });

  String id;
  String name;
  /// 1=Pzt … 7=Paz (DateTime.weekday)
  List<int> days;
  /// "HH:mm"
  String time;
  String location;
  String note;
  /// 'yyyy-MM-dd' -> true
  Map<String, bool> doneDates;
}

class LessonAdapter extends TypeAdapter<Lesson> {
  @override
  final int typeId = 41;

  @override
  Lesson read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < n; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Lesson(
      id: fields[0] as String,
      name: fields[1] as String,
      days: (fields[2] as List).cast<int>(),
      time: fields[3] as String,
      location: (fields[4] as String?) ?? '',
      note: (fields[5] as String?) ?? '',
      doneDates: Map<String, bool>.from(
        (fields[6] as Map?)?.map((k, v) => MapEntry('$k', v == true)) ?? {},
      ),
    );
  }

  @override
  void write(BinaryWriter writer, Lesson obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.days)
      ..writeByte(3)
      ..write(obj.time)
      ..writeByte(4)
      ..write(obj.location)
      ..writeByte(5)
      ..write(obj.note)
      ..writeByte(6)
      ..write(obj.doneDates);
  }
}

class Medicine {
  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.times,
    required this.days,
    this.endDate,
    this.takenDatesMap = const {},
  });

  String id;
  String name;
  String dosage;
  List<String> times; // HH:mm
  List<int> days; // weekday 1-7, empty = every day
  DateTime? endDate;
  /// key: 'yyyy-MM-dd|HH:mm' -> true
  Map<String, bool> takenDatesMap;
}

class MedicineAdapter extends TypeAdapter<Medicine> {
  @override
  final int typeId = 42;

  @override
  Medicine read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < n; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Medicine(
      id: fields[0] as String,
      name: fields[1] as String,
      dosage: fields[2] as String,
      times: (fields[3] as List).cast<String>(),
      days: (fields[4] as List).cast<int>(),
      endDate: fields[5] as DateTime?,
      takenDatesMap: Map<String, bool>.from(
        (fields[6] as Map?)?.map((k, v) => MapEntry('$k', v == true)) ?? {},
      ),
    );
  }

  @override
  void write(BinaryWriter writer, Medicine obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dosage)
      ..writeByte(3)
      ..write(obj.times)
      ..writeByte(4)
      ..write(obj.days)
      ..writeByte(5)
      ..write(obj.endDate)
      ..writeByte(6)
      ..write(obj.takenDatesMap);
  }
}

class ChildNote {
  ChildNote({
    required this.id,
    required this.date,
    required this.title,
    required this.detail,
    this.imagePath,
    this.isImportant = false,
  });

  String id;
  DateTime date;
  String title;
  String detail;
  String? imagePath;
  bool isImportant;
}

class ChildNoteAdapter extends TypeAdapter<ChildNote> {
  @override
  final int typeId = 43;

  @override
  ChildNote read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < n; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ChildNote(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      title: fields[2] as String,
      detail: fields[3] as String,
      imagePath: fields[4] as String?,
      isImportant: (fields[5] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, ChildNote obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.detail)
      ..writeByte(4)
      ..write(obj.imagePath)
      ..writeByte(5)
      ..write(obj.isImportant);
  }
}

class PersonalNote {
  PersonalNote({
    required this.id,
    required this.title,
    required this.detail,
    this.reminderDateTime,
    this.tag = 'Not',
  });

  String id;
  String title;
  String detail;
  DateTime? reminderDateTime;
  /// Acil | Market | Aranacak | Not
  String tag;
}

class PersonalNoteAdapter extends TypeAdapter<PersonalNote> {
  @override
  final int typeId = 44;

  @override
  PersonalNote read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < n; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return PersonalNote(
      id: fields[0] as String,
      title: fields[1] as String,
      detail: fields[2] as String,
      reminderDateTime: fields[3] as DateTime?,
      tag: (fields[4] as String?) ?? 'Not',
    );
  }

  @override
  void write(BinaryWriter writer, PersonalNote obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.detail)
      ..writeByte(3)
      ..write(obj.reminderDateTime)
      ..writeByte(4)
      ..write(obj.tag);
  }
}

class AileKocuSettings {
  AileKocuSettings({
    this.childName = 'Çocuk',
    this.photoPath = '',
    this.disclaimerAccepted = false,
  });

  String childName;
  String photoPath;
  bool disclaimerAccepted;
}

class AileKocuSettingsAdapter extends TypeAdapter<AileKocuSettings> {
  @override
  final int typeId = 45;

  @override
  AileKocuSettings read(BinaryReader reader) {
    final n = reader.readByte();
    final fields = <int, dynamic>{};
    for (var i = 0; i < n; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AileKocuSettings(
      childName: (fields[0] as String?) ?? 'Çocuk',
      photoPath: (fields[1] as String?) ?? '',
      disclaimerAccepted: (fields[2] as bool?) ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, AileKocuSettings obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.childName)
      ..writeByte(1)
      ..write(obj.photoPath)
      ..writeByte(2)
      ..write(obj.disclaimerAccepted);
  }
}
