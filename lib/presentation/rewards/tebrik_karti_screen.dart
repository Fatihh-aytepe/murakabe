import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/reward_repository.dart';

class TebrikKartiScreen extends StatefulWidget {
  final String type;
  final String title;
  final String message;
  final bool autoSave;

  const TebrikKartiScreen({
    super.key,
    required this.type,
    required this.title,
    required this.message,
    this.autoSave = true,
  });

  @override
  State<TebrikKartiScreen> createState() => _TebrikKartiScreenState();
}

class _TebrikKartiScreenState extends State<TebrikKartiScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  final _rewardRepo = RewardRepository();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();

    if (widget.autoSave) {
      _rewardRepo.saveReward(
        type: widget.type,
        title: widget.title,
        message: widget.message,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B), Color(0xFF0A1628)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: ScaleTransition(
              scale: _scaleAnim,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Yıldızlar
                    const Text('✨', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 24),

                    // Kart
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Bismillah
                          Text(
                            'بِسْمِ اللَّهِ',
                            style: GoogleFonts.amiri(
                              fontSize: 24,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Başlık
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 22,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Altın çizgi
                          Container(
                            height: 1,
                            color: AppColors.gold.withOpacity(0.4),
                          ),
                          const SizedBox(height: 20),

                          // Mesaj
                          Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoSans(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.85),
                              height: 1.8,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tarih
                          Text(
                            _formatDate(),
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              color: AppColors.turquoiseLight,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Heybeme kaydet butonu
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.favorite_outline),
                        label: const Text('Heybeme Kaydet'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Kapat',
                        style: GoogleFonts.notoSans(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate() {
    final now = DateTime.now();
    const months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return '${now.day} ${months[now.month]} ${now.year}';
  }
}
