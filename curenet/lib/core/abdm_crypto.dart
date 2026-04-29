import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/asymmetric/api.dart';
import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';

/// Handles ABDM specific Cryptography for Milestone 1
/// Employs RSA OpenSSL encryption with OAEP padding and SHA-1/MGF1 as
/// mandated by the ABDM spec for transmitting PII data.
class AbdmCrypto {
  /// Encrypts an Aadhaar number or OTP using the ABDM Public Key
  static String encryptRsa(String plainText, String publicKeyPem) {
    try {
      final parser = encrypt.RSAKeyParser();
      final RSAAsymmetricKey publicKey = parser.parse(publicKeyPem);
      
      // ABDM strictly requires OAEP with SHA-1 for Aadhaar transmissions.
      final encrypter = encrypt.Encrypter(encrypt.RSA(
        publicKey: publicKey as RSAPublicKey,
        encoding: encrypt.RSAEncoding.OAEP,
        digest: encrypt.RSADigest.SHA1,
      ));

      final encrypted = encrypter.encrypt(plainText);
      return encrypted.base64;
    } catch (e) {
      throw Exception('ABDM RSA Encryption failed: $e');
    }
  }

  /// Generates an ECDH (X25519) KeyPair for M2 Data Flow
  static Future<SimpleKeyPair> generateEcdhKeyPair() async {
    final algorithm = X25519();
    return await algorithm.newKeyPair();
  }

  /// Performs ECDH Key Exchange and derives a shared secret
  static Future<List<int>> deriveSharedSecret(SimpleKeyPair ownKeyPair, SimplePublicKey remotePublicKey) async {
    final algorithm = X25519();
    final sharedSecret = await algorithm.sharedSecretKey(
      keyPair: ownKeyPair,
      remotePublicKey: remotePublicKey,
    );
    return await sharedSecret.extractBytes();
  }

  /// Encrypts data using AES-GCM 256 as required for M2 Data Push
  static Future<encrypt.Encrypted> encryptAesGcm(String plainText, List<int> secretKey, List<int> iv) async {
    final algorithm = AesGcm.with256bits();
    final secretKeyObj = SecretKey(secretKey);
    final box = await algorithm.encrypt(
      utf8.encode(plainText),
      secretKey: secretKeyObj,
      nonce: iv,
    );
    return encrypt.Encrypted(Uint8List.fromList(box.concatenation()));
  }
}
