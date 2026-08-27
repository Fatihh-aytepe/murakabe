import 'package:crypto/crypto.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  // İndirilecek APK için makul bir üst sınır — bozuk/olması gerekenden çok
  // büyük bir yanıtı belleğe tamamen okumadan önce reddeder.
  static const int _maxApkBytes = 300 * 1024 * 1024; // 300 MB

  Future<UpdateInfo> checkForUpdate() async {
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
        'apk_url': '',
        'force_update': false,
        // Opsiyonel: APK'nın SHA-256 özeti (hex, büyük/küçük harf önemsiz).
        // Boş bırakılırsa doğrulama atlanır (geriye dönük uyumluluk) —
        // yayın sürecine (CI yok, elle yükleme) bir doğrulama adımı
        // eklemek isteyen geliştirici bu alanı Remote Config konsolundan
        // doldurabilir. Bkz. README.md "Güncelleme" bölümü.
        'apk_sha256': '',
      });
      await remoteConfig.fetchAndActivate();

      final latestVersion = remoteConfig.getString('latest_version');
      final apkUrl = remoteConfig.getString('apk_url');
      final forceUpdate = remoteConfig.getBool('force_update');
      final apkSha256 = remoteConfig.getString('apk_sha256').trim();

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
        apkUrl: apkUrl,
        forceUpdate: forceUpdate,
        apkSha256: apkSha256,
      );
    } catch (e, st) {
      debugPrint('[UpdateService] ERROR: $e\n$st');
      return const UpdateInfo(
        hasUpdate: false,
        latestVersion: '',
        currentVersion: '',
        apkUrl: '',
        forceUpdate: false,
        apkSha256: '',
      );
    }
  }

  /// [info.apkSha256] boşsa (geliştirici Remote Config'e özet girmemişse)
  /// doğrulama atlanır ve `true` döner — mevcut davranışla tam uyumlu.
  /// Doluysa, APK indirilip SHA-256'sı hesaplanır ve karşılaştırılır.
  /// İndirilen dosya kurulum için KULLANILMAZ (kurulum hâlâ tarayıcı +
  /// Android paket yükleyicisi üzerinden yapılıyor); bu yalnızca "linkteki
  /// dosya beklenenle aynı mı" sorusuna kullanıcı kurmadan önce yanıt verir.
  Future<ApkVerifyResult> verifyApk(UpdateInfo info) async {
    if (info.apkSha256.isEmpty) return ApkVerifyResult.skipped;
    if (info.apkUrl.isEmpty) return ApkVerifyResult.mismatch;

    try {
      final uri = Uri.parse(info.apkUrl);
      // HEAD ile boyutu önceden kontrol etmeyi dene — bazı sunucular HEAD'i
      // desteklemeyebilir, o durumda sessizce GET'e geçilir.
      try {
        final head = await http.head(uri).timeout(const Duration(seconds: 15));
        final len = int.tryParse(head.headers['content-length'] ?? '');
        if (len != null && len > _maxApkBytes) {
          debugPrint('[UpdateService] APK çok büyük (HEAD): $len bayt');
          return ApkVerifyResult.mismatch;
        }
      } catch (_) {}

      final response =
          await http.get(uri).timeout(const Duration(minutes: 3));
      if (response.statusCode != 200) {
        debugPrint('[UpdateService] APK indirilemedi: ${response.statusCode}');
        return ApkVerifyResult.error;
      }
      if (response.bodyBytes.length > _maxApkBytes) {
        debugPrint(
            '[UpdateService] APK çok büyük: ${response.bodyBytes.length} bayt');
        return ApkVerifyResult.mismatch;
      }

      final digest = sha256.convert(response.bodyBytes).toString();
      final matches = digest.toLowerCase() == info.apkSha256.toLowerCase();
      return matches ? ApkVerifyResult.match : ApkVerifyResult.mismatch;
    } catch (e) {
      debugPrint('[UpdateService] verifyApk hatası: $e');
      return ApkVerifyResult.error;
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

enum ApkVerifyResult {
  /// Remote Config'te özet girilmemiş — doğrulama yapılmadı, devam edilebilir.
  skipped,

  /// İndirilen dosyanın özeti beklenenle eşleşti.
  match,

  /// İndirilen dosyanın özeti beklenenle EŞLEŞMEDİ — kuruluma devam edilmemeli.
  mismatch,

  /// Ağ/zaman aşımı gibi bir nedenle doğrulama tamamlanamadı.
  error,
}

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String currentVersion;
  final String apkUrl;
  final bool forceUpdate;
  final String apkSha256;

  const UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    required this.apkUrl,
    required this.forceUpdate,
    this.apkSha256 = '',
  });
}
