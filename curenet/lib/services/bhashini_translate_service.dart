import 'dart:convert';
import 'package:http/http.dart' as http;

class BhashiniTranslateService {
  static const String _baseUrl = 'https://bhashini.ai';
  static const String _translatePath = '/v2/translate';

  static Future<String> translateUiText(
    String text, {
    required String targetLanguage,
  }) async {
    if (text.trim().isEmpty) return text;

    final apiKey = '42889b9af1-74ae-4bee-93a6-e11c624fcc4c';
    final userId = 'c6276a98739a486a87560781c380a30e';
    final authorization = 'sY2ZrfgvdlGrlFPVymlahefiWF-7a_jixnlXywugRXUl1AEqdey9jjaaAwbuJfM0';

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
        return utf8.decode(response.bodyBytes).trim();
      } else {
        return text; // Fallback to original text if translation fails
      }
    } catch (e) {
      return text; // Fallback to original text in case of an error
    }
  }
}
