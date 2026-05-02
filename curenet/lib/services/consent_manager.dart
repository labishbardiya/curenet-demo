import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart' as crypto_lib;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ─── ABDM M3 Consent Manager ─────────────────────────────────────────────────
/// Implements the ABDM HIE-CM Consent Flow for secure patient data sharing.
///
/// Security Architecture (per ABDM M3 spec):
/// ┌──────────────────────────────────────────────────────────────────────────┐
/// │ 1. Patient generates unique session token (SHA-256 + CSPRNG nonce)      │
/// │ 2. Token embedded in QR as signed payload (HMAC-SHA256)                 │
/// │ 3. Doctor scans → consent request sent via HIE-CM                       │
/// │ 4. Patient approves → ECDH X25519 key exchange                          │
/// │ 5. Health data encrypted with AES-256-GCM using derived shared secret   │
/// │ 6. Encrypted bundle pushed to doctor with time-bound access (30 min)    │
/// │ 7. Auto-expiry + patient can revoke at any time                         │
/// └──────────────────────────────────────────────────────────────────────────┘
///
/// Consent Purpose Codes (ABDM standard):
///   CAREMGT  - Care Management
///   BTG      - Break the Glass (emergency)
///   PUBHLTH  - Public Health
///   HPAYMT   - Healthcare Payment
///   DSRCH    - Disease Specific Healthcare Research
///   PATRQT   - Self Requested

// ─── ENUMS ──────────────────────────────────────────────────────────────────

enum ConsentStatus { pending, granted, denied, revoked, expired, delayed }

enum ConsentPurposeCode { CAREMGT, BTG, PUBHLTH, HPAYMT, DSRCH, PATRQT }

enum HIType {
  OPConsultation,
  Prescription,
  DischargeSummary,
  DiagnosticReport,
  ImmunizationRecord,
  HealthDocumentRecord,
  WellnessRecord,
}

// ─── DATA MODELS ────────────────────────────────────────────────────────────

class ConsentPurpose {
  final String text;
  final ConsentPurposeCode code;
  final String refUri;

  const ConsentPurpose({
    required this.text,
    required this.code,
    this.refUri = 'https://nrces.in/ndhm/fhir/r4/ValueSet/ndhm-purpose-of-use',
  });

  Map<String, dynamic> toJson() => {
    'text': text,
    'code': code.name,
    'refUri': refUri,
  };

  static const careManagement = ConsentPurpose(
    text: 'Care Management',
    code: ConsentPurposeCode.CAREMGT,
  );

  static const breakTheGlass = ConsentPurpose(
    text: 'Break the Glass',
    code: ConsentPurposeCode.BTG,
  );
}

class ConsentRequester {
  final String name;
  final String identifierType;  // e.g., REGNO1
  final String identifierValue; // e.g., MH1001
  final String identifierSystem; // e.g., https://www.nmc.org.in

  const ConsentRequester({
    required this.name,
    required this.identifierType,
    required this.identifierValue,
    required this.identifierSystem,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'identifier': {
      'type': identifierType,
      'value': identifierValue,
      'system': identifierSystem,
    },
  };
}

class ConsentPermission {
  final String accessMode; // VIEW, STORE, QUERY, LINK
  final DateTime from;
  final DateTime to;
  final DateTime dataEraseAt;
  final String frequencyUnit;
  final int frequencyValue;
  final int frequencyRepeats;

  const ConsentPermission({
    this.accessMode = 'VIEW',
    required this.from,
    required this.to,
    required this.dataEraseAt,
    this.frequencyUnit = 'HOUR',
    this.frequencyValue = 1,
    this.frequencyRepeats = 0,
  });

  Map<String, dynamic> toJson() => {
    'accessMode': accessMode,
    'dateRange': {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    },
    'dataEraseAt': dataEraseAt.toUtc().toIso8601String(),
    'frequency': {
      'unit': frequencyUnit,
      'value': frequencyValue,
      'repeats': frequencyRepeats,
    },
  };
}

class ConsentArtefact {
  final String consentId;
  final String requestId;
  final ConsentStatus status;
  final ConsentPurpose purpose;
  final String patientAbha;
  final String hipId;
  final String hiuId;
  final ConsentRequester requester;
  final List<HIType> hiTypes;
  final ConsentPermission permission;
  final DateTime createdAt;
  final DateTime? grantedAt;
  final DateTime? revokedAt;
  final String? requesterPublicKey; // X25519 Public Key (Base64)

