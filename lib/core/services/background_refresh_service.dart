import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../../data/local/local_storage.dart';
import 'widget_bridge_service.dart';

/// Ana ekran widget'larının (namaz vakitleri, zikir, günlük içerik) verisini
/// uygulama HİÇ açılmasa bile arka planda tazeler.
///
/// NEDEN: [WidgetBridgeService.refreshAll] eskiden sadece uygulama açılıp
/// HomeScreen görüntülendiğinde çağrılıyordu — kullanıcı günlerce uygulamayı
/// açmazsa namaz vakitleri widget'ları eski (yanlış) günün verisini göstermeye
/// devam ediyordu. Bunu çözmek için burada, Android'in resmi arka plan görev
/// mekanizması olan WorkManager (workmanager paketi üzerinden) kullanılıyor —
/// pil tasarrufu/Doze kısıtlamalarını ÇİĞNEMEDEN, sistemin uygun gördüğü
/// zamanlarda periyodik olarak çalışır. Native tarafta namaz vakti
/// hesaplamasını YENİDEN YAZMAK yerine (yanlış hesaplama riski taşır),
/// mevcut ve doğruluğu zaten kanıtlanmış Dart tarafındaki
/// [WidgetBridgeService]/`GetPrayerTimes` mantığı olduğu gibi tekrar
/// kullanılıyor.
///
/// Yalnızca ANDROID'de etkinleştirilir — iOS'ta arka plan görev
/// zamanlayıcısının (BGTaskScheduler) çalışması için ayrıca AppDelegate/
/// Info.plist tarafında ek native kurulum gerekir ve bu istek özellikle
/// "Android'in pil tasarrufu kurallarını çiğnemeden" ifadesiyle Android'e
/// özgüdür; kapsam dışı bir platforma yarım/test edilmemiş bir entegrasyon
/// eklemekten kaçınıldı.
class BackgroundRefreshService {
  static const _uniqueTaskName = 'murakabe.widgetDataRefresh';
  static const _taskName = 'widgetDataRefreshTask';

  /// Uygulama açılışında (main.dart) bir kez çağrılır. WorkManager'ı
  /// başlatır ve periyodik görevi kaydeder.
  ///
  /// [ExistingPeriodicWorkPolicy.keep] kullanılıyor: görev zaten
  /// kayıtlıysa (uygulama daha önce açılmış ve kaydetmişse) mevcut
  /// zamanlamasını SIFIRLAMAZ — her uygulama açılışında periyodu yeniden
  /// başlatmak, görevin pratikte hiç çalışmadan sürekli ertelenmesine yol
  /// açabilirdi.
  static Future<void> initializeAndSchedule() async {
    if (!Platform.isAndroid) return;
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _uniqueTaskName,
        _taskName,
        // Android'de periyodik görevler için sistemin izin verdiği en kısa
        // aralık 15 dakikadır; biz bunun ÇOK üzerinde, günde birkaç kez
        // yeterli olacak bir değer seçiyoruz — pil tüketimini gereksiz
        // yere artırmamak için (namaz vakitleri günde bir kez, içerik/zikir
        // hedefi de günde bir kez değişiyor; 3 saat, gün değişiminin en
        // geç birkaç saat içinde yakalanmasını sağlıyor).
        frequency: const Duration(hours: 3),
        initialDelay: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(
          // Konum ve yerel veriden çalışır, ağ ZORUNLU değil — gereksiz
          // yere "sadece internet varken çalış" kısıtı koyup görevi
          // ertelenmeye maruz bırakmıyoruz.
          networkType: NetworkType.notRequired,
        ),
      );
    } catch (_) {
      // WorkManager bazı cihazlarda (özellikle OEM pil optimizasyonu
      // saldırgan cihazlar) kayıt sırasında hata verebilir — sessizce yut,
      // uygulamanın açılışını asla engellemesin. Widget'lar bu durumda da
      // en azından uygulama her açıldığında (HomeScreen) tazelenmeye devam
      // eder.
    }
  }
}

/// WorkManager'ın çağırdığı giriş noktası — AYRI bir Dart izole (isolate)
/// içinde çalışır, bu yüzden ana uygulamadaki hiçbir static/singleton
/// durumu (LocalStorage._prefs dahil) buraya taşınmaz; her şey bu izolede
/// SIFIRDAN kurulmalıdır.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await LocalStorage().init();
      // Firebase'e KASITLI OLARAK dokunulmuyor: WidgetBridgeService.refreshAll
      // içindeki namaz vakti (adhan paketi + geolocator), zikir ve günlük
      // içerik (esmâ/âyet/hadis, cihazdaki assets/data JSON'larından) verisi
      // tamamen yerel/pakete gömülü kaynaklardan hesaplanıyor — Firebase'e
      // bağımlı DEĞİL, bu yüzden arka plan izolesinde Firebase.initializeApp
      // çağırmaya gerek yok.
      // isBackground: true — bu izolede görünür bir Activity yok, konum
      // izni "denied" ise sessizce son bilinen konuma düşülür; asla izin
      // diyaloğu tetiklenmeye ÇALIŞILMAZ (bkz. LocationService.
      // getCurrentPosition / WidgetBridgeService._refreshPrayer).
      await WidgetBridgeService().refreshAll(isBackground: true);
    } catch (_) {
      // Konum izni yok, GPS kapalı, vb. — widget'lar son bilinen veriyi
      // göstermeye devam eder; bir sonraki periyotta tekrar denenecek.
    }
    return Future.value(true);
  });
}
