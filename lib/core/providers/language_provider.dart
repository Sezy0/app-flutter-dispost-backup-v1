import 'package:flutter/foundation.dart';
import 'package:dispost_autopost/core/services/language_service.dart';

class LanguageProvider extends ChangeNotifier {
  String _currentLanguage = 'English';

  String get currentLanguage => _currentLanguage;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final language = await LanguageService.getLanguage();
      _currentLanguage = language;
      notifyListeners();
    } catch (e) {
      _currentLanguage = 'English'; // fallback ke default
      notifyListeners();
    }
  }

  Future<void> setLanguage(String language) async {
    await LanguageService.setLanguage(language);
    _currentLanguage = language;
    notifyListeners();
  }

  String getLocalizedText(String key) {
    return LanguageService.getLocalizedText(key, _currentLanguage);
  }
} 