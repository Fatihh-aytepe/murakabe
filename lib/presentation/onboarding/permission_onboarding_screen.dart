import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/permission_helper.dart';
import '../../data/local/local_storage.dart';

/// Kayıt/giriş sonrası TEK SEFERLİK gösterilen izin tanıtım ekranı.
///
/// Play Store'un beklediği akış: bir sistem izin diyaloğu çıkmadan önce,
/// kullanıcının o izni neden istediğimizi anlayacağı sade bir açıklama
/// gösterilir ("gerekçeli izin" / contextual permission priming).
/// Bu ekran iki adımdan oluşur: Bildirim → Konum. Her adımda kullanıcı
/// "İzin Ver" veya "Şimdi Değil" seçebilir; hiçbiri zorunlu değildir ve
/// uygulama izin verilmese de kullanılabilir.
class PermissionOnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const PermissionOnboardingScreen({super.key, required this.onDone});

  @override
  State<PermissionOnboardingScreen> createState() =>
      _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState
    extends State<PermissionOnboardingScreen> {
  int _step = 0;
  bool _isBusy = false;

  static const _steps = [
    _PermissionStepData(
      icon: Icons.notifications_active_outlined,
      title: 'Bildirimlere İzin Ver',
      description:
          'Namaz vakti hatırlatmaları, günlük zikir çağrısı ve seçtiğin '
          'esmâ/âyet/hadis içeriklerini zamanında alabilmen için bildirim '
          'iznine ihtiyacımız var. İstersen daha sonra Ayarlar\'dan '
          'kapatabilirsin.',
    ),
    _PermissionStepData(
      icon: Icons.location_on_outlined,
      title: 'Konumuna İzin Ver',
      description:
          'Bulunduğun yere göre doğru namaz vakitlerini ve kıble yönünü '
          'hesaplayabilmemiz için konum iznine ihtiyacımız var. Konumun '
          'sadece uygulama açıkken kullanılır; arka planda takip edilmez '
          've hiçbir yere gönderilmez.',
    ),
  ];

  Future<void> _handleAllow() async {
    setState(() => _isBusy = true);
    try {
      if (_step == 0) {
        await PermissionHelper.requestNotificationPermission();
        await PermissionHelper.requestAlarmReliabilityPermissions();
      } else {
        await PermissionHelper.requestLocationPermission();
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
    _advance();
  }

  void _handleSkip() => _advance();

  void _advance() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await LocalStorage().setPermissionOnboardingDone();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final data = _steps[_step];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Row(
                  children: List.generate(_steps.length, (i) {
                    final active = i <= _step;
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                            right: i == _steps.length - 1 ? 0 : 6),
                        height: 4,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                FadeIn(
                  key: ValueKey(_step),
                  duration: const Duration(milliseconds: 400),
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: 0.12),
                          border:
                              Border.all(color: AppColors.gold, width: 1.5),
                        ),
                        child: Icon(data.icon, color: AppColors.gold, size: 42),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        data.description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isBusy ? null : _handleAllow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isBusy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2),
                          )
                        : Text('İzin Ver',
                            style: GoogleFonts.notoSans(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isBusy ? null : _handleSkip,
                  child: Text(
                    'Şimdi Değil',
                    style:
                        GoogleFonts.notoSans(color: Colors.white38, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionStepData {
  final IconData icon;
  final String title;
  final String description;
  const _PermissionStepData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
