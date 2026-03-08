import 'dart:convert';
import 'dart:math';

class MockAbdmService {
  // Mock session token (replace with real from Page 7)
  static String getSessionToken() => 'mock-session-token-123';

  // Mock QR generation (simulates ABDM /v1/abha/qr API from Guide Page 19)
  static Future<String> generateAbhaQr({
    required String abhaAddress,
    String type = 'address', // 'address' or 'card'
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Real payload like Guide (encrypted ABHA address)
    final payload = {
      'abhaAddress': abhaAddress,
      'type': type,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'vaultHash': Random().nextInt(1000000).toString(), // Mock ZK hash
    };

    // Base64 for QR data (as per Guide encryption on Page 8)
    final qrData = base64Encode(utf8.encode(jsonEncode(payload)));
    return qrData; // QR scanner decodes this
  }
}