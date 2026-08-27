import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/constants/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/alarm_service.dart';
import 'core/services/background_refresh_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/theme_service.dart';
import 'data/local/local_storage.dart';
import 'presentation/splash/splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

/// DÜZELTME: Önceden bu servisler `main()` içinde düz `await` ile ard arda
/// bekleniyordu — herhangi biri (ör. bir eklentinin native tarafı belirli
/// bir cihaz/OEM'de hata fırlatırsa) BAŞARISIZ olduğunda, atılan hata
/// yakalanmadığı için `runApp()` çağrısına HİÇ ULAŞILAMIYORDU: uygulama
/// beyaz/siyah ekranda donmuş kalıyor, kullanıcı hiçbir şey yapamıyordu.
/// Bu yardımcı, her adımı ayrı ayrı try/catch içine alıp hatayı sadece
/// loglayarak bir SONRAKİ adıma geçilmesini sağlıyor — sıralama (ör.
/// LocalStorage'ın Firebase'den, diğerlerinin LocalStorage'dan önce
/// gelmesi) korunuyor, ama tek bir servisin çökmesi ARTIK uygulamanın hiç
/// açılamamasına yol açmıyor; o servisin özelliği (ör. bildirimler)
/// çalışmayabilir ama geri kalan her şeyle birlikte uygulama render olur.
Future<void> _safeInit(String label, Future<void> Function() step) async {
  try {
    await step();
  } catch (e, st) {
    debugPrint('[main] $label başlatılamadı, devam ediliyor: $e\n$st');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _safeInit(
    'initializeDateFormatting',
    () => initializeDateFormatting('tr_TR', null),
  );

  await _safeInit(
    'Firebase.initializeApp',
    () => Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
  );
  await _safeInit('LocalStorage.init', () => LocalStorage().init());
  await _safeInit('NotificationService.init', () => NotificationService().init());
  await _safeInit('AlarmService.init', () => AlarmService().init());
  await _safeInit(
    'AlarmService.createSoundChannels',
    () => AlarmService().createSoundChannels(),
  );
  await _safeInit('ConnectivityService.init', () => ConnectivityService().init());
  await _safeInit('ThemeService.init', () => ThemeService().init());
  // Ana ekran widget'larının namaz vakti/zikir/günlük içerik verisini
  // uygulama kapalıyken de tazelemesi için — bkz. background_refresh_service.dart.
  await _safeInit(
    'BackgroundRefreshService.initializeAndSchedule',
    () => BackgroundRefreshService.initializeAndSchedule(),
  );

  // NOT: Bildirim/konum/kamera/galeri izinleri artık burada TOPLU
  // istenmiyor. Play Store politikası ve kullanıcı deneyimi gereği her
  // izin, gerekçesiyle birlikte tam ihtiyaç duyulduğu anda isteniyor:
  // bildirim + konum → kayıt/girişten hemen sonra PermissionOnboardingScreen
  // (bkz. presentation/onboarding/permission_onboarding_screen.dart),
  // kamera/galeri → kullanıcı profil fotoğrafı eklemeyi seçtiğinde
  // (bkz. presentation/profile/profile_setup_screen.dart).

  runApp(
    ChangeNotifierProvider.value(
      value: ThemeService(),
      child: const MurakabeApp(),
    ),
  );
}

class MurakabeApp extends StatelessWidget {
  const MurakabeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    return ConnectivityBanner(
      child: MaterialApp(
        title: 'Murakabe',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeService.isDark ? ThemeMode.dark : ThemeMode.light,
        debugShowCheckedModeBanner: false,
        // NOT: flutter_quill'in araç çubuğu/editörü çalışması için
        // FlutterQuillLocalizations.delegate şart — eksik olduğunda
        // "FlutterQuillLocalizations instance is required and could not
        // found" hatası konsolu dolduruyordu. flutter_localizations paketi
        // pubspec'te zaten vardı ama hiç bağlanmamıştı.
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('tr'),
          Locale('en'),
        ],
        locale: const Locale('tr'),
        home: const SplashScreen(),
      ),
    );
  }
}
