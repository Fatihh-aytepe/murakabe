import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../constants/app_strings.dart';
import '../../data/local/local_storage.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/models/esma_model.dart';
import '../../data/models/hadis_model.dart';
import '../../data/models/ayet_model.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int esmaNotifId = 1;
  static const int hadisNotifId = 2;
  static const int ayetNotifId = 3;
  static const int quranNotifId = 4;
  static const int tahajjudNotifId = 5;
  static const int weeklyNotifId = 6;
  static const int remindLaterEsmaId = 11;
  static const int remindLaterHadisId = 12;
  static const int remindLaterAyetId = 13;
  static const int streakWarningId = 99;

  Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationTapped,
    );

    await _createNotificationChannels();
  }

  Future<void> _createNotificationChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'esma_channel',
        'Esmaül Hüsna',
        description: 'Günlük esma bildirimleri',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'hadis_channel',
        'Hadis',
        description: 'Günlük hadis bildirimleri',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'ayet_channel',
        'Ayet',
        description: 'Günlük ayet bildirimleri',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'quran_channel',
        'Kuran Hatırlatma',
        description: 'Kuran okuma hatırlatıcısı',
        importance: Importance.max,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'tahajjud_channel',
        'Teheccüd',
        description: 'Teheccüd namazı hatırlatıcısı',
        importance: Importance.max,
        enableVibration: true,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'streak_channel',
        'Seri Uyarısı',
        description: 'Seri kaybetme uyarısı',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'reminder_channel',
        'Hatırlatıcılar',
        description: 'Kullanıcı hatırlatıcıları',
        importance: Importance.high,
      ),
    );
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'community_channel',
        'Topluluk Bildirimleri',
        description: 'Topluluk katılım ve admin başvuru bildirimleri',
        importance: Importance.high,
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {}

  Future<void> scheduleDailyNotifications() => _rescheduleAllDailyContent();

  // ── Per-type cancel helpers ───────────────────────────────────────────────
  Future<void> cancelEsmaNotification() => _cancelDailyContentType(1);
  Future<void> cancelHadisNotification() => _cancelDailyContentType(2);
  Future<void> cancelAyetNotification() => _cancelDailyContentType(3);
  Future<void> cancelKuranNotification() async {
    await cancelNotification(quranNotifId);
    await cancelHourlyQuranReminders();
  }

  // ── Generic reschedule (settings toggle-on; home screen replaces on next load) ──
  Future<void> rescheduleEsmaNotification() => _rescheduleAllDailyContent();
  Future<void> rescheduleHadisNotification() => _rescheduleAllDailyContent();
  Future<void> rescheduleAyetNotification() => _rescheduleAllDailyContent();
  Future<void> rescheduleKuranNotification() => _scheduleQuranNotification();

  Future<void> _rescheduleAllDailyContent() async {
    final repo = ContentRepository();
    final esmas = await repo.getEsmas();
    final hadises = await repo.getHadises();
    final ayets = await repo.getAyets();
    await schedule30DaysNotifications(
      esmas: esmas,
      hadises: hadises,
      ayets: ayets,
    );
    if (LocalStorage().kuranNotifEnabled) await _scheduleQuranNotification();
  }

  // ── 30 günlük deterministik günlük içerik planlaması ─────────────────────
  // Sabit ID aralığı: 10000–13653. Mevcut sabit ID'lerle (1-6, 11-13, 99,
  // 200-204, quranNotifId+10/+20.., tahajjudNotifId+10 vb.) hiçbir kesişme yok.
  // matchDateTimeComponents KASITLI OLARAK kullanılmıyor: OS seviyesinde
  // "aynı içeriği her gün tekrarla" davranışı, eski donma hatasının kaynağıydı.
  // Bunun yerine her takvim günü kendi içeriğiyle, ayrı bir ID ile, tek
  // seferlik olarak planlanıyor.
  static const int _dailyContentIdBase = 10000;
  static const int _scheduleWindowDays = 30;
  static const int _cancelWindowPadding = 40;

  int _dayOfYear(DateTime date) =>
      date.difference(DateTime(date.year, 1, 1)).inDays;

  /// Bugünden itibaren [_scheduleWindowDays] gün için Esma/Hadis/Ayet
  /// bildirimlerini takvim tarihine göre deterministik olarak kurar.
  Future<void> schedule30DaysNotifications({
    required List<EsmaModel> esmas,
    required List<HadisModel> hadises,
    required List<AyetModel> ayets,
  }) async {
    final storage = LocalStorage();
    await _cancelDailyContentIds();

    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);

    for (int offset = 0; offset < _scheduleWindowDays; offset++) {
      final date = base.add(Duration(days: offset));
      final doy = _dayOfYear(date);
      final id = _dailyContentIdBase + doy * 10;

      if (storage.esmaNotifEnabled && esmas.isNotEmpty) {
        final esma = esmas[doy % esmas.length];
        await _scheduleOne(
          id: id + 1,
          when: tz.TZDateTime(tz.local, date.year, date.month, date.day, 9, 0),
          title: esma.arabic,
          body: esma.meaning,
          channelId: 'esma_channel',
          channelName: 'Esmaül Hüsna',
          bigText: esma.meaning,
        );
      }

      if (storage.hadisNotifEnabled && hadises.isNotEmpty) {
        final hadis = hadises[doy % hadises.length];
        final shortText = hadis.text.length > 100
            ? '${hadis.text.substring(0, 100)}...'
            : hadis.text;
        await _scheduleOne(
          id: id + 2,
          when: tz.TZDateTime(tz.local, date.year, date.month, date.day, 13, 0),
          title: 'Günün Hadisi',
          body: shortText,
          channelId: 'hadis_channel',
          channelName: 'Hadis',
          bigText: hadis.text,
          subText: hadis.source,
        );
      }

      if (storage.ayetNotifEnabled && ayets.isNotEmpty) {
        final ayet = ayets[doy % ayets.length];
        final shortText = ayet.turkish.length > 100
            ? '${ayet.turkish.substring(0, 100)}...'
            : ayet.turkish;
        await _scheduleOne(
          id: id + 3,
          when: tz.TZDateTime(tz.local, date.year, date.month, date.day, 18, 0),
          title: 'Günün Ayeti — ${ayet.surah}',
          body: shortText,
          channelId: 'ayet_channel',
          channelName: 'Ayet',
          bigText: ayet.turkish,
        );
      }
    }
  }

  Future<void> _scheduleOne({
    required int id,
    required tz.TZDateTime when,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String bigText,
    String? subText,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    if (!when.isAfter(now)) return; // geçmiş saate kurma
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(bigText),
          subText: subText,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _cancelDailyContentIds() async {
    final today = DateTime.now();
    for (int offset = -_cancelWindowPadding;
        offset < _scheduleWindowDays + _cancelWindowPadding;
        offset++) {
      final date = DateTime(today.year, today.month, today.day)
          .add(Duration(days: offset));
      final id = _dailyContentIdBase + _dayOfYear(date) * 10;
      await _plugin.cancel(id + 1);
      await _plugin.cancel(id + 2);
      await _plugin.cancel(id + 3);
    }
  }

  Future<void> _cancelDailyContentType(int typeOffset) async {
    final today = DateTime.now();
    for (int offset = -_cancelWindowPadding;
        offset < _scheduleWindowDays + _cancelWindowPadding;
        offset++) {
      final date = DateTime(today.year, today.month, today.day)
          .add(Duration(days: offset));
      final id = _dailyContentIdBase + _dayOfYear(date) * 10 + typeOffset;
      await _plugin.cancel(id);
    }
  }

  Future<void> _scheduleQuranNotification() async {
    final scheduled = _nextTime(19, 0);
    await _plugin.zonedSchedule(
      quranNotifId,
      AppStrings.quranReminder,
      AppStrings.quranReminderBody,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quran_channel',
          'Kuran Hatırlatma',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> scheduleRemindLater(
    String type,
    String title,
    String body,
  ) async {
    final scheduled = tz.TZDateTime.now(tz.local).add(const Duration(hours: 3));
    int id = type == 'esma'
        ? remindLaterEsmaId
        : type == 'hadis'
            ? remindLaterHadisId
            : remindLaterAyetId;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          '${type}_channel',
          type == 'esma'
              ? 'Esmaül Hüsna'
              : type == 'hadis'
                  ? 'Hadis'
                  : 'Ayet',
          importance: Importance.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleQuranRemindLater() async {
    final scheduled = tz.TZDateTime.now(tz.local).add(const Duration(hours: 1));
    await _plugin.zonedSchedule(
      quranNotifId + 10,
      AppStrings.quranReminder,
      AppStrings.quranReminderBody,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quran_channel',
          'Kuran Hatırlatma',
          importance: Importance.max,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleTahajjudNotification(DateTime alarmTime) async {
    final scheduled = tz.TZDateTime.from(alarmTime, tz.local);
    await _plugin.zonedSchedule(
      tahajjudNotifId,
      AppStrings.tahajjudTitle,
      AppStrings.tahajjudBody,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tahajjud_channel',
          'Teheccüd',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> scheduleThursdayTahajjud() async {
    final now = tz.TZDateTime.now(tz.local);
    var thursday = now;
    while (thursday.weekday != DateTime.thursday) {
      thursday = thursday.add(const Duration(days: 1));
    }
    final scheduled = tz.TZDateTime(
      tz.local,
      thursday.year,
      thursday.month,
      thursday.day,
      2,
      0,
    );
    await _plugin.zonedSchedule(
      tahajjudNotifId + 10,
      'Teheccüd Vakti',
      'Gece namazı vakti. Bu gecenin bereketinden mahrum kalma...',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tahajjud_channel',
          'Teheccüd',
          importance: Importance.max,
          fullScreenIntent: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> scheduleWeeklyFridaySummary() async {
    final now = tz.TZDateTime.now(tz.local);
    var friday = now;
    while (friday.weekday != DateTime.friday) {
      friday = friday.add(const Duration(days: 1));
    }
    final scheduled = tz.TZDateTime(
      tz.local,
      friday.year,
      friday.month,
      friday.day,
      10,
      0,
    );
    await _plugin.zonedSchedule(
      weeklyNotifId,
      'Haftalık Özet',
      'Bu haftaki kaydettiklerinizi görmek için dokunun.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'esma_channel',
          'Esmaül Hüsna',
          importance: Importance.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> scheduleCustomReminder(
    int id,
    String title,
    String body,
    DateTime time,
  ) async {
    final scheduled = tz.TZDateTime.from(time, tz.local);
    if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Hatırlatıcılar',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Günlük tekrarlayan görev bildirimi (her gün aynı saatte)
  Future<void> scheduleTaskNotification(
    int id,
    String title,
    String body,
    int hour,
    int minute,
  ) async {
    final scheduled = _nextTime(hour, minute);
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Hatırlatıcılar',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelTaskNotification(int id) => _plugin.cancel(id);

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  // Android 12+ exact alarm izni kontrolü
  Future<bool> checkExactAlarmPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarmPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  // Yardımcı: bir sonraki saat:dakika zamanı hesapla
  tz.TZDateTime _nextTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  // Kuran okumadıysa saat 19-23 arası saat başı hatırlatma
  Future<void> scheduleHourlyQuranReminders(bool alreadyRead) async {
    // Önceki saatlik hatırlatmaları temizle
    for (int i = 0; i < 5; i++) {
      await _plugin.cancel(quranNotifId + 20 + i);
    }
    if (alreadyRead) return;

    final now = tz.TZDateTime.now(tz.local);
    int slot = 0;
    for (int hour = 20; hour <= 23; hour++) {
      var scheduled =
          tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, 0);
      if (scheduled.isBefore(now)) continue;
      await _plugin.zonedSchedule(
        quranNotifId + 20 + slot,
        'Kuran Hatırlatıcı',
        'Bugün henüz Kuran okumadınız. Birkaç sayfa bile olsa okuyun.',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'quran_channel',
            'Kuran Hatırlatma',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      slot++;
    }
  }

  Future<void> cancelHourlyQuranReminders() async {
    for (int i = 0; i < 5; i++) {
      await _plugin.cancel(quranNotifId + 20 + i);
    }
  }

  // Tamamlanmamış görev hatırlatmaları — 09:00, 12:00, 15:00, 18:00, 21:00 (ID 200–204)
  Future<void> schedulePendingTaskReminders() async {
    final times = [
      [9, 0],
      [12, 0],
      [15, 0],
      [18, 0],
      [21, 0]
    ];
    for (var i = 0; i < times.length; i++) {
      await scheduleTaskNotification(
        200 + i,
        'Topluluk Görevleri',
        'Tamamlanmamış görevleriniz var. Kontrol etmeyi unutmayın.',
        times[i][0],
        times[i][1],
      );
    }
  }

  Future<void> cancelPendingTaskReminders() async {
    for (var i = 0; i < 5; i++) {
      await _plugin.cancel(200 + i);
    }
  }

  Future<void> cancelNotification(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}

@pragma('vm:entry-point')
void _onBackgroundNotificationTapped(NotificationResponse response) {}
