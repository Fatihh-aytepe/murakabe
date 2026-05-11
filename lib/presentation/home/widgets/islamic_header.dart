import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class IslamicHeader extends StatelessWidget {
  const IslamicHeader({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Hayırlı Sabahlar';
    if (hour < 17) return 'Hayırlı Öğleler';
    if (hour < 20) return 'Hayırlı Akşamlar';
    return 'Hayırlı Geceler';
  }

  String _getArabicGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صَبَاحُ الْخَيْر';
    if (hour < 17) return 'مَسَاءُ الْخَيْر';
    return 'لَيْلَةٌ مُبَارَكَة';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getGreeting(),
                    style: GoogleFonts.notoSans(
                      fontSize: 14,
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    'Murakabe',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 26,
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                _getArabicGreeting(),
                style: GoogleFonts.amiri(
                  fontSize: 18,
                  color: AppColors.turquoiseLight,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Tarih
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Text(
              _formatDate(),
              style: GoogleFonts.notoSans(
                fontSize: 12,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
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
    const days = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return '${days[now.weekday]}, ${now.day} ${months[now.month]} ${now.year}';
  }
}
