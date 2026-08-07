import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'child_photo.dart';

/// Aile Koçu — tamamen yerel bildirimler (FCM yok).
/// Sessiz saatler: 22:00–08:00 (o aralıkta planlananlar 08:00'e kaydırılır).
class AileKocuNotificationService {
  AileKocuNotificationService._();
  static final AileKocuNotificationService instance =
      AileKocuNotificationService._();

  static const _channelId = 'aile_kocu_channel';
  static const _channelName = 'Aile Koçum';
  static const _medChannelId = 'aile_kocu_med';
  static const _horizonDays = 21;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  AndroidScheduleMode _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;

  /// Bildirim aksiyonları: lessons|done|id , med|taken|id|time , ...
  void Function(String payload)? onAction;

  bool get isSupported => !kIsWeb;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (r) {
        final p = r.payload ?? r.actionId ?? '';
        if (p.isNotEmpty) onAction?.call(p);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    // Android 12+: tam saatli alarm (USE_EXACT_ALARM değil — Play politikası)
    try {
      final canExact = await androidPlugin?.canScheduleExactNotifications();
      if (canExact == false) {
        await androidPlugin?.requestExactAlarmsPermission();
      }
      final ok = await androidPlugin?.canScheduleExactNotifications();
      _scheduleMode = (ok == true)
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Ders ve not hatırlatmaları',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _medChannelId,
        'İlaç hatırlatmaları',
        description: 'İlaç saatleri',
        importance: Importance.max,
        playSound: true,
      ),
    );
    _ready = true;
  }

  /// Wall-clock saati Istanbul/local TZ’ye bağlar (DateTime.from kayması olmasın).
  tz.TZDateTime _wallClock(DateTime localWall) {
    return tz.TZDateTime(
      tz.local,
      localWall.year,
      localWall.month,
      localWall.day,
      localWall.hour,
      localWall.minute,
      localWall.second,
    );
  }

  /// 22:00–08:00 arasını atlayıp 08:00'e kaydırır.
  tz.TZDateTime respectQuietHours(tz.TZDateTime when) {
    final h = when.hour;
    if (h >= 22) {
      return tz.TZDateTime(
        when.location,
        when.year,
        when.month,
        when.day + 1,
        8,
      );
    }
    if (h < 8) {
      return tz.TZDateTime(
        when.location,
        when.year,
        when.month,
        when.day,
        8,
      );
    }
    return when;
  }

  int _lessonNotifId(String lessonId, int dayOffset) =>
      Object.hash('lesson', lessonId, dayOffset) & 0x7fffffff;

  int _medNotifId(String medicineId, String time, int dayOffset) =>
      Object.hash('med', medicineId, time, dayOffset) & 0x7fffffff;

  int _noteNotifId(String noteId) =>
      Object.hash('note', noteId) & 0x7fffffff;

  Future<AndroidBitmap<Object>?> _largeIcon(String photoPath) async {
    if (kIsWeb) return null;
    final bytes = childPhotoBytes(photoPath);
    if (bytes != null && bytes.isNotEmpty) {
      return ByteArrayAndroidBitmap(bytes);
    }
    if (photoPath.isEmpty || photoPath.startsWith('data:')) return null;
    try {
      final f = File(photoPath);
      if (await f.exists()) return FilePathAndroidBitmap(photoPath);
    } catch (_) {}
    if (bytes != null) {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/ak_notif_icon.jpg');
      await f.writeAsBytes(bytes);
      return FilePathAndroidBitmap(f.path);
    }
    return null;
  }

  Future<void> showLessonNotification({
    required String childName,
    required String title,
    required String time,
    required String photoPath,
    required DateTime scheduledAt,
    required int notificationId,
    required String payloadLessonId,
  }) async {
    if (!_ready || kIsWeb) return;
    var when = _wallClock(scheduledAt);
    when = respectQuietHours(when);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;

    final icon = await _largeIcon(photoPath);
    try {
      await _plugin.zonedSchedule(
        id: notificationId,
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Ders hatırlatmaları',
            importance: Importance.high,
            priority: Priority.high,
            largeIcon: icon,
            styleInformation: BigTextStyleInformation(
              '$time · $title',
              contentTitle: '$childName · Ders hatırlatma',
              summaryText: '2 saat kaldı',
            ),
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction('lesson_done', 'YAPILDI'),
              AndroidNotificationAction('lesson_snooze', '1 SAAT ERTELE'),
              AndroidNotificationAction('lesson_cancel', 'BUGÜN İPTAL'),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            presentBadge: true,
          ),
        ),
        androidScheduleMode: _scheduleMode,
        payload: 'lesson|$payloadLessonId|$title|$time',
        title: '$childName · Ders',
        body: '$time — $title (2 saat kaldı)',
      );
    } catch (e, st) {
      debugPrint('AileKoçu ders bildirimi planlanamadı: $e\n$st');
    }
  }

  Future<void> showMedicineNotification({
    required String childName,
    required String title,
    required String dosage,
    required String time,
    required String photoPath,
    required DateTime scheduledAt,
    required int notificationId,
    required String medicineId,
  }) async {
    if (!_ready || kIsWeb) return;
    var when = _wallClock(scheduledAt);
    when = respectQuietHours(when);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;

    final icon = await _largeIcon(photoPath);
    try {
      await _plugin.zonedSchedule(
        id: notificationId,
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _medChannelId,
            'İlaç hatırlatmaları',
            channelDescription: 'İlaç saatleri',
            importance: Importance.max,
            priority: Priority.high,
            largeIcon: icon,
            category: AndroidNotificationCategory.reminder,
            styleInformation: BigTextStyleInformation(
              '$dosage · $time',
              contentTitle: '$childName · İlaç zamanı',
              summaryText: title,
            ),
            actions: const <AndroidNotificationAction>[
              AndroidNotificationAction('med_taken', 'İÇTİM'),
              AndroidNotificationAction('med_snooze', '1 SAAT ERTELE'),
              AndroidNotificationAction('med_skip', 'BUGÜN ATLA'),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: _scheduleMode,
        payload: 'med|$medicineId|$title|$time|$dosage',
        title: '$childName · İlaç',
        body: '$time — $title ($dosage)',
      );
    } catch (e, st) {
      debugPrint('AileKoçu ilaç bildirimi planlanamadı: $e\n$st');
    }
  }

  Future<void> showPersonalNoteNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String noteId,
  }) async {
    if (!_ready || kIsWeb) return;
    final id = _noteNotifId(noteId);
    var when = _wallClock(scheduledTime);
    when = respectQuietHours(when);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;

    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Kişisel not hatırlatmaları',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: _scheduleMode,
        payload: 'pnote|$noteId',
        title: title,
        body: body,
      );
    } catch (e, st) {
      debugPrint('AileKoçu not bildirimi planlanamadı: $e\n$st');
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(id: id);

  Future<void> cancelLesson(String lessonId) async {
    for (var add = 0; add < _horizonDays; add++) {
      await cancel(_lessonNotifId(lessonId, add));
    }
  }

  Future<void> cancelMedicine(String medicineId, {List<String>? times}) async {
    final tlist = times ?? const <String>[''];
    for (final t in tlist) {
      for (var add = 0; add < _horizonDays; add++) {
        await cancel(_medNotifId(medicineId, t, add));
      }
    }
  }

  Future<void> cancelPersonalNote(String noteId) =>
      cancel(_noteNotifId(noteId));

  /// Ders: bugünden itibaren önümüzdeki günler için 2 saat önce planla.
  Future<void> rescheduleLesson({
    required String lessonId,
    required String childName,
    required String title,
    required String timeHhmm,
    required List<int> weekdays,
    required String photoPath,
  }) async {
    if (!_ready && !kIsWeb) await init();
    if (!_ready || kIsWeb) return;
    await cancelLesson(lessonId);
    final parts = timeHhmm.split(':');
    if (parts.length < 2) return;
    final hh = int.tryParse(parts[0]) ?? 0;
    final mm = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    for (var add = 0; add < _horizonDays; add++) {
      final day = DateTime(now.year, now.month, now.day)
          .add(Duration(days: add));
      if (weekdays.isNotEmpty && !weekdays.contains(day.weekday)) continue;
      final lessonAt = DateTime(day.year, day.month, day.day, hh, mm);
      final notifyAt = lessonAt.subtract(const Duration(hours: 2));
      if (!notifyAt.isAfter(now)) continue;
      await showLessonNotification(
        childName: childName,
        title: title,
        time: timeHhmm,
        photoPath: photoPath,
        scheduledAt: notifyAt,
        notificationId: _lessonNotifId(lessonId, add),
        payloadLessonId: lessonId,
      );
    }
  }

  Future<void> rescheduleMedicine({
    required String medicineId,
    required String childName,
    required String title,
    required String dosage,
    required List<String> times,
    required List<int> weekdays,
    required String photoPath,
    DateTime? endDate,
  }) async {
    if (!_ready && !kIsWeb) await init();
    if (!_ready || kIsWeb) return;
    await cancelMedicine(medicineId, times: times);
    final now = DateTime.now();
    final everyDay = weekdays.isEmpty;
    for (var add = 0; add < _horizonDays; add++) {
      final day = DateTime(now.year, now.month, now.day)
          .add(Duration(days: add));
      if (endDate != null) {
        final end = DateTime(endDate.year, endDate.month, endDate.day);
        if (day.isAfter(end)) break;
      }
      if (!everyDay && !weekdays.contains(day.weekday)) continue;
      for (final t in times) {
        final parts = t.split(':');
        if (parts.length < 2) continue;
        final hh = int.tryParse(parts[0]) ?? 0;
        final mm = int.tryParse(parts[1]) ?? 0;
        final at = DateTime(day.year, day.month, day.day, hh, mm);
        if (!at.isAfter(now)) continue;
        await showMedicineNotification(
          childName: childName,
          title: title,
          dosage: dosage,
          time: t,
          photoPath: photoPath,
          scheduledAt: at,
          notificationId: _medNotifId(medicineId, t, add),
          medicineId: medicineId,
        );
      }
    }
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint(
    'AileKoçu background action: ${response.actionId} ${response.payload}',
  );
}
