import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

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
  static const _smallIcon = 'ic_stat_notify';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// İlaç: mümkünse alarmClock (ekran kapalı / Doze’da da tam saat).
  AndroidScheduleMode _medScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
  AndroidScheduleMode _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
  bool exactAlarmsAllowed = false;
  bool notificationsAllowed = true;

  /// Bildirim aksiyonları: lessons|done|id , med|taken|id|time , ...
  void Function(String payload)? onAction;

  bool get isSupported => !kIsWeb;
  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    var initialized = false;
    for (final icon in const [_smallIcon, 'ic_launcher']) {
      try {
        await _plugin.initialize(
          settings: InitializationSettings(
            android: AndroidInitializationSettings(icon),
            iOS: ios,
          ),
          onDidReceiveNotificationResponse: (r) {
            final p = r.payload ?? r.actionId ?? '';
            if (p.isNotEmpty) onAction?.call(p);
          },
          onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
        );
        initialized = true;
        break;
      } catch (e, st) {
        debugPrint('AileKoçu notify initialize ($icon): $e\n$st');
      }
    }
    if (!initialized) return;

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // runApp öncesi Activity yoksa bu çağrı Android'de patlar — yut, kanalı kur.
    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('AileKoçu POST_NOTIFICATIONS (init): $e');
    }

    await refreshExactAlarmMode(promptUser: false);

    try {
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Ders ve not hatırlatmaları',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _medChannelId,
          'İlaç hatırlatmaları',
          description: 'İlaç saatleri',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      );
    } catch (e) {
      debugPrint('AileKoçu kanal: $e');
    }

    await _refreshNotificationAllowed();
    _ready = true;
  }

  /// UI açıkken (Activity var) bildirim + isteğe bağlı tam saat izni.
  Future<void> ensurePermissions({bool promptExactAlarm = false}) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('AileKoçu POST_NOTIFICATIONS: $e');
    }
    await _refreshNotificationAllowed();
    await refreshExactAlarmMode(promptUser: promptExactAlarm);
  }

  Future<void> _refreshNotificationAllowed() async {
    if (kIsWeb) {
      notificationsAllowed = false;
      return;
    }
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      notificationsAllowed =
          await androidPlugin?.areNotificationsEnabled() ?? true;
    } catch (_) {
      notificationsAllowed = true;
    }
  }

  /// Exact alarm iznini yenile. [promptUser] yalnızca ayarlar butonundan true.
  Future<bool> refreshExactAlarmMode({bool promptUser = false}) async {
    if (kIsWeb) return false;
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      var ok = await androidPlugin?.canScheduleExactNotifications();
      if (ok == false && promptUser) {
        try {
          await androidPlugin?.requestExactAlarmsPermission();
        } catch (e) {
          debugPrint('AileKoçu exact alarm izni: $e');
        }
        ok = await androidPlugin?.canScheduleExactNotifications();
      }
      exactAlarmsAllowed = ok == true;
      if (exactAlarmsAllowed) {
        _medScheduleMode = AndroidScheduleMode.alarmClock;
        _scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      } else {
        _medScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    } catch (_) {
      exactAlarmsAllowed = false;
      _medScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      _scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }
    return exactAlarmsAllowed;
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

  /// Takvim günü + saat başına tek bildirim (aynı gün tekrarlanmaz).
  int _medNotifId(String medicineId, String time, DateTime day) =>
      Object.hash(
        'med',
        medicineId,
        time,
        day.year,
        day.month,
        day.day,
      ) &
      0x7fffffff;

  /// Eski sürüm: gün-ofset kimliği — temizlik için.
  int _medNotifIdLegacyOffset(String medicineId, String time, int dayOffset) =>
      Object.hash('med', medicineId, time, dayOffset) & 0x7fffffff;

  /// Eski sürüm: haftanın günü kimliği — çoklu bildirim hatası.
  int _medNotifIdLegacyWeekday(String medicineId, String time, int weekday) =>
      Object.hash('med', medicineId, time, 'wd', weekday) & 0x7fffffff;

  static bool _bootstrapRunning = false;
  final Set<String> _medicineRescheduleLocks = {};

  int _noteNotifId(String noteId) =>
      Object.hash('note', noteId) & 0x7fffffff;

  /// Bootstrap eşzamanlı çağrıları birleştirir.
  static bool get bootstrapRunning => _bootstrapRunning;
  static set bootstrapRunning(bool v) => _bootstrapRunning = v;

  /// Android AlarmManager extra’sına büyük fotoğraf koymak planlamayı düşürür.
  /// iOS’ta da ek gerekmez; başlık/gövde yeter.
  Future<void> _zonedSchedule({
    required int id,
    required tz.TZDateTime when,
    required AndroidNotificationDetails android,
    required DarwinNotificationDetails ios,
    required AndroidScheduleMode mode,
    required String payload,
    required String title,
    required String body,
  }) async {
    Future<void> go(AndroidScheduleMode m, {bool withIcon = true}) {
      return _plugin.zonedSchedule(
        id: id,
        scheduledDate: when,
        notificationDetails: NotificationDetails(
          android: withIcon
              ? android
              : AndroidNotificationDetails(
                  android.channelId,
                  android.channelName,
                  channelDescription: android.channelDescription,
                  importance: android.importance,
                  priority: android.priority,
                  playSound: true,
                  enableVibration: true,
                ),
          iOS: ios,
        ),
        androidScheduleMode: m,
        payload: payload,
        title: title,
        body: body,
      );
    }

    final modes = <AndroidScheduleMode>{
      mode,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    }.toList();
    for (final m in modes) {
      try {
        await go(m);
        return;
      } catch (e) {
        debugPrint('AileKoçu zonedSchedule ($m) id=$id: $e');
        // Önceki mod alarmı kurmuş olabilir — yedek denemeden önce iptal.
        await cancel(id);
      }
    }
    try {
      await go(AndroidScheduleMode.inexactAllowWhileIdle, withIcon: false);
    } catch (e) {
      debugPrint('AileKoçu zonedSchedule (no-icon) id=$id: $e');
    }
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

    await _zonedSchedule(
      id: notificationId,
      when: when,
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Ders hatırlatmaları',
        icon: _smallIcon,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
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
      ios: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      ),
      mode: _scheduleMode,
      payload: 'lesson|$payloadLessonId|$title|$time',
      title: '$childName · Ders',
      body: '$time — $title (2 saat kaldı)',
    );
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
    // İlaçta sessiz saat UYGULANMAZ — planlanan saatte düşmeli.
    final when = _wallClock(scheduledAt);
    if (!when.isAfter(tz.TZDateTime.now(tz.local))) return;

    // Aynı kimlikte eski/alternatif alarm kalmasın.
    await cancel(notificationId);

    await _zonedSchedule(
      id: notificationId,
      when: when,
      android: AndroidNotificationDetails(
        _medChannelId,
        'İlaç hatırlatmaları',
        channelDescription: 'İlaç saatleri',
        icon: _smallIcon,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
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
      ios: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      mode: _medScheduleMode,
      payload: 'med|$medicineId|$title|$time|$dosage',
      title: '$childName · İlaç',
      body: '$time — $title ($dosage)',
    );
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

    await _zonedSchedule(
      id: id,
      when: when,
      android: const AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Kişisel not hatırlatmaları',
        icon: _smallIcon,
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        category: AndroidNotificationCategory.reminder,
      ),
      ios: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
      mode: _scheduleMode,
      payload: 'pnote|$noteId',
      title: title,
      body: body,
    );
  }

  Future<int> pendingCount() async {
    if (kIsWeb || !_ready) return 0;
    try {
      final list = await _plugin.pendingNotificationRequests();
      return list.length;
    } catch (_) {
      return 0;
    }
  }

  /// Hemen bir deneme bildirimi (izin / kanal kontrolü).
  Future<bool> showTestNow() async {
    if (kIsWeb) return false;
    if (!_ready) await init();
    await ensurePermissions();
    if (!_ready || !notificationsAllowed) return false;
    try {
      await _plugin.show(
        id: 910001,
        title: 'Aile Koçum',
        body: 'Bildirimler açık. Hatırlatmalar bu kanaldan gelecek.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Ders ve not hatırlatmaları',
            icon: _smallIcon,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
          ),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('AileKoçu test bildirimi: $e');
      try {
        await _plugin.show(
          id: 910001,
          title: 'Aile Koçum',
          body: 'Bildirimler açık. Hatırlatmalar bu kanaldan gelecek.',
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(
              presentAlert: true,
              presentSound: true,
            ),
          ),
        );
        return true;
      } catch (e2) {
        debugPrint('AileKoçu test bildirimi (yedek): $e2');
        return false;
      }
    }
  }

  /// ~15 sn sonra deneme (AlarmManager / zamanlama).
  Future<bool> scheduleTestInSeconds([int seconds = 15]) async {
    if (kIsWeb) return false;
    if (!_ready) await init();
    await ensurePermissions();
    if (!notificationsAllowed) return false;
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    try {
      await _zonedSchedule(
        id: 910002,
        when: when,
        android: const AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Ders ve not hatırlatmaları',
          icon: _smallIcon,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        ios: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
        mode: exactAlarmsAllowed
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'test',
        title: 'Aile Koçum',
        body: 'Zamanlanmış hatırlatma çalışıyor.',
      );
      return true;
    } catch (e) {
      debugPrint('AileKoçu test zamanlama: $e');
      return false;
    }
  }

  Future<void> cancel(int id) async {
    if (kIsWeb || !_ready) return;
    try {
      await _plugin.cancel(id: id);
    } catch (e) {
      debugPrint('AileKoçu cancel($id): $e');
    }
  }

  Future<void> cancelLesson(String lessonId) async {
    if (kIsWeb || !_ready) return;
    await Future.wait([
      for (var add = 0; add < _horizonDays; add++)
        cancel(_lessonNotifId(lessonId, add)),
    ]);
  }

  Future<void> cancelMedicine(String medicineId, {List<String>? times}) async {
    if (kIsWeb || !_ready) return;

    // Payload ile eşleşen tüm bekleyen ilaç bildirimlerini iptal et.
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final p in pending) {
        final payload = p.payload ?? '';
        if (payload.startsWith('med|$medicineId|')) {
          await cancel(p.id);
        }
      }
    } catch (e) {
      debugPrint('AileKoçu cancelMedicine pending: $e');
    }

    final tlist = times ?? const <String>[];
    final now = DateTime.now();
    final cancelIds = <int>{};
    for (final t in tlist) {
      for (var add = 0; add < _horizonDays; add++) {
        final day = DateTime(now.year, now.month, now.day)
            .add(Duration(days: add));
        cancelIds.add(_medNotifId(medicineId, t, day));
        cancelIds.add(_medNotifIdLegacyOffset(medicineId, t, add));
        for (var wd = 1; wd <= 7; wd++) {
          cancelIds.add(_medNotifIdLegacyWeekday(medicineId, t, wd));
        }
      }
    }
    await Future.wait(cancelIds.map(cancel));
  }

  Future<void> cancelPersonalNote(String noteId) async {
    if (kIsWeb || !_ready) return;
    await cancel(_noteNotifId(noteId));
  }

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
      var notifyAt = lessonAt.subtract(const Duration(hours: 2));
      if (!notifyAt.isAfter(now)) {
        if (lessonAt.isAfter(now)) {
          notifyAt = lessonAt;
        } else {
          continue;
        }
      }
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
    if (times.isEmpty) return;

    if (_medicineRescheduleLocks.contains(medicineId)) return;
    _medicineRescheduleLocks.add(medicineId);
    try {
      await cancelMedicine(medicineId, times: times);
      final now = DateTime.now();
      final everyDay = weekdays.isEmpty;
      final scheduledKeys = <String>{};
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
          final dedupeKey =
              '${at.year}-${at.month}-${at.day}|$t|$medicineId';
          if (!scheduledKeys.add(dedupeKey)) continue;
          await showMedicineNotification(
            childName: childName,
            title: title,
            dosage: dosage,
            time: t,
            photoPath: photoPath,
            scheduledAt: at,
            notificationId: _medNotifId(medicineId, t, day),
            medicineId: medicineId,
          );
        }
      }
    } finally {
      _medicineRescheduleLocks.remove(medicineId);
    }
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint(
    'AileKoçu background action: ${response.actionId} ${response.payload}',
  );
}
