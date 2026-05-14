import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Android 13+ bildirim izni
  await _requestPermissions();

  runApp(
    ChangeNotifierProvider.value(
      value: ThemeService(),
      child: const MurakabeApp(),
    ),
  );
}

Future<void> _requestPermissions() async {
  // Bildirim izni (Android 13+)
  final notifStatus = await Permission.notification.status;
  if (notifStatus.isDenied) {
    await Permission.notification.request();
  }

  // Konum izni (namaz vakitleri için)
  final locationStatus = await Permission.location.status;
  if (locationStatus.isDenied) {
    await Permission.location.request();
  }

  // Tam ekranlı alarm izni (Android 12+)
  final canSchedule = await NotificationService().checkExactAlarmPermission();
  if (!canSchedule) {
    await NotificationService().requestExactAlarmPermission();
  }

  // Pil optimizasyonu — alarm için kritik (Xiaomi/Samsung/Huawei)
  final batteryStatus = await Permission.ignoreBatteryOptimizations.status;
  if (batteryStatus.isDenied) {
    await Permission.ignoreBatteryOptimizations.request();
  }
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
        home: const SplashScreen(),
      ),
    );
  }
}
