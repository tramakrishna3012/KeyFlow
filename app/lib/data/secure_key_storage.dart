import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages encryption key generation and storage backed by the Android Hardware Keystore via [FlutterSecureStorage].
class SecureKeyStorage {
  SecureKeyStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const String _dbKeyName = 'keyflow_db_encryption_key';
  static const String _sessionKeyPrefix = 'keyflow_user_db_key_';

  /// Retrieves existing encryption key or generates new key, backed by Keystore and optional user session entropy.
  Future<String> getOrCreateDatabaseKey([String? userEntropy]) async {
    final keyName = (userEntropy != null && userEntropy.isNotEmpty)
        ? '$_sessionKeyPrefix${userEntropy.hashCode}'
        : _dbKeyName;

    try {
      final existingKey = await _storage.read(key: keyName);
      if (existingKey != null && existingKey.isNotEmpty) {
        return existingKey;
      }
    } on Object catch (_) {
      try {
        await _storage.deleteAll();
      } on Object catch (_) {}
    }

    final newKey = _generate256BitKey(userEntropy);
    try {
      await _storage.write(key: keyName, value: newKey);
    } on Object catch (_) {}
    return newKey;
  }

  Future<void> deleteDatabaseKey([String? userEntropy]) async {
    final keyName = (userEntropy != null && userEntropy.isNotEmpty)
        ? '$_sessionKeyPrefix${userEntropy.hashCode}'
        : _dbKeyName;
    try {
      await _storage.delete(key: keyName);
    } on Object catch (_) {}
  }

  String _generate256BitKey([String? entropy]) {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    if (entropy != null && entropy.isNotEmpty) {
      final entropyBytes = utf8.encode(entropy);
      for (var i = 0; i < values.length; i++) {
        values[i] = values[i] ^ entropyBytes[i % entropyBytes.length];
      }
    }
    return base64Url.encode(values);
  }
}
