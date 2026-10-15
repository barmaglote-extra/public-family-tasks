import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tasks/services/ai_settings_service.dart';

class AiService {
  final _settings = AiSettingsService();

  static const _taskPrompt =
      'You turn a spoken or typed note into a task for a task manager. '
      'Reply with ONLY a JSON object, no markdown, no extra text, in exactly this shape: '
      '{"title": string (short, max 8 words), '
      '"description": string (may be empty), '
      '"subtasks": array of short strings (0 to 7 items, only if the task naturally has steps)}. '
      'Write everything in the same language as the user\'s note.';

  /// Sends one message to an OpenAI-compatible chat endpoint
  /// and returns the text of the reply. Throws on any error.
  Future<String> ask(String text, {String? system}) async {
    final s = await _settings.load();

    final response = await http
        .post(
          Uri.parse(s['endpoint']!),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${s['apiKey']}',
          },
          body: jsonEncode({
            'model': s['model'],
            'messages': [
              if (system != null) {'role': 'system', 'content': system},
              {'role': 'user', 'content': text},
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    return data['choices'][0]['message']['content'] as String;
  }

  /// Turns a free-form note into {title, description, subtasks}.
  Future<Map<String, dynamic>> parseTask(String note) async {
    final reply = await ask(note, system: _taskPrompt);

    // Models sometimes wrap JSON in text or code fences, so cut out the {...} part
    final start = reply.indexOf('{');
    final end = reply.lastIndexOf('}');
    if (start == -1 || end <= start) {
      throw Exception('AI did not return JSON: $reply');
    }

    final data = jsonDecode(reply.substring(start, end + 1)) as Map<String, dynamic>;

    return {
      'title': (data['title'] ?? '').toString(),
      'description': (data['description'] ?? '').toString(),
      'subtasks': data['subtasks'] is List
          ? (data['subtasks'] as List).map((e) => e.toString()).toList()
          : <String>[],
    };
  }
}