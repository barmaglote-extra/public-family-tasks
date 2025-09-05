import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';

  // Supported languages
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('ru', 'RU'), // Russian
    Locale('de', 'DE'), // German
    Locale('uk', 'UA'), // Ukrainian
    Locale('es', 'ES'), // Spanish
    Locale('fr', 'FR'), // French
  ];

  static const Map<String, String> languageNames = {
    'en_US': 'English',
    'ru_RU': 'Русский',
    'de_DE': 'Deutsch',
    'uk_UA': 'Українська',
    'es_ES': 'Español',
    'fr_FR': 'Français',
  };

  Locale _currentLocale = const Locale('en', 'US');
  Map<String, String> _localizedStrings = {};

  Locale get currentLocale => _currentLocale;

  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey) ?? 'en_US';

    final parts = languageCode.split('_');
    if (parts.length == 2) {
      _currentLocale = Locale(parts[0], parts[1]);
    }

    await _loadLocalizedStrings(_currentLocale);
    notifyListeners();
  }

  Future<void> changeLanguage(Locale locale) async {
    if (_currentLocale == locale) return;

    _currentLocale = locale;
    await _loadLocalizedStrings(locale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, '${locale.languageCode}_${locale.countryCode}');

    notifyListeners();
  }

  Future<void> _loadLocalizedStrings(Locale locale) async {
    try {
      final fileName = '${locale.languageCode}_${locale.countryCode}';
      final jsonString = await rootBundle.loadString('assets/intl/$fileName.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);

      _localizedStrings = {};
      _extractStrings(jsonMap, '');
    } catch (e) {
      // Fallback to English if loading fails
      if (locale.languageCode != 'en') {
        await _loadLocalizedStrings(const Locale('en', 'US'));
      }
    }
  }

  void _extractStrings(Map<String, dynamic> map, String prefix) {
    map.forEach((key, value) {
      final fullKey = prefix.isEmpty ? key : '$prefix.$key';
      if (value is String) {
        _localizedStrings[fullKey] = value;
      } else if (value is Map<String, dynamic>) {
        _extractStrings(value, fullKey);
      }
    });
  }

  String translate(String key, {Map<String, String>? params}) {
    String translation = _localizedStrings[key] ?? key;

    if (params != null) {
      params.forEach((paramKey, paramValue) {
        translation = translation.replaceAll('{$paramKey}', paramValue);
      });
    }

    return translation;
  }

  // Convenience method for getting translations
  String t(String key, {Map<String, String>? params}) => translate(key, params: params);
}

// Extension for easy access to localization in widgets
extension LocalizationExtension on BuildContext {
  LocalizationService get loc => LocalizationService();
  String t(String key, {Map<String, String>? params}) => LocalizationService().translate(key, params: params);
}
