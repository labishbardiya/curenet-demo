import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../core/app_config.dart';

/// Bhashini TTS API (v2) – 22 Indian languages.
/// https://bhashini.ai/openapi/ – POST /v2/synthesize → audio/mpeg.
class BhashiniTtsService {
  static const String _baseUrl = 'https://bhashini.ai';
  static const String _synthesizePath = '/v2/synthesize';

  /// Supported language names as per Bhashini OpenAPI (English, Hindi, etc.).
  static String normalizeLanguage(String? language) {
    if (language == null || language.isEmpty) return 'English';
    final normalized = language.trim().toLowerCase();
    const map = {
      'hindi': 'Hindi', 'bengali': 'Bengali', 'marathi': 'Marathi',
      'telugu': 'Telugu', 'tamil': 'Tamil', 'gujarati': 'Gujarati',
      'urdu': 'Urdu', 'kannada': 'Kannada', 'odia': 'Odia',
      'malayalam': 'Malayalam', 'punjabi': 'Punjabi', 'assamese': 'Assamese',
      'maithili': 'Maithili', 'sanskrit': 'Sanskrit', 'nepali': 'Nepali',
      'sindhi': 'Sindhi', 'konkani': 'Konkani', 'dogri': 'Dogri',
      'bodo': 'Bodo', 'manipuri': 'Manipuri', 'kashmiri': 'Kashmiri',
      'bhojpuri': 'Bhojpuri',
    };
    return map[normalized] ?? 'English';
  }

  /// Synthesize speech and play. Returns true if successful.
  static Future<bool> synthesizeAndPlay({
    required String text,
    String? language,
    String voiceName = 'Female1',
    String voiceStyle = 'Neutral',
    double speechRate = 0.3,
  }) async {
    final apiKey = AppConfig.bhashiniApiKey;
    if (apiKey.isEmpty) return false;

    final lang = normalizeLanguage(language);
    final uri = Uri.parse('$_baseUrl$_synthesizePath');
    final body = {
      'text': text,
      'language': lang,
      'voiceName': voiceName,
      'voiceStyle': voiceStyle,
      'speechRate': speechRate,
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'X-API-KEY': apiKey,
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return false;
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) return false;

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/bhashini_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(bytes);

      final player = AudioPlayer();
      await player.play(DeviceFileSource(file.path));
      await player.onPlayerComplete.first;
      try {
        await file.delete();
      } catch (_) {
        // Best-effort cleanup of temp file.
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
