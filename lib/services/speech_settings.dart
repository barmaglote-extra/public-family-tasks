import 'package:shared_preferences/shared_preferences.dart';

class SpeechSettings {
  static const _key = 'speech_language';

  /// 'app' = same as app language, 'system' = phone system language,
  /// or a language code like 'ru', 'en', 'de'
  static Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'app';
  }

  static Future<void> save(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, value);
  }
}