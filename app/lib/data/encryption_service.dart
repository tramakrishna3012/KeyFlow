import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/export.dart' as pc;

class EncryptionService {
  EncryptionService({required this._userId, FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final String _userId;
  final FlutterSecureStorage _storage;

  String get userId => _userId;


  static const String _saltKeyName = 'keyflow_encryption_salt';
  static const int _keyLengthBytes = 32;
  static const int _ivLengthBytes = 12;

  Uint8List? _cachedKey;

  Future<Uint8List> _getOrCreateKey() async {
    if (_cachedKey != null) return _cachedKey!;

    Uint8List salt;
    try {
      final existingSalt = await _storage.read(key: _saltKeyName);
      if (existingSalt != null && existingSalt.isNotEmpty) {
        salt = base64Url.decode(existingSalt);
      } else {
        salt = _generateSecureRandom(_keyLengthBytes);
        try {
          await _storage.write(
            key: _saltKeyName,
            value: base64Url.encode(salt),
          );
        } on Object catch (_) {}
      }
    } on Object catch (_) {
      salt = _generateSecureRandom(_keyLengthBytes);
      try {
        await _storage.write(key: _saltKeyName, value: base64Url.encode(salt));
      } on Object catch (_) {}
    }

    _cachedKey = _deriveKey(Uint8List.fromList(utf8.encode(_userId)), salt);
    return _cachedKey!;
  }

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
      throw ArgumentError(
        'Decryption failed — key mismatch or tampered data: $e',
      );
    }
  }

  Future<void> deleteSalt() async {
    try {
      await _storage.delete(key: _saltKeyName);
    } on Object catch (_) {}
    _cachedKey = null;
  }

  Uint8List _generateSecureRandom(int length) {
    final random = Random.secure();
    final values = Uint8List(length);
    for (var i = 0; i < length; i++) {
      values[i] = random.nextInt(256);
    }
    return values;
  }
}

class EncryptedPayload {
  const EncryptedPayload({required this.ciphertext, required this.iv});

  final String ciphertext;
  final String iv;
}
