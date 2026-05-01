import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class TahajjudOdulScreen extends StatefulWidget {
  const TahajjudOdulScreen({super.key});

  @override
  State<TahajjudOdulScreen> createState() => _TahajjudOdulScreenState();
}

class _TahajjudOdulScreenState extends State<TahajjudOdulScreen>
    with TickerProviderStateMixin {
  late AnimationController _moonCtrl;
  late AnimationController _cardCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _cardFade;
  late Animation<double> _cardScale;
  late Animation<double> _moonFloat;
  late Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    _moonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _cardFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.easeIn),
    );
    _cardScale = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _cardCtrl, curve: Curves.elasticOut),
    );
    _moonFloat = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _moonCtrl, curve: Curves.easeInOut),
    );
    _glow = Tween<double>(begin: 0.3, end: 0.8).animate(_glowCtrl);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _cardCtrl.forward();
    });
  }

  @override
  void dispose() {
    _moonCtrl.dispose();
    _cardCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF010812),
              Color(0xFF050D1F),
              Color(0xFF0A1628),
              Color(0xFF050D1F),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          children: [
            // Yildiz arkaplan
            const Positioned.fill(child: _NightSkyPainterWidget()),

            SafeArea(
              child: FadeTransition(
                opacity: _cardFade,
                child: ScaleTransition(
                  scale: _cardScale,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Column(
                      children: [
                        // Ay ikonu - yukari asagi animasyonlu
                        AnimatedBuilder(
                          animation: _moonFloat,
                          builder: (_, __) => Transform.translate(
                            offset: Offset(0, _moonFloat.value),
                            child: AnimatedBuilder(
                              animation: _glow,
                              builder: (_, __) => Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF4080FF)
                                          .withOpacity(_glow.value * 0.6),
                                      blurRadius: 40,
                                      spreadRadius: 10,
                                    ),
                                    BoxShadow(
                                      color: Colors.white
                                          .withOpacity(_glow.value * 0.2),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  '🌙',
                                  style: TextStyle(fontSize: 70),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Ayet
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'وَمِنَ اللَّيْلِ فَتَهَجَّدْ بِهِ نَافِلَةً لَّكَ',
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.amiri(
                              fontSize: 22,
                              color: AppColors.gold,
                              height: 1.8,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '"Gecenin bir bolumunde de uyanip sana mahsus fazla bir ibadet olarak"'
                          ' namaz kil." — Isra: 79',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSans(
                            fontSize: 12,
                            color: Colors.white38,
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Ana odül karti
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF0A1628).withOpacity(0.95),
                                const Color(0xFF0D2050).withOpacity(0.90),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFF4080FF).withOpacity(0.5),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    const Color(0xFF2040A0).withOpacity(0.4),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Teheccud Odulu',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 24,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      const Color(0xFF4080FF).withOpacity(0.8),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Bu gece milyonlar uykudayken sen Rabbinle bulustun.\n\n'
                                'Gece namazinin en ozel ani; alemin sussup sadece'
                                ' kalplerin konustugu o derin sessizlik aninda,'
                                ' Arsin sahibi ile yalniz kalabilmektir.\n\n'
                                'Bu sadakat, kalbinde hic sonmeyecek bir kandil yakti.'
                                ' Allah bu ibadeti kabul eylesin.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.notoSans(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.85),
                                  height: 1.9,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Yildiz rozeti
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('⭐', style: TextStyle(fontSize: 16)),
                                  const SizedBox(width: 4),
                                  const Text('⭐', style: TextStyle(fontSize: 22)),
                                  const SizedBox(width: 4),
                                  const Text('⭐', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Teheccud Sadigi',
                                style: GoogleFonts.playfairDisplay(
                                  color: AppColors.gold,
                                  fontSize: 14,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.favorite_outline,
                                color: Colors.white),
                            label: Text(
                              'Heybeme Kaydet',
                              style: GoogleFonts.notoSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2040A0),
                              foregroundColor: Colors.white,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 8,
                              shadowColor:
                                  const Color(0xFF2040A0).withOpacity(0.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Kapat',
                            style: GoogleFonts.notoSans(
                                color: Colors.white30, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
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

// Statik yildiz arkaplan (hafif, sabit)
class _NightSkyPainterWidget extends StatelessWidget {
  const _NightSkyPainterWidget();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _NightSkyPainter());
  }
}

class _NightSkyPainter extends CustomPainter {
  static final List<(double, double, double)> _pts = List.generate(
    80,
    (i) {
      final r = math.Random(i * 17 + 3);
      return (r.nextDouble(), r.nextDouble(), r.nextDouble() * 1.5 + 0.3);
    },
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final (x, y, r) in _pts) {
      final opacity = 0.2 + (r / 2.0) * 0.4;
      paint.color = Colors.white.withOpacity(opacity.clamp(0.1, 0.7));
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, paint);
    }
  }

  @override
  bool shouldRepaint(_NightSkyPainter old) => false;
}