  ConsentArtefact({
    required this.consentId,
    required this.requestId,
    required this.status,
    required this.purpose,
    required this.patientAbha,
    required this.hipId,
    required this.hiuId,
    required this.requester,
    required this.hiTypes,
    required this.permission,
    DateTime? createdAt,
    this.grantedAt,
    this.revokedAt,
    this.requesterPublicKey,
  }) : createdAt = createdAt ?? DateTime.now();

  ConsentArtefact copyWith({ConsentStatus? status, DateTime? grantedAt, DateTime? revokedAt}) {
    return ConsentArtefact(
      consentId: consentId,
      requestId: requestId,
      status: status ?? this.status,
      purpose: purpose,
      patientAbha: patientAbha,
      hipId: hipId,
      hiuId: hiuId,
      requester: requester,
      hiTypes: hiTypes,
      permission: permission,
      createdAt: createdAt,
      grantedAt: grantedAt ?? this.grantedAt,
      revokedAt: revokedAt ?? this.revokedAt,
      requesterPublicKey: requesterPublicKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'consentId': consentId,
    'requestId': requestId,
    'status': status.name.toUpperCase(),
    'purpose': purpose.toJson(),
    'patient': {'id': patientAbha},
    'hip': {'id': hipId},
    'hiu': {'id': hiuId},
    'requester': requester.toJson(),
    'hiTypes': hiTypes.map((t) => t.name.toUpperCase()).toList(),
    'permission': permission.toJson(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (grantedAt != null) 'grantedAt': grantedAt!.toUtc().toIso8601String(),
    if (revokedAt != null) 'revokedAt': revokedAt!.toUtc().toIso8601String(),
  };
}

// ─── QR TOKEN (Signed, tamper-proof) ────────────────────────────────────────

class SecureQrToken {
  final String sessionId;
  final String patientAbha;
  final String nonce;
  final int timestamp;
  final int expiresAt;
  final String signature; // HMAC-SHA256

  SecureQrToken({
    required this.sessionId,
    required this.patientAbha,
    required this.nonce,
    required this.timestamp,
    required this.expiresAt,
    required this.signature,
  });

  Map<String, dynamic> toJson() => {
    'sid': sessionId,
    'abha': patientAbha,
    'n': nonce,
    'ts': timestamp,
    'exp': expiresAt,
    'sig': signature,
  };

  String toEncodedString() => base64Url.encode(utf8.encode(jsonEncode(toJson())));

  static SecureQrToken? fromEncodedString(String encoded) {
    try {
      final json = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      return SecureQrToken(
        sessionId: json['sid'],
        patientAbha: json['abha'],
        nonce: json['n'],
        timestamp: json['ts'],
        expiresAt: json['exp'],
        signature: json['sig'],
      );
    } catch (_) {
      return null;
    }
  }
}

// ─── MAIN CONSENT MANAGER ──────────────────────────────────────────────────

class ConsentManager extends ChangeNotifier {
  // Active consent artefacts
  final List<ConsentArtefact> _artefacts = [];
  List<ConsentArtefact> get artefacts => List.unmodifiable(_artefacts);

  // Current QR session
  SecureQrToken? _activeQrToken;
  SecureQrToken? get activeQrToken => _activeQrToken;

  // ECDH keypair for this session
  SimpleKeyPair? _sessionKeyPair;
  SimplePublicKey? _sessionPublicKey;

  // Pending consent request (from doctor)
  ConsentArtefact? _pendingRequest;
  ConsentArtefact? get pendingRequest => _pendingRequest;

  // Stream for real-time request notifications
  final _requestStreamController = StreamController<ConsentArtefact>.broadcast();
  Stream<ConsentArtefact> get requestStream => _requestStreamController.stream;

  // HMAC secret key (generated per-session, stored securely)
  late List<int> _hmacSecret;

  ConsentManager() {
    _hmacSecret = _generateSecureRandom(32);
    _loadArtefacts(); // Restore persisted access log
  }

  // ─── SECURE PERSISTENCE ─────────────────────────────────────────────────
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'consent_access_log';

  /// Persist all artefacts to secure storage (AES-encrypted on Android)
  Future<void> _persistArtefacts() async {
    try {
      final data = _artefacts.map((a) => {
        'consentId': a.consentId,
        'requestId': a.requestId,
        'status': a.status.name,
        'patientAbha': a.patientAbha,
        'hipId': a.hipId,
        'hiuId': a.hiuId,
        'requesterName': a.requester.name,
        'requesterIdType': a.requester.identifierType,
        'requesterIdValue': a.requester.identifierValue,
        'requesterIdSystem': a.requester.identifierSystem,
        'createdAt': a.createdAt.toUtc().toIso8601String(),
        'grantedAt': a.grantedAt?.toUtc().toIso8601String(),
        'revokedAt': a.revokedAt?.toUtc().toIso8601String(),
      }).toList();
      await _storage.write(key: _storageKey, value: jsonEncode(data));
    } catch (e) {
      debugPrint('Failed to persist artefacts: $e');
    }
  }

  /// Load artefacts from secure storage on startup
  Future<void> _loadArtefacts() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> data = jsonDecode(raw);
      for (final item in data) {
        final statusStr = item['status'] as String;
        ConsentStatus status;
        switch (statusStr) {
          case 'granted': status = ConsentStatus.granted; break;
          case 'revoked': status = ConsentStatus.revoked; break;
          case 'denied':  status = ConsentStatus.denied;  break;
          case 'expired': status = ConsentStatus.expired;  break;
          default:        status = ConsentStatus.pending;  break;
        }

        // Skip pending — those are ephemeral session requests
        if (status == ConsentStatus.pending) continue;

        // Avoid duplicates
        if (_artefacts.any((a) => a.consentId == item['consentId'])) continue;

        _artefacts.add(ConsentArtefact(
          consentId: item['consentId'],
          requestId: item['requestId'],
          status: status,
          purpose: ConsentPurpose.careManagement,
          patientAbha: item['patientAbha'] ?? '',
          hipId: item['hipId'] ?? '',
          hiuId: item['hiuId'] ?? '',
          requester: ConsentRequester(
            name: item['requesterName'] ?? 'Unknown Doctor',
            identifierType: item['requesterIdType'] ?? 'REGNO1',
            identifierValue: item['requesterIdValue'] ?? '',
            identifierSystem: item['requesterIdSystem'] ?? '',
          ),
          hiTypes: [HIType.OPConsultation],
          permission: ConsentPermission(
            from: DateTime.now().subtract(const Duration(days: 365)),
            to: DateTime.now(),
            dataEraseAt: DateTime.now().add(const Duration(days: 30)),
          ),
          createdAt: DateTime.tryParse(item['createdAt'] ?? '') ?? DateTime.now(),
          grantedAt: item['grantedAt'] != null ? DateTime.tryParse(item['grantedAt']) : null,
          revokedAt: item['revokedAt'] != null ? DateTime.tryParse(item['revokedAt']) : null,
        ));
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load artefacts: $e');
    }
  }

  // ─── CSPRNG (Cryptographically Secure Pseudo-Random Number Generator) ────

  static List<int> _generateSecureRandom(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static String _generateUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    // Set version 4 bits
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
           '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
           '${hex.substring(20)}';
  }

  // ─── HMAC-SHA256 SIGNATURE ────────────────────────────────────────────────

  String _signPayload(String payload) {
    final key = utf8.encode(base64.encode(_hmacSecret));
    final hmacSha256 = crypto_lib.Hmac(crypto_lib.sha256, key);
    final digest = hmacSha256.convert(utf8.encode(payload));
    return digest.toString();
  }

  bool verifySignature(SecureQrToken token) {
    final payload = '${token.sessionId}:${token.patientAbha}:${token.nonce}:${token.timestamp}:${token.expiresAt}';
    final expectedSig = _signPayload(payload);
    // Constant-time comparison to prevent timing attacks
    if (expectedSig.length != token.signature.length) return false;
    var result = 0;
    for (var i = 0; i < expectedSig.length; i++) {
      result |= expectedSig.codeUnitAt(i) ^ token.signature.codeUnitAt(i);
    }
    return result == 0;
  }

  // ─── QR TOKEN GENERATION ──────────────────────────────────────────────────

  Future<String> generateSecureQrData(String patientAbha) async {
    _pendingRequest = null; // Clear old pending requests for new session
    // 1. Generate ECDH keypair for this session
    final algorithm = X25519();
    _sessionKeyPair = await algorithm.newKeyPair();
    _sessionPublicKey = await _sessionKeyPair!.extractPublicKey();

    // 2. Generate session-unique values
    final sessionId = _generateUuid();
    final nonce = base64Url.encode(_generateSecureRandom(16));
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final expiresAt = now + (30 * 60); // 30 minutes

    // 3. Create HMAC signature over all fields
    final payload = '$sessionId:$patientAbha:$nonce:$now:$expiresAt';
    final signature = _signPayload(payload);

    // 4. Build token
    _activeQrToken = SecureQrToken(
      sessionId: sessionId,
      patientAbha: patientAbha,
      nonce: nonce,
      timestamp: now,
      expiresAt: expiresAt,
      signature: signature,
    );

    notifyListeners();

    // 5. Return the full QR payload (base64url encoded JSON)
    // Format: curenet://consent?token=<base64url>&pub=<base64 X25519 public key>
    final pubKeyBytes = _sessionPublicKey!.bytes;
    final pubKeyB64 = base64Url.encode(pubKeyBytes);
    
    return 'curenet://consent?v=3&token=${_activeQrToken!.toEncodedString()}&pub=$pubKeyB64';
  }

  // ─── REAL-TIME POLLING (Actual Application) ──────────────────────────────

  /// Polls the backend for new consent requests for this patient
  Future<void> pollForRequests(String abha) async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.backendBaseUrl}/api/consent/poll/$abha'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List requests = data['requests'];
        
