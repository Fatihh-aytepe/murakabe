import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';

/// İzin isteklerini tek bir yerden, gerekçesiyle birlikte ve *doğru anda*
/// yönetir. Play Store politikası + kullanıcı deneyimi için kural:
/// bir sistem izin diyaloğu, kullanıcının ne için istendiğini anlayacağı
/// bir gerekçe ekranından SONRA ve sadece o izin gerçekten lazım olduğunda
/// gösterilir. Hiçbir izin uygulama açılışında topluca istenmez.
class PermissionHelper {
  /// Bildirim izni (Android 13+ / POST_NOTIFICATIONS).
  /// Namaz vakti hatırlatmaları, zikir ve günlük içerik bildirimleri için.
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Hatırlatıcı kurmadan HEMEN ÖNCE çağrılır. Bildirim izni varsa true.
  /// Yoksa önce sistem izin diyaloğunu açar; kullanıcı yine izin vermezse
  /// (ya da daha önce kalıcı reddettiyse) "Ayarları Aç" seçenekli bir
  /// pencere gösterip false döner.
  ///
  /// NEDEN: Bildirim izni önceden yalnızca ilk girişteki tanıtım ekranında
  /// BİR KEZ soruluyordu. Orada "Atla" denirse ya da izin reddedilirse bir
  /// daha hiç sorulmuyor, hatırlatıcı "kuruldu" görünüyor ama Android 13+
  /// üzerinde bildirim hiç gösterilmiyordu.
  static Future<bool> ensureNotificationPermissionForReminder(
      BuildContext context) async {
    var status = await Permission.notification.status;
    if (status.isGranted) return true;
    if (!status.isPermanentlyDenied) {
      status = await Permission.notification.request();
      if (status.isGranted) return true;
    }
    if (!context.mounted) return false;
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Bildirim izni kapalı'),
        content: const Text(
            'Hatırlatıcının sana ulaşabilmesi için Murakabe\'nin bildirim '
            'göndermesine izin vermen gerekiyor. Ayarlardan bildirimleri '
            'açıp tekrar deneyebilirsin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Vazgeç'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Ayarları Aç'),
          ),
        ],
      ),
    );
    if (openSettings == true) await openAppSettings();
    return false;
  }

  /// Namaz vakti alarmlarının tam zamanında çalması için Android 12+
  /// "tam zamanlı alarm" izni + pil optimizasyonu istisnası.
  /// Bildirim izniyle birlikte, aynı gerekçe ekranının parçası olarak istenir.
  static Future<void> requestAlarmReliabilityPermissions() async {
    final canSchedule =
        await NotificationService().checkExactAlarmPermission();
    if (!canSchedule) {
      await NotificationService().requestExactAlarmPermission();
    }
    // Pil optimizasyonu istisnası (REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
    // KALDIRILDI: Google Play bu izni yalnızca çok dar kullanım
    // durumlarında kabul ediyor; reddedilme riski. Tam zamanlı alarm izni
    // bildirimlerin zamanında gelmesi için yeterli.
  }

  /// Konum izni — SADECE ön planda (whileInUse). Arka plan konum izni
  /// (ACCESS_BACKGROUND_LOCATION) bilinçli olarak istenmiyor: uygulama
  /// namaz vakitlerini yalnızca uygulama açıkken hesaplıyor, kullanıcı
  /// takip edilmiyor. Play Console "Hassas izinler" beyanında bu nedenle
  /// arka plan konum kullanımı beyan edilmemelidir.
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;
    final result = await Permission.locationWhenInUse.request();
    return result.isGranted;
  }

  /// Kamera izni — YALNIZCA kullanıcı "Kameradan çek" seçeneğine dokunduğunda
  /// çağrılmalı (bkz. profile_setup_screen.dart / profile_screen.dart).
  /// image_picker zaten bunu gerektiğinde otomatik istiyor; bu metod sadece
  /// önceden bir gerekçe göstermek isteyen ekranlar için yardımcıdır.
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    final result = await Permission.camera.request();
    return result.isGranted;
  }

}
