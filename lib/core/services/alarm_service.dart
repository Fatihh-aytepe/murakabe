import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/local/local_storage.dart';
import 'notification_service.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    // Android 12+ exact alarm izni kontrol et
    await NotificationService().requestExactAlarmPermission();
  }

  Future<void> setTahajjudAlarm(DateTime alarmTime) async {
    // Geçmiş zaman kontrolü
    if (alarmTime.isBefore(DateTime.now())) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }

    final scheduled = tz.TZDateTime.from(alarmTime, tz.local);
    final id = 500 + alarmTime.hour * 60 + alarmTime.minute;

    await _plugin.zonedSchedule(
      id,
      'Teheccüd Vakti 🌙',
      'Gece namazı vakti geldi. Rabbine seccadeyi ser...',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'tahajjud_channel',
          'Teheccüd',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          enableVibration: true,
          playSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> setWeeklyTahajjudAlarm() async {
    final now = DateTime.now();
    var thursday = now;
    while (thursday.weekday != DateTime.thursday) {
      thursday = thursday.add(const Duration(days: 1));
    }
    final alarmDt = DateTime(thursday.year, thursday.month, thursday.day, 2, 0);
    await setTahajjudAlarm(alarmDt);
  }

  Future<void> cancelAlarm(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAllAlarms() async {
    for (int i = 500; i < 1500; i++) {
      await _plugin.cancel(i);
    }
  }

  Future<void> saveTahajjudAlarmDate() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await LocalStorage().setTahajjudAlarmDate(today);
  }
}
