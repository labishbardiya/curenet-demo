class AppConfig {
  // --- PRODUCTION CONFIG ---
  // Replace with your actual cloud API URL once deployed
  static const String _productionUrl = 'https://api.curenet.in/api/ocr';

  // --- DEVELOPMENT CONFIG ---
  // For physical devices, use your computer's local IP. 
  // Current IP: 192.168.1.3
  static const String _developmentUrl = 'http://192.168.1.3:3000/api/ocr';

  // Toggle this to switch between environments
  static const bool isProduction = false;

  static String get ocrApiUrl => isProduction ? _productionUrl : _developmentUrl;
}
