import 'package:flutter_tts/flutter_tts.dart';

class VoiceHelper {
  static final FlutterTts _tts = FlutterTts();

  static Future<void> init() async {
    await _tts.setLanguage("en-IN");   // Indian English accent
    await _tts.setSpeechRate(0.9);     // Perfect speed for seniors
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
  }

  static Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  static Future<void> stop() async {
    await _tts.stop();
  }
}