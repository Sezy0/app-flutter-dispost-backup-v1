import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static const String _themeKey = 'selected_theme';
  static const String _defaultTheme = 'light';

  static Future<String> getTheme() async {
    try {
      debugPrint('Mengakses SharedPreferences untuk tema...');
      final prefs = await SharedPreferences.getInstance();
      final theme = prefs.getString(_themeKey) ?? _defaultTheme;
      debugPrint('Tema yang ditemukan: $theme');
      return theme;
    } catch (e) {
      debugPrint('Error saat mengakses SharedPreferences untuk tema: $e');
      // Hapus data corrupt dan reset ke default
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_themeKey);
        debugPrint('Data tema corrupt telah dihapus, menggunakan default');
      } catch (clearError) {
        debugPrint('Error saat menghapus data corrupt: $clearError');
      }
      return _defaultTheme;
    }
  }

  static Future<void> setTheme(String theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme);
  }

  static bool isDarkMode(String theme) {
    return theme == 'dark';
  }

  static bool isLightMode(String theme) {
    return theme == 'light';
  }
} 