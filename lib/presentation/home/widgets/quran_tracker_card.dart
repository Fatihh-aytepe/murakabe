import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class QuranTrackerCard extends StatelessWidget {
  final bool isRead;
  final VoidCallback onRead;

  const QuranTrackerCard({
    super.key,
    required this.isRead,
    required this.onRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isRead
            ? LinearGradient(
                colors: [AppColors.success, AppColors.success.withOpacity(0.7)],
              )
            : const LinearGradient(
                colors: [Color(0xFF2C3E50), Color(0xFF3498DB)],
              ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isRead ? AppColors.success : const Color(0xFF3498DB))
                .withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRead ? Icons.check_circle : Icons.menu_book,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isRead ? 'Bugün Kuran Okudun ✓' : 'Bugün Kuran Okudun mu?',
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isRead
                      ? 'Mâşâallah! Devam et!'
                      : "Allah'ın kelamı kalplere şifa verir",
                  style: GoogleFonts.notoSans(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (!isRead)
            ElevatedButton(
              onPressed: onRead,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF3498DB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: const Text('Okudum', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}
