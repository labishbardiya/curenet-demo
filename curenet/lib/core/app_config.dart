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
      const String.fromEnvironment('ABDM_CLIENT_ID', defaultValue: '');

  /// ABDM Sandbox Client Secret
  static String get abdmClientSecret =>
      const String.fromEnvironment('ABDM_CLIENT_SECRET', defaultValue: '');

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
}
