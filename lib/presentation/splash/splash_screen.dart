import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/update_service.dart';
import '../../core/services/role_service.dart';
import '../../data/local/local_storage.dart';
import '../auth/login_screen.dart';
import '../auth/auth_migration_screen.dart';
import '../home/home_screen.dart';
import '../community/owner_panel_screen.dart';
import '../community/admin_dashboard_screen.dart';

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
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Güncelleme kontrolü
    final updateInfo = await UpdateService().checkForUpdate();
    if (!mounted) return;
    if (updateInfo.hasUpdate && updateInfo.apkUrl.isNotEmpty) {
      await _showUpdateDialog(updateInfo);
      if (!mounted) return;
    }

    final storage = LocalStorage();

    // ── 1. Hiç kayıt yok → Login ──────────────────────────────────────────
    if (!storage.isUserRegistered) {
      _go(const LoginScreen());
      return;
    }

    // ── 2. Kayıt var ama Auth migration yapılmamış ─────────────────────────
    // Eski kullanıcı: SQLite'da var, Firebase Auth'a geçmemiş
    if (!storage.authMigrationDone) {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        // Firebase Auth oturumu yok → migration ekranına gönder
        final oldUserId = storage.userId ?? '';
        if (oldUserId.isNotEmpty) {
          _go(AuthMigrationScreen(oldUserId: oldUserId));
          return;
        }
      } else {
        // Auth oturumu var ama migration flag yok → tamamlanmış say
        await storage.setAuthMigrationDone();
      }
    }

    // ── 3. Migration tamamlanmış → Role göre yönlendir ─────────────────────
    final role = await RoleService().getCurrentRole();
    if (!mounted) return;

    switch (role) {
      case UserRole.owner:
        _go(const OwnerPanelScreen());
        break;
      case UserRole.admin:
        _go(const AdminDashboardScreen());
        break;
      case UserRole.user:
        _go(const HomeScreen());
        break;
    }
  }

  void _go(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _showUpdateDialog(UpdateInfo info) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Güncelleme Mevcut',
          style: GoogleFonts.playfairDisplay(
              color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Yeni sürüm (${info.latestVersion}) hazır!\n\nDaha iyi bir deneyim için güncellemenizi öneririz.',
          style: GoogleFonts.notoSans(color: AppColors.white),
        ),
        actions: [
          if (!info.forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
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
              final uri = Uri.parse(info.apkUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
              if (!info.forceUpdate && ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('Güncelle'),
          ),
        ],
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
