import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// [requestIfDenied] false ise ve izin şu an "denied" durumdaysa hiç
  /// `requestPermission()` ÇAĞRILMAZ, doğrudan son bilinen konuma düşülür.
  /// BUNU ÖZELLİKLE arka plan (headless) çağrılar false geçmeli — ör.
  /// BackgroundRefreshService'in WorkManager izolesi: burada görünür bir
  /// Activity olmadığından sistem izin diyaloğu gösterilemez; buna rağmen
  /// çağrılırsa (a) diyalog sessizce başarısız olur/isteği yok sayar ya da
  /// (b) bazı OEM'lerde kullanıcıya hiç sorulmadan izni "denied" olarak
  /// işaretleyebilir — uygulamanın kendi ilkesiyle de çelişir: izinler
  /// SADECE kullanıcının gördüğü, gerekçeli bir ön plan akışından istenir
  /// (bkz. PermissionOnboardingScreen, AlarmService.init düzeltmesi).
  Future<Position?> getCurrentPosition({bool requestIfDenied = true}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _getLastKnown();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (!requestIfDenied) return _getLastKnown();
      try {
        permission = await Geolocator.requestPermission();
      } catch (_) {
        return _getLastKnown();
      }
      if (permission == LocationPermission.denied) return _getLastKnown();
    }
    if (permission == LocationPermission.deniedForever) return _getLastKnown();

    try {
      // forceAndroidLocationManager: Google Play Services (DEVELOPER_ERROR)
      // yerine native Android LocationManager kullanır
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
        forceAndroidLocationManager: true,
      );
    } catch (_) {
      return _getLastKnown();
    }
  }

  Future<Position?> _getLastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
