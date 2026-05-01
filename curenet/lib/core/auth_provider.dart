import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/abdm_service.dart';
import '../services/secure_storage_service.dart';
import '../core/abdm_crypto.dart';
import '../services/biometric_service.dart';
import '../core/data_mode.dart';

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
  Map<String, dynamic>? _userProfile;
  String? _error;

  AuthStatus get status => _status;
  Map<String, dynamic>? get userProfile => _userProfile;
  String? get error => _error;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final token = await SecureStorageService.getAccessToken();
    if (token != null) {
      AbdmService.setAccessToken(token);
      final profileJson = await SecureStorageService.getUserProfile();
      if (profileJson != null) {
        _userProfile = jsonDecode(profileJson);
        _status = AuthStatus.authenticated;
        notifyListeners();
      }
    }
  }

  // Login flow state (shared with OTP screen via route args)
  String? _lastTxnId;
  String? _lastPublicKey;
  String? _lastMobile;

  String? get lastTxnId => _lastTxnId;
  String? get lastPublicKey => _lastPublicKey;
  String? get lastMobile => _lastMobile;

  Future<void> loginWithMobile(String mobile) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      final keyMap = await AbdmService.getPublicKey();
      final String publicKey = keyMap['publicKey'];
      _lastPublicKey = publicKey;
      _lastMobile = mobile;
      
      final String encryptedMobile = AbdmCrypto.encryptRsa(mobile, publicKey);
      
      // Try real ABDM login
      try {
        final result = await AbdmService.requestLoginOtp(
          encryptedAbhaIdOrMobile: encryptedMobile,
        );
        _lastTxnId = result['txnId'] as String?;
      } catch (e) {
        if (DataMode.isDemo.value) {
          // Demo fallback — allows testing with OTP 123456
          _lastTxnId = 'demo_txn';
        } else {
          rethrow;
        }
      }
      
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    } catch (e) {
      if (DataMode.isDemo.value) {
        // Even if public key fails, allow demo login
        _lastTxnId = 'demo_txn';
        _lastMobile = mobile;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      } else {
        _status = AuthStatus.error;
        _error = e.toString();
        notifyListeners();
      }
    }
  }

  Future<void> verifyOtp(String txnId, String otp, {String flow = 'login', String? publicKey}) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    try {
      Map<String, dynamic> result;
      
      // 1. Immediate Bypass ONLY if in Demo Mode and using test OTP
      if (DataMode.isDemo.value && (otp == '123456' || txnId == 'demo_txn' || txnId == 'dummy_txn')) {
        result = {
          'token': 'demo_token',
          'x-token': 'demo_token',
          'name': 'Arjun Kumar',
          'ABHANumber': '91-6423-3886-4779',
          'healthIdNumber': '91-6423-3886-4779',
          'mobile': _lastMobile ?? '9876543210',
        };
      } else {
        // 2. Real ABDM Path (only if not demo)
        // Get Public Key if not provided
        final String effectivePublicKey = publicKey ?? _lastPublicKey ?? (await AbdmService.getPublicKey())['publicKey'];
        
        // Encrypt OTP
        final String encryptedOtp = AbdmCrypto.encryptRsa(otp, effectivePublicKey);
        
        // Real ABDM Verify based on flow
        if (flow == 'registration') {
          result = await AbdmService.verifyAadhaarOtpForRegistration(
            txnId: txnId,
            encryptedOtp: encryptedOtp,
          );
        } else if (flow == 'registration_mobile') {
          result = await AbdmService.verifyMobileOtp(
            txnId: txnId,
            encryptedOtp: encryptedOtp,
          );
        } else {
          // Login flow
          result = await AbdmService.verifyLoginOtp(
            txnId: txnId,
            encryptedOtp: encryptedOtp,
          );
        }
      }

      // 4. Fetch Profile if token is present
      final String? xToken = result['token'] ?? result['x-token'];
      if (xToken != null) {
        try {
          final profile = await AbdmService.getProfile(xToken: xToken);
          _userProfile = profile;
        } catch (_) {
          // Profile fetch may fail in sandbox — use what we have
          _userProfile = result['profile'] ?? {
            'name': result['name'] ?? 'ABHA User',
            'abha': result['ABHANumber'] ?? result['healthIdNumber'] ?? '',
          };
        }
        await SecureStorageService.saveAccessToken(xToken);
        await SecureStorageService.saveUserProfile(jsonEncode(_userProfile));
      } else if (result['ABHANumber'] != null || result['healthIdNumber'] != null) {
        _userProfile = {
          'name': result['name'] ?? result['firstName'] ?? 'ABHA User',
          'abha': result['ABHANumber'] ?? result['healthIdNumber'] ?? '',
          'mobile': result['mobile'] ?? _lastMobile,
        };
        await SecureStorageService.saveUserProfile(jsonEncode(_userProfile));
      } else {
        _userProfile = {
          'name': 'New User',
          'abha': 'Pending Confirmation',
          'txnId': txnId,
        };
      }
      
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.error;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> authenticateWithBiometrics() async {
    final hasBiometrics = await SecureStorageService.isBiometricsEnabled();
    if (!hasBiometrics) return;

    final success = await BiometricService.authenticate(
      reason: 'Confirm your identity to log in to CureNet',
    );

    if (success) {
      _status = AuthStatus.authenticated;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await SecureStorageService.clearAll();
    _status = AuthStatus.unauthenticated;
    _userProfile = null;
    notifyListeners();
  }
}
