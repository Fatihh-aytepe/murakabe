import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/local/local_storage.dart';
import 'notification_service.dart';

/// Kullanıcının seçebileceği alarm sesleri.
/// [id]   → assets/sounds/ içindeki dosya adı (uzantısız) — Android raw resource
/// [label] → UI'da gösterilecek isim
class AlarmSound {
  final String id;
  final String label;
  const AlarmSound({required this.id, required this.label});
}

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Kullanılabilir alarm sesleri ──────────────────────────────────────────
  // Dosyalar android/app/src/main/res/raw/ klasörüne kopyalanmalı (küçük harf, rakam, _ kabul edilir)
  static const List<AlarmSound> availableSounds = [
    AlarmSound(id: 'alarm_fajr', label: 'Mehter Marşı'),
    AlarmSound(id: 'alarm_ney', label: 'Karadeniz'),
    AlarmSound(id: 'alarm_kuran', label: 'Namaz uykudan daha hayırlıdır'),
    AlarmSound(id: 'alarm_sala', label: 'Zikir'),
    AlarmSound(id: 'alarm_tesbih', label: 'Ezan'),
    AlarmSound(id: 'alarm_soft', label: 'Pala'),
    AlarmSound(id: 'alarm_default', label: 'Ramiz dayı'),
  ];

  static const AlarmSound defaultSound =
      AlarmSound(id: 'alarm_default', label: 'Varsayılan');

  // ── Seçili ses — LocalStorage'dan okunur / yazılır ───────────────────────
  AlarmSound get selectedSound {
    final saved = LocalStorage().alarmSoundId;
    if (saved == null || saved.isEmpty) return defaultSound;
    return availableSounds.firstWhere(
      (s) => s.id == saved,
      orElse: () => defaultSound,
    );
  }

  Future<void> setSelectedSound(AlarmSound sound) =>
      LocalStorage().setAlarmSoundId(sound.id);

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
    await NotificationService().requestExactAlarmPermission();
  }

  // ── Teheccüd alarmı ───────────────────────────────────────────────────────
  Future<void> setTahajjudAlarm(DateTime alarmTime) async {
    if (alarmTime.isBefore(DateTime.now())) {
      alarmTime = alarmTime.add(const Duration(days: 1));
    }

    final scheduled = tz.TZDateTime.from(alarmTime, tz.local);
    final id = 500 + alarmTime.hour * 60 + alarmTime.minute;
    final sound = selectedSound;

    await _plugin.zonedSchedule(
      id,
      'Teheccüd Vakti 🌙',
      'Gece namazı vakti geldi. Rabbine seccadeyi ser...',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          // Her ses için ayrı kanal — Android kanalı değişince ses güncellenir
          'tahajjud_${sound.id}',
          'Teheccüd — ${sound.label}',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          enableVibration: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound.id),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.alarmClock,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    await LocalStorage().setTahajjudAlarmDate(
        DateTime.now().toIso8601String().substring(0, 10));
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

  // ── İptal ─────────────────────────────────────────────────────────────────
  Future<void> cancelAlarm(int id) async {
    await _plugin.cancel(id);
  }

  Future<void> cancelAllAlarms() async {
    // Teheccüd alarm ID aralığı: 500–1499
    for (int i = 500; i < 1500; i++) {
      await _plugin.cancel(i);
    }
  }

  // ── Ses kanallarını oluştur (uygulama başlangıcında çağır) ───────────────
  // Android kanalları bir kez oluşturulunca ses ayarı güncellenemez.
  // Bu yüzden kanal sürümünü SharedPreferences'ta tutuyoruz; değişince sil+yeniden oluştur.
  static const int _channelVersion = 2;

  Future<void> createSoundChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    final savedVersion = LocalStorage().alarmChannelVersion;
    if (savedVersion >= _channelVersion) return;

    // Eski kanalları sil (ses güncellenmesi için zorunlu)
    for (final sound in availableSounds) {
      try {
        await androidPlugin.deleteNotificationChannel('tahajjud_${sound.id}');
      } catch (_) {}
    }

    for (final sound in availableSounds) {
      await androidPlugin.createNotificationChannel(
        AndroidNotificationChannel(
          'tahajjud_${sound.id}',
          'Teheccüd — ${sound.label}',
          description: 'Teheccüd alarmı (${sound.label})',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound(sound.id),
        ),
      );
    }
    await LocalStorage().setAlarmChannelVersion(_channelVersion);
  }
}
