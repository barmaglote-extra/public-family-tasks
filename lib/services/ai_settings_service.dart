import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiSettingsService {
  static const _storage = FlutterSecureStorage();

  static const _endpointKey = 'ai_endpoint';
  static const _modelKey = 'ai_model';
  static const _apiKeyKey = 'ai_api_key';

  Future<Map<String, String>> load() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'endpoint': prefs.getString(_endpointKey) ?? '',
      'model': prefs.getString(_modelKey) ?? '',
      'apiKey': await _storage.read(key: _apiKeyKey) ?? '',
    };
  }

  Future<void> save({
    required String endpoint,
    required String model,
    String? apiKey,
    bool clearApiKey = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_endpointKey, endpoint.trim());
    await prefs.setString(_modelKey, model.trim());

    if (clearApiKey) {
      await _storage.delete(key: _apiKeyKey);
    } else if (apiKey != null && apiKey.trim().isNotEmpty) {
      await _storage.write(
        key: _apiKeyKey,
        value: apiKey.trim(),
      );
    }
  }

  Future<bool> isConfigured() async {
    final settings = await load();

    final endpoint = Uri.tryParse(settings['endpoint'] ?? '');
    final model = settings['model']?.trim() ?? '';
    final apiKey = settings['apiKey']?.trim() ?? '';

    return endpoint != null &&
        (endpoint.scheme == 'https' || endpoint.scheme == 'http') &&
        endpoint.host.isNotEmpty &&
        model.isNotEmpty &&
        apiKey.isNotEmpty;
  }
}
