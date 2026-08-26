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

  /// Namaz vakti alarmlarının tam zamanında çalması için Android 12+
  /// "tam zamanlı alarm" izni + pil optimizasyonu istisnası.
  /// Bildirim izniyle birlikte, aynı gerekçe ekranının parçası olarak istenir.
  static Future<void> requestAlarmReliabilityPermissions() async {
    final canSchedule =
        await NotificationService().checkExactAlarmPermission();
    if (!canSchedule) {
      await NotificationService().requestExactAlarmPermission();
    }
    final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
    if (batteryStatus.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
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

  /// Galeri/foto izni — YALNIZCA kullanıcı "Galeriden seç" seçeneğine
  /// dokunduğunda. Android 13+ (Photo Picker) için genelde sistem düzeyinde
  /// izin gerekmez; image_picker bunu otomatik yönetir.
  static Future<bool> requestPhotosPermission() async {
    final status = await Permission.photos.status;
    if (status.isGranted) return true;
    final result = await Permission.photos.request();
    return result.isGranted;
  }
}
