/// CureNet app configuration.
/// API keys are read from compile-time env to avoid committing secrets.
///
/// Run with:
///   flutter run --dart-define=BHASHINI_API_KEY=your_inference_api_key
/// Or set in IDE: Run > Edit Configurations > Additional run args.
class AppConfig {
  /// Groq API Key
  static String get groqApiKey =>
      const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  /// Tavily API Key
  static String get tavilyApiKey =>
      const String.fromEnvironment('TAVILY_API_KEY', defaultValue: '');

  /// ABDM Sandbox Client ID (Bridge ID)
  static String get abdmClientId =>
      const String.fromEnvironment('ABDM_CLIENT_ID', defaultValue: 'SBXID_021821');

  /// ABDM Sandbox Client Secret
  static String get abdmClientSecret =>
      const String.fromEnvironment('ABDM_CLIENT_SECRET', defaultValue: 'e7199d37-43bf-458f-8355-7b0dbe4ee30f');

  /// Bhashini Inference API Key
  static String get bhashiniApiKey =>
      const String.fromEnvironment('BHASHINI_API_KEY', defaultValue: '');

  /// Bhashini User ID
  static String get bhashiniUserId =>
      const String.fromEnvironment('BHASHINI_USER_ID', defaultValue: '');

  /// Bhashini Auth (Authorization)
  static String get bhashiniAuth =>
      const String.fromEnvironment('BHASHINI_AUTH', defaultValue: '');

  static bool get hasBhashiniKey => bhashiniApiKey.isNotEmpty;

  // ─── OCR API Configuration ─────────────────────────────────────────────────
  /// Production OCR URL (replace with actual cloud endpoint once deployed)
  static const String _ocrProductionUrl = 'https://api.curenet.in/api/ocr';

  /// Development OCR URL (use your machine's local IP for device testing)
  static const String _ocrDevelopmentUrl = 'http://192.168.1.11:3000/api/ocr';

  /// Toggle between production and development OCR endpoints
  static const bool isOcrProduction = false;

  static String get ocrApiUrl =>
      isOcrProduction ? _ocrProductionUrl : _ocrDevelopmentUrl;
}

