/// CureNet app configuration.
/// API keys are read from compile-time env to avoid committing secrets.
///
/// Run with:
///   flutter run --dart-define=BHASHINI_API_KEY=your_inference_api_key
/// Or set in IDE: Run > Edit Configurations > Additional run args.
class AppConfig {
  /// Bhashini Inference API Key (from dashboard.bhashini.co.in).
  /// Used for TTS /synthesize and other inference APIs.
  static String get bhashiniApiKey =>
      String.fromEnvironment('BHASHINI_API_KEY', defaultValue: '');

  /// Bhashini Udyam Key (optional; from dashboard if needed for other APIs).
  static String get bhashiniUdyamKey =>
      String.fromEnvironment('BHASHINI_UDYAM_KEY', defaultValue: '');

  /// Bhashini Client ID (from dashboard.bhashini.co.in).
  static String get bhashiniClientId =>
      String.fromEnvironment('BHASHINI_CLIENT_ID', defaultValue: '');

  /// Bhashini Client Secret (optional; from dashboard if needed for other APIs).
  static String get bhashiniClientSecret =>
      String.fromEnvironment('BHASHINI_CLIENT_SECRET', defaultValue: '');

  static bool get hasBhashiniKey => bhashiniApiKey.isNotEmpty;
}