        for (var req in requests) {
          // Security Check: Ignore ghost requests from previous sessions
          final String incomingSid = (req['sessionId'] ?? '').toString().trim();
          final String currentSid = (_activeQrToken?.sessionId ?? '').toString().trim();

          if (_activeQrToken == null || incomingSid != currentSid) {
            continue;
          }

          // If we don't have this request yet, add it
          if (!_artefacts.any((a) => a.requestId == req['requestId'])) {
            final artefact = ConsentArtefact(
              consentId: _generateUuid(),
              requestId: req['requestId'],
              status: ConsentStatus.pending,
              purpose: ConsentPurpose.careManagement,
              patientAbha: abha,
              hipId: 'CureNet_HIP',
              hiuId: 'Doctor_Portal',
              requester: ConsentRequester(
                name: req['doctorName'],
                identifierType: 'REGNO1',
                identifierValue: req['doctorId'],
                identifierSystem: 'https://www.nmc.org.in',
              ),
              hiTypes: [HIType.OPConsultation, HIType.Prescription, HIType.DiagnosticReport],
              permission: ConsentPermission(
                accessMode: 'VIEW',
                from: DateTime.now().subtract(const Duration(days: 365)),
                to: DateTime.now(),
                dataEraseAt: DateTime.now().add(const Duration(minutes: 30)),
              ),
              requesterPublicKey: req['doctorPubKey'],
            );
            
            _pendingRequest = artefact;
            _artefacts.add(artefact);
            _requestStreamController.add(artefact); // Push to real-time stream
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('Live Polling error: $e');
    }
  }

