import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';

class BhashiniTranslateService {
  static const String _baseUrl = 'https://bhashini.ai';
  static const String _translatePath = '/v2/translate';
  
  // Cache format: {"hi": {"Hello": "नमस्ते"}}
  static Map<String, Map<String, String>> _cache = {};
  static bool _isCacheLoaded = false;

  static Future<void> _loadCache() async {
    if (_isCacheLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final cacheJson = prefs.getString('bhashini_translation_cache');
    if (cacheJson != null) {
      final decoded = jsonDecode(cacheJson) as Map<String, dynamic>;
      _cache = decoded.map((key, value) => MapEntry(key, Map<String, String>.from(value)));
    }
    _isCacheLoaded = true;
  }

  static Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bhashini_translation_cache', jsonEncode(_cache));
  }

  static Future<String> translateUiText(
    String text, {
    required String targetLanguage,
  }) async {
    if (text.trim().isEmpty) return text;
    if (targetLanguage == 'en') return text;

    await _loadCache();

    // Check cache first
    if (_cache.containsKey(targetLanguage) && _cache[targetLanguage]!.containsKey(text)) {
      return _cache[targetLanguage]![text]!;
    }

    final apiKey = AppConfig.bhashiniApiKey;
    final userId = AppConfig.bhashiniUserId;
    final authorization = AppConfig.bhashiniAuth;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl$_translatePath'),
        headers: {
          'Content-Type': 'application/json',
          'ulcaApiKey': apiKey,
          'userID': userId,
          'Authorization': authorization,
        },
        body: jsonEncode({
          'inputText': text,
          'inputLanguage': 'English',
          'outputLanguage': targetLanguage,
        }),
      );

      if (response.statusCode == 200) {
        final translatedText = utf8.decode(response.bodyBytes).trim();
        
        // Save to cache
        _cache.putIfAbsent(targetLanguage, () => {});
        _cache[targetLanguage]![text] = translatedText;
        _saveCache(); // Fire and forget
        
        return translatedText;
      } else {
        return text; // Fallback to original text if translation fails
      }
    } catch (e) {
      return text; // Fallback to original text in case of an error
    }
  }
}
