import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/quran_repository.dart';

/// `QuranPageView` ve `QuranSurahView` arasında paylaşılan ayet satırı.
class QuranAyahTile extends StatelessWidget {
  final QuranAyah ayah;
  final bool isSelected;
  final bool showMeal;
  final double arabicFontSize;
  final String secondaryLabel;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const QuranAyahTile({
    super.key,
    required this.ayah,
    required this.isSelected,
    required this.showMeal,
    required this.arabicFontSize,
    required this.secondaryLabel,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final arabicColor = isSelected
        ? AppColors.gold
        : (isDark ? Colors.white : const Color(0xFF1A1A1A));
    final turkishColor = isDark ? Colors.white60 : AppColors.textSecondary;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold.withValues(alpha: 0.08) : null,
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${ayah.number}',
                  style: GoogleFonts.notoSans(
                    color: isSelected
                        ? AppColors.gold
                        : AppColors.gold.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.volume_up, color: AppColors.gold, size: 12),
                ],
                const Spacer(),
                Text(
                  secondaryLabel,
                  style: GoogleFonts.notoSans(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              ayah.arabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(
                fontFamily: 'NotoNaskhArabic',
                fontSize: arabicFontSize,
                color: arabicColor,
                height: 2.6,
              ),
            ),
            if (showMeal) ...[
              const SizedBox(height: 10),
              Text(
                ayah.turkish,
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  color: turkishColor,
                  height: 1.7,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
