import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/local/local_storage.dart';

/// Kullanıcının seçebileceği alarm sesleri.
/// Dahili (hazır) sesler için [id] → assets/sounds/ + android res/raw
/// içindeki dosya adı (uzantısız). Kullanıcının yüklediği özel sesler için
/// [contentUri] dolu olur — bu, native tarafta MediaStore'a eklenmiş
/// dosyanın sistem çapında okunabilir content:// URI'sidir; [id] o zaman
/// sadece seçim/kanal anahtarı olarak kullanılan benzersiz bir string'dir.
class AlarmSound {
  final String id;
  final String label;
  final String? contentUri;
  const AlarmSound({required this.id, required this.label, this.contentUri});

  bool get isCustom => contentUri != null;
}

/// Kullanıcının cihazından ses dosyası seçmesi/silmesi sırasında oluşan,
/// kullanıcıya doğrudan gösterilebilecek Türkçe hatalar.
class AlarmSoundException implements Exception {
  final String message;
  AlarmSoundException(this.message);
  @override
  String toString() => message;
}

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Kullanılabilir alarm sesleri ──────────────────────────────────────────
  // Dosyalar android/app/src/main/res/raw/ klasörüne kopyalanmalı (küçük harf, rakam, _ kabul edilir)
  // Tüm sesler Pixabay İçerik Lisansı'yla alınmış, kesilip düzenlenmiş
  // kayıtlardır — kaynaklar ve lisans bağlantıları: ses_lisanslari.md
  static const List<AlarmSound> availableSounds = [
    AlarmSound(id: 'alarm_default', label: 'Sabah Kuşları'),
    AlarmSound(id: 'alarm_klasik', label: 'Klasik Türk'),
    AlarmSound(id: 'alarm_ney', label: 'Ney'),
    AlarmSound(id: 'alarm_ud', label: 'Ud'),
    AlarmSound(id: 'alarm_kanun', label: 'Ud ve Kanun'),
    AlarmSound(id: 'alarm_anadolu', label: 'Anadolu'),
    AlarmSound(id: 'alarm_darbuka', label: 'Ney ve Darbuka'),
    AlarmSound(id: 'alarm_zil', label: 'Klasik Zil'),
    AlarmSound(id: 'alarm_dijital', label: 'Dijital Alarm'),
  ];

  static const AlarmSound defaultSound =
      AlarmSound(id: 'alarm_default', label: 'Sabah Kuşları');

  /// Telif nedeniyle kaldırılan eski hazır seslerin kimlikleri. Bu sesleri
  /// seçmiş kullanıcılar varsayılana taşınır; daha önce kurulmuş alarmlar
  /// sessiz kalmasın diye bu kimliklerin bildirim kanalları varsayılan sesle
  /// yeniden oluşturulur (bkz. createSoundChannels).
  static const List<String> _legacySoundIds = [
    'alarm_fajr',
    'alarm_kuran',
    'alarm_sala',
    'alarm_tesbih',
    'alarm_soft',
  ];

  static const _audioChannel = MethodChannel('com.murakabe.app/audio');

  // ── Kullanıcının yüklediği özel sesler ────────────────────────────────────
  List<AlarmSound> get customSounds => LocalStorage()
      .customAlarmSounds
      .map((m) => AlarmSound(
            id: m['id']!,
            label: m['label']!,
            contentUri: m['contentUri'],
          ))
      .toList();

  /// Hazır + kullanıcının yüklediği tüm sesler (seçim ekranında gösterilir).
  List<AlarmSound> get allSounds => [...availableSounds, ...customSounds];

  // ── Seçili ses — LocalStorage'dan okunur / yazılır ───────────────────────
  AlarmSound get selectedSound {
    final saved = LocalStorage().alarmSoundId;
    if (saved == null || saved.isEmpty) return defaultSound;
    return allSounds.firstWhere(
      (s) => s.id == saved,
      orElse: () => defaultSound,
    );
  }

  Future<void> setSelectedSound(AlarmSound sound) =>
      LocalStorage().setAlarmSoundId(sound.id);

  // ── Kullanıcının kendi ses dosyasını yüklemesi ────────────────────────────
  // Native taraf (MainActivity.kt) sistem dosya seçiciyi açar, seçilen sesi
  // MediaStore'a IS_NOTIFICATION=1 ile ekler (Android 10+ scoped storage —
  // ekstra depolama izni gerekmez) ve bize content:// URI'sini döner. Bu URI
  // hem uygulama içi önizlemede hem de bildirim kanalının sesi olarak
  // doğrudan kullanılabilir.
  Future<AlarmSound?> pickAndAddCustomSound() async {
    Map<Object?, Object?>? raw;
    try {
      raw = await _audioChannel.invokeMethod<Map<Object?, Object?>>(
        'pickAndSaveAudio',
      );
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'TOO_LARGE':
          throw AlarmSoundException(
              'Ses dosyası çok büyük (en fazla 8 MB olabilir).');
        case 'UNSUPPORTED_VERSION':
          throw AlarmSoundException(
              'Bu Android sürümünde özel ses ekleme desteklenmiyor (Android 10+ gerekir).');
        default:
          throw AlarmSoundException('Ses dosyası eklenemedi.');
      }
    }
    if (raw == null) return null; // Kullanıcı seçiciyi iptal etti.

    final uri = raw['uri'] as String;
    final rawName = (raw['name'] as String?) ?? 'Özel Ses';
    final label =
        rawName.contains('.') ? rawName.substring(0, rawName.lastIndexOf('.')) : rawName;

    final sound = AlarmSound(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      label: label.isEmpty ? 'Özel Ses' : label,
      contentUri: uri,
    );

    final updated = [
      ...LocalStorage().customAlarmSounds,
      {'id': sound.id, 'label': sound.label, 'contentUri': uri},
    ];
    await LocalStorage().setCustomAlarmSounds(updated);
    await _createChannelForSound(sound);
    return sound;
  }

  /// Bir özel sesi hem MediaStore'dan hem de kayıtlı listeden siler.
  /// Silinen ses o an seçiliyse otomatik olarak varsayılana döner.
  Future<void> removeCustomSound(AlarmSound sound) async {
    if (!sound.isCustom) return;
    try {
      await _audioChannel
          .invokeMethod('deleteCustomAudio', {'uri': sound.contentUri});
    } catch (_) {
      // MediaStore kaydı zaten silinmiş/erişilemez olabilir — yine de
      // uygulama tarafındaki referansı temizlemeye devam ediyoruz.
    }

    final updated = LocalStorage()
        .customAlarmSounds
        .where((m) => m['id'] != sound.id)
        .toList();
    await LocalStorage().setCustomAlarmSounds(updated);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.deleteNotificationChannel('tahajjud_${sound.id}');

    if (LocalStorage().alarmSoundId == sound.id) {
      await setSelectedSound(defaultSound);
    }
  }

  // ── Uygulama içi önizleme (özel sesler için) ─────────────────────────────
  // Hazır sesler settings ekranında AssetSource ile (audioplayers) çalınmaya
  // devam ediyor; özel (content:// URI'li) sesler için native MediaPlayer
  // kullanıyoruz çünkü content:// URI oynatma desteği paket sürümüne göre
  // değişebiliyor — native tarafta garanti çalışan bir yol.
  Future<void> previewCustomSound(AlarmSound sound) async {
    if (!sound.isCustom) return;
    await _audioChannel
        .invokeMethod('previewAudio', {'uri': sound.contentUri});
  }

  Future<void> stopCustomPreview() async {
    await _audioChannel.invokeMethod('stopPreviewAudio');
  }

  // ── Ortak: bir AlarmSound'a karşılık gelen bildirim sesi + kanal ────────
  AndroidNotificationSound _androidSoundFor(AlarmSound sound) => sound.isCustom
      ? UriAndroidNotificationSound(sound.contentUri!)
      : RawResourceAndroidNotificationSound(sound.id);

  /// Kullanıcı yeni bir özel ses eklediğinde hemen çağrılır — o sesin
  /// teheccüd bildirim kanalını oluşturur (Android'de kanal oluşturulduktan
  /// sonra sesi değiştirilemez, bu yüzden her ses kendi kanalını kullanır).
  Future<void> _createChannelForSound(AlarmSound sound) async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;
    await androidPlugin.createNotificationChannel(
      AndroidNotificationChannel(
        'tahajjud_${sound.id}',
        'Teheccüd — ${sound.label}',
        description: 'Teheccüd alarmı (${sound.label})',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        sound: _androidSoundFor(sound),
      ),
    );
  }

  // ── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidInit),
    );
    // ÖNCEDEN burada NotificationService().requestExactAlarmPermission()
    // çağrılıyordu. AlarmService().init() main()'de, kullanıcı daha giriş/
    // kayıt ekranını bile görmeden UNKOŞULSUZ çalıştırılıyor (bkz.
    // main.dart) — bu da tam alarm izni diyaloğunun uygulama açılır
    // açılmaz, hiçbir gerekçe gösterilmeden çıkmasına neden oluyordu.
    // Bu, PermissionHelper'ın kendi belgelediği kuralla ("Hiçbir izin
    // uygulama açılışında topluca istenmez") doğrudan çelişiyordu. İzin artık
    // yalnızca PermissionHelper.requestAlarmReliabilityPermissions()
    // üzerinden, kayıt/girişten hemen sonra PermissionOnboardingScreen'de
    // gerekçesiyle birlikte isteniyor.
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
          sound: _androidSoundFor(sound),
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
  // 3: telifli sesler kaldırıldı, yeni 9 ses eklendi (Ekim 2026).
  static const int _channelVersion = 3;

  Future<void> createSoundChannels() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    final savedVersion = LocalStorage().alarmChannelVersion;
    if (savedVersion >= _channelVersion) return;

    // Eski kanalları sil (ses güncellenmesi için zorunlu)
    for (final id in [
      ...availableSounds.map((s) => s.id),
      ..._legacySoundIds,
    ]) {
      try {
        await androidPlugin.deleteNotificationChannel('tahajjud_$id');
      } catch (_) {}
    }

    // Kaldırılan bir sesi seçmiş kullanıcıyı varsayılana taşı.
    final savedId = LocalStorage().alarmSoundId;
    if (savedId != null && _legacySoundIds.contains(savedId)) {
      await setSelectedSound(defaultSound);
    }

    // Güncellemeden ÖNCE kurulmuş alarmlar eski kanal kimliğiyle
    // planlanmış durumda. O kanallar varsayılan sesle yeniden oluşturulur
    // ki alarm çaldığında sessiz kalmasın.
    for (final id in _legacySoundIds) {
      try {
        await androidPlugin.createNotificationChannel(
          AndroidNotificationChannel(
            'tahajjud_$id',
            'Teheccüd — ${defaultSound.label}',
            description: 'Teheccüd alarmı (önceki sürümden kalan alarmlar)',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            sound: RawResourceAndroidNotificationSound(defaultSound.id),
          ),
        );
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
