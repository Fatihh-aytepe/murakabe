import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Google Play politikası gereği uygulama KENDİNİ Play dışından güncellemez.
/// Bu servis yalnızca Remote Config'teki `latest_version` ile mevcut sürümü
/// karşılaştırır; "Güncelle" düğmesi Play Store sayfasını açar (bkz.
/// SplashScreen._showUpdateDialog). APK indirme/doğrulama kodu bu yüzden
/// tamamen kaldırıldı.
class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  Future<UpdateInfo> checkForUpdate() async {
    // İnternetsiz açılışı bekletmemek için tüm kontrol en fazla 5 sn sürer;
    // aşılırsa "güncelleme yok" kabul edilir, bir sonraki açılışta denenir.
    return _checkForUpdate().timeout(
      const Duration(seconds: 5),
      onTimeout: () => const UpdateInfo(
        hasUpdate: false,
        latestVersion: '',
        currentVersion: '',
        forceUpdate: false,
      ),
    );
  }

  Future<UpdateInfo> _checkForUpdate() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        // Debug modunda her açılışta Firebase'den taze veri çek;
        // release modunda 1 saatte bir yeter.
        minimumFetchInterval:
            kDebugMode ? Duration.zero : const Duration(hours: 1),
      ));
      await remoteConfig.setDefaults({
        'latest_version': '1.0.0',
      });
      await remoteConfig.fetchAndActivate();

      final latestVersion = remoteConfig.getString('latest_version');
      final forceUpdate = remoteConfig.getBool('force_update');

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final hasUpdate = _isNewer(latestVersion, currentVersion);

      debugPrint(
        '[UpdateService] current=$currentVersion latest=$latestVersion '
        'hasUpdate=$hasUpdate forceUpdate=$forceUpdate',
      );

      return UpdateInfo(
        hasUpdate: hasUpdate,
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        forceUpdate: forceUpdate,
      );
    } catch (e, st) {
      debugPrint('[UpdateService] ERROR: $e\n$st');
      return const UpdateInfo(
        hasUpdate: false,
        latestVersion: '',
        currentVersion: '',
        forceUpdate: false,
      );
    }
  }

  bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      for (int i = 0; i < l.length; i++) {
        if (i >= c.length) return true;
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String currentVersion;
  final bool forceUpdate;

  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    required this.forceUpdate,
  });
}
