import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/reward_service.dart';
import '../../data/repositories/reward_repository.dart';

class MurakabeHosgeldinScreen extends StatefulWidget {
  final VoidCallback onDone;
  const MurakabeHosgeldinScreen({super.key, required this.onDone});

  @override
  State<MurakabeHosgeldinScreen> createState() =>
      _MurakabeHosgeldinScreenState();
}

class _MurakabeHosgeldinScreenState extends State<MurakabeHosgeldinScreen>
    with TickerProviderStateMixin {
  late AnimationController _starCtrl;
  late AnimationController _cardCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _starAnim;

  @override
  void initState() {
    super.initState();
    _starCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut),
    );
    _starAnim = Tween<double>(begin: 0, end: 1).animate(_starCtrl);
    _cardCtrl.forward();

    _saveWelcomeReward();
  }

  Future<void> _saveWelcomeReward() async {
    await RewardRepository().saveReward(
      type: 'welcome',
      title: 'Murakabe Yoluna Hos Geldin',
      message: 'Kalbin daima Allah\'in gozeti altinda oldugu bilincini tasiman,'
          ' ruhunu arindirman ve tefekkur etmen icin bu yola girdin.'
          ' Bu adim, manevi yolculugunun en kiymetli anlaridir.',
    );
    await RewardService().markWelcomeDone();
  }

  @override
  void dispose() {
    _starCtrl.dispose();
    _cardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF020B18), Color(0xFF0D1B2A), Color(0xFF061020)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Yildiz animasyonu
            AnimatedBuilder(
              animation: _starAnim,
              builder: (_, __) => CustomPaint(
                painter: _StarFieldPainter(_starAnim.value),
                child: const SizedBox.expand(),
              ),
            ),
            // Icerik
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // Arapca hatt
                        Text(
                          'مُرَاقَبَة',
                          style: GoogleFonts.amiri(
                            fontSize: 64,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'MURAKABE',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            color: Colors.white38,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Ana kart
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppColors.gold.withOpacity(0.4),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withOpacity(0.15),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Bismillah
                              Text(
                                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.amiri(
                                  fontSize: 20,
                                  color: AppColors.gold,
                                ),
                              ),
                              const SizedBox(height: 20),

                              Container(
                                height: 1,
                                color: AppColors.gold.withOpacity(0.3),
                              ),
                              const SizedBox(height: 20),

                              Text(
                                'Murakabe Yoluna Hos Geldin',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 22,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              Text(
                                'Murakabe; kulun daima Allah\'in gozetimi altinda oldugu'
                                ' bilinci (ihsan) ile kalbini arindirmasi, ic dunyasini'
                                ' kontrol etmesi ve tefekkur etmesi halidir.\n\n'
                                '"Allah\'i goruyormus gibi ibadet et; sen O\'nu gormesen'
                                ' de O seni gormektedir."\n— Cibril Hadisi',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.80),
                                  height: 1.9,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),

                              const SizedBox(height: 20),
                              Container(
                                height: 1,
                                color: AppColors.gold.withOpacity(0.3),
                              ),
                              const SizedBox(height: 20),

                              // Odul rozeti
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: AppColors.gold.withOpacity(0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('✨',
                                        style: TextStyle(fontSize: 18)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Heybene eklendi: Hosgeldin Odulu',
                                      style: GoogleFonts.notoSans(
                                        color: AppColors.gold,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 36),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: widget.onDone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.gold,
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor: AppColors.gold.withOpacity(0.4),
                            ),
                            child: Text(
                              'Yolculuga Basla',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  final double progress;
  static final List<_Star> _stars = List.generate(
    60,
    (i) => _Star(
      x: math.Random(i * 7).nextDouble(),
      y: math.Random(i * 13).nextDouble(),
      r: math.Random(i * 3).nextDouble() * 1.8 + 0.4,
      phase: math.Random(i * 11).nextDouble() * math.pi * 2,
    ),
  );

  const _StarFieldPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final s in _stars) {
      final opacity =
          (0.3 + 0.5 * math.sin(progress * math.pi * 2 + s.phase))
              .clamp(0.1, 0.9);
      paint.color = AppColors.gold.withOpacity(opacity);
      canvas.drawCircle(
          Offset(s.x * size.width, s.y * size.height), s.r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarFieldPainter old) => old.progress != progress;
}

class _Star {
  final double x, y, r, phase;
  const _Star(
      {required this.x, required this.y, required this.r, required this.phase});
}
