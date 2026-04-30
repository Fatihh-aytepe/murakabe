import 'package:flutter/material.dart';

class AppColors {
  // Ana Renkler
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF0D060);
  static const Color goldDark = Color(0xFFA07820);
  static const Color turquoise = Color(0xFF40B4C8);
  static const Color turquoiseLight = Color(0xFF70D4E4);
  static const Color turquoiseDark = Color(0xFF207080);
  static const Color white = Color(0xFFFFFFFF);
  static const Color cream = Color(0xFFFAF6F0);

  // Arka Plan
  static const Color background = Color(0xFFF8F4EE);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF1A1A2E);

  // Metin
  static const Color textPrimary = Color(0xFF2C2C2C);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textLight = Color(0xFF999999);

  // Durum
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);

  // Gradient'lar
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldDark, gold, goldLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient turquoiseGradient = LinearGradient(
    colors: [turquoiseDark, turquoise, turquoiseLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient islamicGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