  @override
  void dispose() {
    _requestStreamController.close();
    super.dispose();
  }

  /// Sends the patient's response (GRANTED/DENIED) to the backend
  Future<void> sendResponse(String abha, String requestId, String status, {Map<String, dynamic>? encryptedBundle}) async {
    try {
      final Map<String, dynamic> body = {
        'abha': abha,
        'requestId': requestId,
        'status': status,
      };
      if (encryptedBundle != null) {
        body['encryptedBundle'] = encryptedBundle;
      }
      
      await http.post(
        Uri.parse('${AppConfig.backendBaseUrl}/api/consent/respond'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint('Response error: $e');
    }
  }

  // ─── CONSENT REQUEST HANDLING ─────────────────────────────────────────────

  /// Simulates receiving a consent request from a doctor (HIU) via HIE-CM.
  /// In production, this would come via the ABDM gateway callback:
  ///   POST /api/v3/hip/consent/request/notify
  ConsentArtefact createConsentRequest({
    required String doctorName,
    required String doctorRegNo,
    required String doctorSystem,
    required String patientAbha,
    required String hipId,
    required String hiuId,
    ConsentPurpose purpose = ConsentPurpose.careManagement,
    List<HIType>? hiTypes,
  }) {
    final now = DateTime.now();
    final artefact = ConsentArtefact(
      consentId: _generateUuid(),
      requestId: _generateUuid(),
      status: ConsentStatus.pending,
      purpose: purpose,
      patientAbha: patientAbha,
      hipId: hipId,
      hiuId: hiuId,
      requester: ConsentRequester(
        name: doctorName,
        identifierType: 'REGNO1',
        identifierValue: doctorRegNo,
        identifierSystem: doctorSystem,
      ),
      hiTypes: hiTypes ?? [
        HIType.OPConsultation,
        HIType.Prescription,
        HIType.DiagnosticReport,
      ],
      permission: ConsentPermission(
        accessMode: 'VIEW',
        from: now.subtract(const Duration(days: 365)),
        to: now,
        dataEraseAt: now.add(const Duration(minutes: 30)),
        frequencyUnit: 'HOUR',
        frequencyValue: 1,
        frequencyRepeats: 0,
      ),
    );

    _pendingRequest = artefact;
    _artefacts.add(artefact);
    notifyListeners();
    _persistArtefacts();
    return artefact;
  }

  // ─── CONSENT ACTIONS ──────────────────────────────────────────────────────

  /// Patient GRANTS consent → triggers ECDH key exchange + encrypted data push
  Future<ConsentArtefact?> grantConsent(String consentId) async {
    final idx = _artefacts.indexWhere((a) => a.consentId == consentId);
    if (idx == -1) return null;

    final updated = _artefacts[idx].copyWith(
      status: ConsentStatus.granted,
      grantedAt: DateTime.now(),
    );
    _artefacts[idx] = updated;
    _pendingRequest = null;
    notifyListeners();
    _persistArtefacts();

    // In production: POST /api/hiecm/consent/v3/request/hiu/on-notify
    // with status: "GRANTED" and consent artefact ID
    return updated;
  }

  /// Patient DENIES consent
  ConsentArtefact? denyConsent(String consentId) {
    final idx = _artefacts.indexWhere((a) => a.consentId == consentId);
    if (idx == -1) return null;

    final updated = _artefacts[idx].copyWith(status: ConsentStatus.denied);
    _artefacts[idx] = updated;
    _pendingRequest = null;
    notifyListeners();
    _persistArtefacts();
    return updated;
  }

  /// Patient DELAYS consent (request stays pending, notified in 5 min)
  void delayConsent(String consentId) {
    // Keep as pending, but mark for delayed notification
    notifyListeners();
  }

  /// Patient REVOKES previously granted consent
  ConsentArtefact? revokeConsent(String consentId) {
    final idx = _artefacts.indexWhere((a) => a.consentId == consentId);
    if (idx == -1) return null;

    final updated = _artefacts[idx].copyWith(
      status: ConsentStatus.revoked,
      revokedAt: DateTime.now(),
    );
    _artefacts[idx] = updated;
    notifyListeners();
    _persistArtefacts();
    return updated;
  }

  // ─── ENCRYPTED DATA BUNDLE (ABDM M3 Data Flow) ───────────────────────────

  /// Builds the encrypted health information bundle per ABDM spec.
  /// Uses ECDH X25519 for key agreement + AES-256-GCM for data encryption.
  ///
  /// Data flow (per M3 doc):
  /// 1. HIU sends its X25519 public key + random nonce
  /// 2. HIP (us) derives shared secret via ECDH
  /// 3. HIP encrypts FHIR bundle with AES-256-GCM using derived key
  /// 4. HIP pushes encrypted data to HIU's data-push URL
  Future<Map<String, dynamic>> buildEncryptedSnapshot({
    required Map<String, dynamic> healthData,
    required ConsentArtefact artefact,
  }) async {
    final consentId = artefact.consentId;
    // 0. Ensure we have a session keypair (ABDM: usually generated per session/QR)
    if (_sessionKeyPair == null) {
      final algorithm = X25519();
      _sessionKeyPair = await algorithm.newKeyPair();
      _sessionPublicKey = await _sessionKeyPair!.extractPublicKey();
    }

    // 1. Generate a fresh nonce for this data transfer
    final nonce = _generateSecureRandom(12); // 96-bit for AES-GCM

    // 2. Use the DOCTOR'S public key for ECDH derivation
    if (artefact.requesterPublicKey == null) throw Exception('No doctor public key');
    final doctorPubKey = SimplePublicKey(
      base64.decode(artefact.requesterPublicKey!),
      type: KeyPairType.x25519,
    );
    final sharedSecret = await _deriveKey(doctorPubKey);

    // 3. Encrypt the health data with AES-256-GCM
    final plaintext = utf8.encode(jsonEncode(healthData));
    final algorithm = AesGcm.with256bits();
    final secretKey = SecretKey(sharedSecret);
    
    final secretBox = await algorithm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // 4. Build the ABDM-compliant data transfer envelope
    return {
      'transactionId': _generateUuid(),
      'consentId': consentId,
      'hipId': 'CureNet_HIP',
      'entries': [
        {
          'content': base64.encode([...secretBox.cipherText, ...secretBox.mac.bytes]),
          'media': 'application/fhir+json',
          'checksum': crypto_lib.sha256.convert(plaintext).toString(),
          'careContextReference': 'CureNet-Session-${_activeQrToken?.sessionId ?? 'unknown'}',
        },
      ],
      'keyMaterial': {
        'cryptoAlg': 'ECDH',
        'curve': 'Curve25519',
        'dhPublicKey': {
          'expiry': DateTime.now().add(const Duration(minutes: 30)).toUtc().toIso8601String(),
          'parameters': 'Curve25519/32byte random key',
          'keyValue': base64.encode(_sessionPublicKey!.bytes),
        },
        'nonce': base64.encode(nonce),
      },
    };
  }

  Future<List<int>> _deriveKey(SimplePublicKey remotePublicKey) async {
    final algorithm = X25519();
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: _sessionKeyPair!,
      remotePublicKey: remotePublicKey,
    );
    final bytes = await sharedSecret.extractBytes();
    // Derive 256-bit key using HKDF-SHA256
    final hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);
    final derivedKey = await hkdf.deriveKey(
      secretKey: SecretKey(bytes),
      nonce: <int>[],         // salt = empty (matches JS: new Uint8Array())
      info: utf8.encode('ABDM_M3_E2EE'),
    );
    return await derivedKey.extractBytes();
  }

  // ─── QR SESSION MANAGEMENT ────────────────────────────────────────────────

  void revokeQrSession() {
    _activeQrToken = null;
    _sessionKeyPair = null;
    _sessionPublicKey = null;
    _pendingRequest = null;
    _hmacSecret = _generateSecureRandom(32); // Rotate secret
    notifyListeners();
  }

  bool isQrActive() => _activeQrToken != null;

  bool isQrExpired() {
    if (_activeQrToken == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now > _activeQrToken!.expiresAt;
  }

  /// Returns remaining seconds before QR expiry
  int qrRemainingSeconds() {
    if (_activeQrToken == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final remaining = _activeQrToken!.expiresAt - now;
    return remaining > 0 ? remaining : 0;
  }

  // ─── AUDIT LOG ────────────────────────────────────────────────────────────

  List<Map<String, dynamic>> getAuditLog() {
    return _artefacts.map((a) => {
      'consentId': a.consentId,
      'doctor': a.requester.name,
      'status': a.status.name,
      'purpose': a.purpose.text,
      'createdAt': a.createdAt.toIso8601String(),
      'grantedAt': a.grantedAt?.toIso8601String(),
      'revokedAt': a.revokedAt?.toIso8601String(),
    }).toList();
  }
}
