// ignore_for_file: unused_element

import 'dart:convert';
import 'package:http/http.dart' as http;

/// ABDM Sandbox integration – M1 (ABHA creation/verification), M2 (HIP), M3 (HIU).
/// Strictly follows: ABDM_ABHA_V3_AP_Is_V1_31_07_2025 PDF + AyushmanNHA YouTube workflows.
///
/// M1 video: session → get public key → encrypt Aadhaar/OTP → request OTP → verify OTP
/// → mobile update (optional) → email verify → ABHA address suggestion → confirm address
/// → profile → download ABHA card. Verification: Aadhaar OTP, ABHA OTP, password, mobile, Aadhaar.
/// Scan & share: register bridge URL, facility QR, on_share callback, profile on share.
///
/// Base URL (sandbox): https://dev.ndhm.gov.in/devservice/gateway
/// Production: use gateway URL without dev/sandbox path as per ABDM docs.
class AbdmService {
  static const String _sandboxBase = 'https://dev.ndhm.gov.in/devservice/gateway';
  static String _baseUrl = _sandboxBase;
  static String? _accessToken;

  static void setBaseUrl(String url) => _baseUrl = url;
  static void setAccessToken(String token) => _accessToken = token;

  /// M1 – Get public key for RSA encryption (Aadhaar, OTP, mobile, email).
  /// GET, no auth. Key expires in 3 months – refresh before expiry.
  static Future<Map<String, dynamic>> getPublicKey() async {
    final uri = Uri.parse('$_baseUrl/v1/gateway/auth/public-key');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw AbdmException('Public key failed: ${response.statusCode}', response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// M1 – Create session. Returns access token for subsequent APIs.
  /// Headers: X-Request-Id (GUID), X-Timestamp (ISO), X-CM-ID: SBX (sandbox).
  /// Body: clientId, clientSecret, grantType: client_credentials.
  static Future<Map<String, dynamic>> createSession({
    required String clientId,
    required String clientSecret,
    String xCmId = 'SBX',
  }) async {
    final uri = Uri.parse('$_baseUrl/v3/sessions');
    final requestId = _newGuid();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Request-Id': requestId,
        'X-Timestamp': timestamp,
        'X-CM-ID': xCmId,
      },
      body: jsonEncode({
        'clientId': clientId,
        'clientSecret': clientSecret,
        'grantType': 'client_credentials',
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200 && response.statusCode != 202) {
      throw AbdmException('Session failed: ${response.statusCode}', response.body);
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final token = map['accessToken'] as String?;
    if (token != null) _accessToken = token;
    return map;
  }

  /// M1 – Request OTP for ABHA enrollment via Aadhaar.
  /// loginId must be encrypted with public key (SHA1 + MGF1 padding per guide).
  static Future<Map<String, dynamic>> requestAadhaarOtp({
    required String encryptedAadhaar,
    String? txnId,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/account/auth/init');
    final body = {
      if (txnId != null && txnId.isNotEmpty) 'txnId': txnId,
      'scope': 'abha-enroll',
      'loginHint': 'Aadhaar',
      'loginId': encryptedAadhaar,
      'otpSystem': 'Aadhaar',
    };
    return _postWithAuth(uri, body);
  }

  /// M1 – Verify OTP (Aadhaar-linked mobile). authData.otp.value = encrypted OTP.
  static Future<Map<String, dynamic>> verifyAadhaarOtp({
    required String txnId,
    required String encryptedOtp,
    required String mobile,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/account/auth/confirm');
    final body = {
      'authData': {
        'authMethod': 'OTP',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'txnId': txnId,
        'otp': {'value': encryptedOtp},
        'mobile': mobile,
      },
      'consent': {'code': 'abha-enrollment', 'version': '1.4'},
    };
    return _postWithAuth(uri, body);
  }

  /// M1 – Fetch ABHA address suggestions (GET). Use txnId from verify OTP flow.
  static Future<Map<String, dynamic>> getAbhaAddressSuggestions({
    required String txnId,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/account/abha/suggest');
    return _getWithAuth(uri, extraHeaders: {'X-Transaction-Id': txnId});
  }

  /// M1 – Confirm ABHA address (from suggestion or custom).
  static Future<Map<String, dynamic>> confirmAbhaAddress({
    required String txnId,
    required String abhaAddress,
    int preferred = 1,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/account/abha/confirm');
    return _postWithAuth(uri, {
      'txnId': txnId,
      'abhaAddress': abhaAddress,
      'preferred': preferred,
    });
  }

  /// M1 – Get profile (GET). Requires X-Token from verify OTP response.
  static Future<Map<String, dynamic>> getProfile({required String xToken}) async {
    final uri = Uri.parse('$_baseUrl/v1/account/profile');
    return _getWithAuth(uri, extraHeaders: {'X-Token': xToken});
  }

  /// M1 – Download ABHA card. Requires X-Token.
  static Future<List<int>> downloadAbhaCard({required String xToken}) async {
    final uri = Uri.parse('$_baseUrl/v1/account/abha/card');
    final requestId = _newGuid();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $_accessToken',
        'X-Request-Id': requestId,
        'X-Timestamp': timestamp,
        'X-CM-ID': 'SBX',
        'X-Token': xToken,
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw AbdmException('ABHA card failed: ${response.statusCode}', response.body);
    }
    return response.bodyBytes;
  }

  /// M1 – Scan & share: Register bridge/callback URL for facility (HIP).
  static Future<void> updateBridgeUrl({
    required String callbackUrl,
  }) async {
    final uri = Uri.parse('$_baseUrl/v1/gateway/bridge/url');
    await _postWithAuth(uri, {'url': callbackUrl});
  }

  static Future<Map<String, dynamic>> _postWithAuth(Uri uri, Map<String, dynamic> body) async {
    final requestId = _newGuid();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
        'X-Request-Id': requestId,
        'X-Timestamp': timestamp,
        'X-CM-ID': 'SBX',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw AbdmException('Request failed: ${response.statusCode}', response.body);
    }
    return response.body.isEmpty ? {} : jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _getWithAuth(Uri uri, {Map<String, String>? extraHeaders}) async {
    final requestId = _newGuid();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final headers = {
      'Authorization': 'Bearer $_accessToken',
      'X-Request-Id': requestId,
      'X-Timestamp': timestamp,
      'X-CM-ID': 'SBX',
      ...?extraHeaders,
    };
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw AbdmException('Request failed: ${response.statusCode}', response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static String _newGuid() {
    // Non-cryptographic GUID (fine for request IDs in sandbox).
    // Avoid bitwise ops on doubles; keep it strictly integer.
    final seed = DateTime.now().microsecondsSinceEpoch;
    var x = seed;
    int nextNibble() {
      // xorshift
      x ^= (x << 13);
      x ^= (x >> 7);
      x ^= (x << 17);
      return (x & 0xF).abs();
    }

    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replaceAllMapped(RegExp(r'[xy]'), (m) {
      final r = nextNibble();
      final v = m[0] == 'x' ? r : ((r & 0x3) | 0x8);
      return v.toRadixString(16);
    });
  }
}

class AbdmException implements Exception {
  final String message;
  final String? body;
  AbdmException(this.message, [this.body]);
  @override
  String toString() => 'AbdmException: $message${body != null ? '\n$body' : ''}';
}
