import 'package:flutter/material.dart';
import 'package:dispost_autopost/core/services/theme_service.dart';

class ThemeProvider extends ChangeNotifier {
  String _currentTheme = 'light';

  String get currentTheme => _currentTheme;
  bool get isDarkMode => ThemeService.isDarkMode(_currentTheme);
  bool get isLightMode => ThemeService.isLightMode(_currentTheme);

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final theme = await ThemeService.getTheme();
      _currentTheme = theme;
      notifyListeners();
    } catch (e) {
      _currentTheme = 'light'; // fallback ke default
      notifyListeners();
    }
  }

  Future<void> setTheme(String theme) async {
    await ThemeService.setTheme(theme);
    _currentTheme = theme;
    notifyListeners();
  }

  ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.deepPurple, // Menggunakan deepPurple sebagai material swatch terdekat
      primaryColor: const Color(0xFF7d3dfe), // Warna utama custom
      fontFamily: 'Premier League',
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF7d3dfe), // Menggunakan warna ungu custom
        unselectedItemColor: Colors.grey,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: Colors.grey.shade50,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: Colors.black,
        iconColor: Colors.black87,
      ),
    );
  }

  ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.deepPurple, // Menggunakan deepPurple sebagai material swatch terdekat
      primaryColor: const Color(0xFF7d3dfe), // Warna utama custom
      fontFamily: 'Premier League',
      scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Background lebih terang dari sebelumnya
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2A2A2A), // AppBar lebih terang
        foregroundColor: Colors.white, // Text putih
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white), // Icon putih
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF2A2A2A), // Background lebih terang
        selectedItemColor: Color(0xFF7d3dfe), // Icon dan label aktif ungu custom
        unselectedItemColor: Colors.white70, // Icon dan label tidak aktif putih dengan opacity
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF3A3A3A), // Card lebih terang untuk kontras yang lebih baik
        elevation: 4, // Elevation lebih tinggi untuk shadow yang lebih terlihat
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1), // Border tipis untuk definisi yang lebih baik
            width: 0.5,
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white, // Text putih
        iconColor: Colors.white70, // Icon putih dengan opacity
      ),
      // Menambahkan textTheme untuk memastikan semua text berwarna putih
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Colors.white),
        displayMedium: TextStyle(color: Colors.white),
        displaySmall: TextStyle(color: Colors.white),
        headlineLarge: TextStyle(color: Colors.white),
        headlineMedium: TextStyle(color: Colors.white),
        headlineSmall: TextStyle(color: Colors.white),
        titleLarge: TextStyle(color: Colors.white),
        titleMedium: TextStyle(color: Colors.white),
        titleSmall: TextStyle(color: Colors.white),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white),
        bodySmall: TextStyle(color: Colors.white),
        labelLarge: TextStyle(color: Colors.white),
        labelMedium: TextStyle(color: Colors.white),
        labelSmall: TextStyle(color: Colors.white),
      ),
      // Menambahkan iconTheme global
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  ThemeData get currentThemeData {
    return isDarkMode ? darkTheme : lightTheme;
  }
} 