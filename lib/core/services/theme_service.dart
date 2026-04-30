import 'package:flutter/material.dart';
import '../../data/local/local_storage.dart';

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  bool _isDark = false;
  bool get isDark => _isDark;

  Future<void> init() async {
    _isDark = LocalStorage().isDarkMode;
  }

  Future<void> toggleTheme() async {
    _isDark = !_isDark;
    await LocalStorage().setDarkMode(_isDark);
    notifyListeners();
  }
}
