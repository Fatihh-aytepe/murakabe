import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/models/user_model.dart';

class StreakCard extends StatelessWidget {
  final UserModel user;

  const StreakCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = UserModel.getStreakColors(user.streakDays);
    final badge = UserModel.getStreakBadge(user.streakDays);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Streak sayısı
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${user.streakDays}',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'gün',
                  style: GoogleFonts.notoSans(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge,
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getMotivationText(),
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                if (user.allowedMercyDays > 0) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(
                      user.allowedMercyDays,
                      (i) => Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: i < user.mercyDaysUsed
                              ? Colors.white24
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Aksama payı: ${user.allowedMercyDays - user.mercyDaysUsed} kaldı',
                    style: GoogleFonts.notoSans(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMotivationText() {
    if (user.streakDays == 0) return 'Bugün başla, yarın fark et!';
    if (user.streakDays < 7) return 'Güzel gidiyorsun, devam et!';
    if (user.streakDays < 14) return 'Bir hafta geçti, mükemmel!';
    if (user.streakDays < 30) return 'Alışkanlık haline geliyor!';
    return 'Maşaallah! Gerçek bir serdengeçti!';
  }
}
