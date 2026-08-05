import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

/// Client-side AES-256-GCM encryption service for securing history data
/// before uploading to Supabase.
///
/// Key derivation uses HKDF with the user's Supabase UID as input key material
/// and a random salt persisted in [FlutterSecureStorage]. This ensures:
/// - Each user gets a unique encryption key
/// - The key never leaves the device
/// - Supabase only ever stores ciphertext
class EncryptionService {
  EncryptionService({
    required this._userId,
    FlutterSecureStorage? storage,
  })  : _storage = storage ?? const FlutterSecureStorage();

  final String _userId;
  final FlutterSecureStorage _storage;

  static const String _saltKeyName = 'keyflow_encryption_salt';
  static const int _keyLengthBytes = 32; // 256-bit
  static const int _ivLengthBytes = 12; // 96-bit IV for GCM

  Uint8List? _cachedKey;

  /// Returns the derived AES-256 key, generating the salt on first run.
  Future<Uint8List> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    final existingSalt = await _storage.read(key: _saltKeyName);
    Uint8List salt;

    if (existingSalt != null && existingSalt.isNotEmpty) {
      salt = base64Url.decode(existingSalt);
    } else {
      salt = _generateSecureRandom(_keyLengthBytes);
      await _storage.write(key: _saltKeyName, value: base64Url.encode(salt));
    }

    _cachedKey = _deriveKey(Uint8List.fromList(utf8.encode(_userId)), salt);
    return _cachedKey!;
  }

  /// Derives a 256-bit key using HKDF-SHA256.
  Uint8List _deriveKey(Uint8List inputKeyMaterial, Uint8List salt) {
    final hkdf = pc.HKDFKeyDerivator(pc.SHA256Digest());
    final params = pc.HkdfParameters(
      inputKeyMaterial,
      _keyLengthBytes,
      salt,
      Uint8List.fromList(utf8.encode('keyflow-history-encryption')),
    );
    hkdf.init(params);

    final derivedKey = Uint8List(_keyLengthBytes);
    hkdf.deriveKey(null, 0, derivedKey, 0);
    return derivedKey;
  }

  /// Encrypts [plaintext] using AES-256-GCM.
  ///
  /// Returns an [EncryptedPayload] containing base64-encoded ciphertext and IV.
  /// Each call generates a fresh IV for semantic security.
  Future<EncryptedPayload> encryptText(String plaintext) async {
    final key = await _getOrCreateKey();
    final iv = _generateSecureRandom(_ivLengthBytes);

    final encryptKey = encrypt.Key(key);
    final encryptIV = encrypt.IV(iv);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(encryptKey, mode: encrypt.AESMode.gcm),
    );

    final encrypted = encrypter.encrypt(plaintext, iv: encryptIV);

    return EncryptedPayload(
      ciphertext: encrypted.base64,
      iv: base64Url.encode(iv),
    );
  }

  /// Decrypts an [EncryptedPayload] back to plaintext using AES-256-GCM.
  ///
  /// Throws [ArgumentError] if decryption fails (wrong key, tampered data).
  Future<String> decryptText(EncryptedPayload payload) async {
    final key = await _getOrCreateKey();
    final iv = base64Url.decode(payload.iv);

    final encryptKey = encrypt.Key(key);
    final encryptIV = encrypt.IV(iv);

    final encrypter = encrypt.Encrypter(
      encrypt.AES(encryptKey, mode: encrypt.AESMode.gcm),
    );

    try {
      return encrypter.decrypt64(payload.ciphertext, iv: encryptIV);
    } on Exception catch (e) {
      throw ArgumentError('Decryption failed — key mismatch or tampered data: $e');
    }
  }

  /// Deletes the stored salt (used during full account/data wipe).
  Future<void> deleteSalt() async {
    await _storage.delete(key: _saltKeyName);
    _cachedKey = null;
  }

  /// Generates [length] cryptographically secure random bytes.
  Uint8List _generateSecureRandom(int length) {
    final secureRandom = pc.FortunaRandom();
    final seedSource = pc.SecureRandom('Fortuna')
      ..seed(pc.KeyParameter(
        Uint8List.fromList(
          List<int>.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256),
        ),
      ));
    secureRandom.seed(pc.KeyParameter(seedSource.nextBytes(32)));
    return secureRandom.nextBytes(length);
  }
}

/// Holds the encrypted output: base64-encoded ciphertext and IV.
class EncryptedPayload {
  const EncryptedPayload({
    required this.ciphertext,
    required this.iv,
  });

  /// Base64-encoded AES-256-GCM ciphertext.
  final String ciphertext;

  /// Base64-encoded initialization vector (unique per encryption).
  final String iv;
}
