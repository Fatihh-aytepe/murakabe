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
import 'core/services/connectivity_service.dart';
import 'core/services/theme_service.dart';
import 'data/local/local_storage.dart';
import 'presentation/splash/splash_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await LocalStorage().init();
  await NotificationService().init();
  await AlarmService().init();
  await AlarmService().createSoundChannels();
  await ConnectivityService().init();
  await ThemeService().init();

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
