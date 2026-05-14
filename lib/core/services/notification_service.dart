import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../constants/app_strings.dart';

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
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

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
  }

  void _onNotificationTapped(NotificationResponse response) {}

  Future<void> scheduleDailyNotifications({
    required String esmaArabic,
    required String esmaMeaning,
    required String hadisText,
    required String hadisSource,
    required String ayetTurkish,
    required String surahName,
  }) async {
    await _scheduleEsmaNotification(esmaArabic, esmaMeaning);
    await _scheduleHadisNotification(hadisText, hadisSource);
    await _scheduleAyetNotification(ayetTurkish, surahName);
    await _scheduleQuranNotification();
  }

  Future<void> _scheduleEsmaNotification(String arabic, String meaning) async {
    final scheduled = _nextTime(8, 0);
    await _plugin.zonedSchedule(
      esmaNotifId,
      arabic,
      meaning,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'esma_channel',
          'Esmaül Hüsna',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(meaning),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleHadisNotification(String text, String source) async {
    final scheduled = _nextTime(12, 0);
    await _plugin.zonedSchedule(
      hadisNotifId,
      'Günün Hadisi',
      text.length > 100 ? '${text.substring(0, 100)}...' : text,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'hadis_channel',
          'Hadis',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(text),
          subText: source,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleAyetNotification(String turkish, String surah) async {
    final scheduled = _nextTime(14, 0);
    await _plugin.zonedSchedule(
      ayetNotifId,
      'Günün Ayeti — $surah',
      turkish.length > 100 ? '${turkish.substring(0, 100)}...' : turkish,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'ayet_channel',
          'Ayet',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(turkish),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
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
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarmPermission() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
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
      var scheduled = tz.TZDateTime(
          tz.local, now.year, now.month, now.day, hour, 0);
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

  Future<void> cancelNotification(int id) => _plugin.cancel(id);
  Future<void> cancelAll() => _plugin.cancelAll();
}

@pragma('vm:entry-point')
void _onBackgroundNotificationTapped(NotificationResponse response) {}
