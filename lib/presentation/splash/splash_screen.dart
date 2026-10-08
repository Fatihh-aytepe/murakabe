import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/role_service.dart';
import '../../core/services/update_service.dart';
import '../../data/local/local_storage.dart';
import '../../data/remote/firebase_service.dart';
import '../../data/repositories/user_repository.dart';
import '../admin/admin_panel_screen.dart' show OwnerPanelScreen;
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  int _messageIndex = 0;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _startMessageCycle();
    _navigateAfterDelay();
  }

  void _startMessageCycle() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _messageIndex = (_messageIndex + 1) % AppStrings.splashMessages.length;
      });
      return true;
    });
  }

  Future<void> _navigateAfterDelay() async {
    // Güncelleme kontrolü splash animasyonuyla AYNI ANDA yapılır (önceden
    // 3 sn beklendikten SONRA başlıyordu). İnternet yoksa hiç denenmez —
    // uygulama internetsiz de bekletmeden açılmalı.
    final online = ConnectivityService().isConnected;
    final updateFuture = online
        ? UpdateService().checkForUpdate()
        : Future.value(const UpdateInfo(
            hasUpdate: false,
            latestVersion: '',
            currentVersion: '',
            forceUpdate: false,
          ));
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Güncelleme kontrolü
    final updateInfo = await updateFuture;
    if (!mounted) return;
    final skipped = LocalStorage().skippedVersion;
    // apk_url artık kullanılmıyor (bkz. _showUpdateDialog); yalnızca
    // Remote Config'teki latest_version'a bakılır.
    if (updateInfo.hasUpdate && skipped != updateInfo.latestVersion) {
      await _showUpdateDialog(updateInfo);
      if (!mounted) return;
      // forceUpdate ise güncelleme yapılana kadar uygulamayı ilerletme
      if (updateInfo.forceUpdate) return;
    }

    final storage = LocalStorage();

    // ── 1. Firebase Auth oturumu var mı? ──────────────────────────────────
    // Android'de uygulama silinince Auth tokeni de silinir → null gelir.
    // iOS'ta Keychain sayesinde yeniden yükleme sonrası da geçerli kalabilir.
    // Her iki durumda da storedId ile UID eşleşmiyorsa Firestore'dan geri yükle.
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser != null) {
      final storedId = storage.userId;
      // DÜZELTME: önceden yalnızca storedId != authUser.uid iken (yeni
      // cihaz/yeniden yükleme) restore yapılıyordu. UID AYNI olsa bile
      // yerel `users` tablosunda bu uid için satır YOKSA (ör. yarım kalmış
      // bir restore, bozulmuş/silinmiş SQLite dosyası, ya da bu oturumun
      // erken kısmında eklenen hesap-değiştirme "wipe" akışının ardından
      // bir şekilde yeniden aynı UID'ye dönülmüş olması) HomeScreen sessizce
      // boş/eksik bir profille açılıyordu. `needsRestore` bu iki durumu da
      // kapsayacak şekilde genişletildi.
      final hasLocalRow =
          storedId == authUser.uid && await UserRepository().getCurrentUser() != null;
      final needsRestore = storedId != authUser.uid || !hasLocalRow;
      if (needsRestore) {
        // Yeni cihaz / yeniden yükleme / eksik yerel satır — verileri
        // Firestore'dan çek
        await storage.setUserId(authUser.uid);
        await storage.setUserRegistered(true);
        await storage.setAuthMigrationDone();
        try {
          final restored = await UserRepository().restoreFromFirestore(authUser.uid);
          debugPrint('[Splash] Firestore restore sonucu: $restored');
          final prefs = await FirebaseService().getUserPrefs(authUser.uid);
          if (prefs != null) await storage.restoreFromMap(prefs);
        } catch (e) {
          debugPrint('[Splash] Restore hatası: $e');
        }
      }

      // ── E-posta doğrulama kontrolü ────────────────────────────────────
      // login_screen.dart normal girişte e-posta doğrulanmadan HomeScreen'e
      // geçmiyor (bkz. EmailVerificationScreen yönlendirmesi). Ancak Firebase
      // Auth oturumu kayıt anında (doğrulama yapılmadan) zaten açılıyor ve
      // cihazda kalıcı; bu yüzden kullanıcı doğrulamadan uygulamayı kapatıp
      // yeniden açarsa, burası hiç kontrol yapmadan doğrudan HomeScreen'e
      // yönlendiriyordu — doğrulama adımını tamamen atlatıyordu. Sahip
      // hesabı (AppStrings.isOwnerEmail) için normal girişte de bu kontrol
      // aranmıyor, burada da aynı istisna korunur.
      if (!AppStrings.isOwnerEmail(authUser.email)) {
        // Çevrimdışıyken uzun beklememek için en fazla 4 sn; başarısız
        // olursa cihazdaki son bilinen doğrulama durumu kullanılır.
        try {
          await authUser.reload().timeout(const Duration(seconds: 4));
        } catch (_) {}
        final refreshed = FirebaseAuth.instance.currentUser;
        if (refreshed == null) {
          // reload() sırasında hesap silinmiş/oturum geçersiz kalmış olabilir.
          if (!mounted) return;
          _go(const LoginScreen());
          return;
        }
        if (!refreshed.emailVerified) {
          if (!mounted) return;
          _go(EmailVerificationScreen(email: refreshed.email ?? ''));
          return;
        }
      }

      if (!mounted) return;
      final role = await RoleService().getCurrentRole();
      if (!mounted) return;
      _go(role == UserRole.owner
          ? const OwnerPanelScreen()
          : const HomeScreen());
      return;
    }

    // ── 2. Auth oturumu yok ────────────────────────────────────────────────
    // DÜZELTME (kritik): `isUserRegistered`/`authMigrationDone` SADECE
    // SharedPreferences bayraklarıdır — KİMLİK DOĞRULAMASI YERİNE
    // GEÇMEZLER. Önceden ikisi de true ise (authUser == null olsa BİLE,
    // yani gerçek bir Firebase Auth oturumu YOKKEN) doğrudan HomeScreen'e
    // gidiliyordu. Bu durum, ör. Firebase Auth oturumu bir şekilde temizlenmiş
    // (token iptal edilmiş, uygulama verisi kısmen silinmiş, paylaşılan/
    // ödünç bir cihaz vb.) ama SharedPreferences hâlâ duruyorsa, önceki
    // kullanıcının TÜM yerel önbelleğine (notlar, ödüller, profil) HİÇBİR
    // KİMLİK DOĞRULAMASI OLMADAN erişilebilmesi anlamına geliyordu. Auth
    // oturumu yoksa artık HER ZAMAN LoginScreen'e gidiyoruz; kullanıcı aynı
    // hesapla tekrar giriş yaptığında yerel veri zaten yerinde kalacağı
    // için deneyim kaybı minimaldir (bkz. login_screen.dart'ın restore akışı).
    if (!storage.authMigrationDone) {
      await storage.setAuthMigrationDone();
    }
    if (!mounted) return;
    _go(const LoginScreen());
  }

  void _go(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  // Google Play politikası gereği uygulama Play dışından KENDİNİ
  // GÜNCELLEYEMEZ. Önceden burada Remote Config'teki apk_url'den APK
  // indirtilip kurduruluyordu — Play sürümünde bu doğrudan politika
  // ihlali (reddedilme sebebi). Artık "Güncelle" yalnızca uygulamanın Play
  // Store sayfasını açar; güncellemeyi Play yapar.
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.murakabe.app';

  Future<void> _showUpdateDialog(UpdateInfo info) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !info.forceUpdate,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1B2A3B),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Güncelleme Mevcut',
            style: GoogleFonts.playfairDisplay(
                color: AppColors.gold, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Yeni sürüm (${info.latestVersion}) Google Play\'de hazır.',
            style: GoogleFonts.notoSans(color: AppColors.white),
          ),
          actions: [
            if (!info.forceUpdate)
              TextButton(
                onPressed: () async {
                  await LocalStorage().setSkippedVersion(info.latestVersion);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Sonra',
                    style: TextStyle(color: AppColors.turquoiseLight)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final uri = Uri.parse(_playStoreUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
                if (!info.forceUpdate && ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Güncelle'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B2A3B), Color(0xFF0A1628)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _IslamicPatternPainter()),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeInDown(
                    duration: const Duration(milliseconds: 1000),
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/images/logo.png',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: Text(
                      'مراقبة',
                      style: GoogleFonts.amiri(
                        fontSize: 42,
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: Text(
                      'MURAKABE',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 20,
                        color: AppColors.white,
                        letterSpacing: 6,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      AppStrings.splashMessages[_messageIndex],
                      key: ValueKey(_messageIndex),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.notoSans(
                        fontSize: 16,
                        color: AppColors.turquoiseLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IslamicPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.05)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double step = 80;
    for (double x = 0; x < size.width + step; x += step) {
      for (double y = 0; y < size.height + step; y += step) {
        _drawOctagon(canvas, paint, Offset(x, y), 30);
      }
    }
  }

  void _drawOctagon(Canvas canvas, Paint paint, Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45 - 22.5) * math.pi / 180;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
