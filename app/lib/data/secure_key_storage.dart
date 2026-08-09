import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages encryption key generation and storage via [FlutterSecureStorage].
class SecureKeyStorage {
  SecureKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _dbKeyName = 'keyflow_db_encryption_key';

  /// Retrieves existing encryption key or generates new key, handling Keystore corruption safely.
  Future<String> getOrCreateDatabaseKey() async {
    try {
      final existingKey = await _storage.read(key: _dbKeyName);
      if (existingKey != null && existingKey.isNotEmpty) {
        return existingKey;
      }
    } on Object catch (_) {
      try {
        await _storage.deleteAll();
      } on Object catch (_) {}
    }

    final newKey = _generate256BitKey();
    try {
      await _storage.write(key: _dbKeyName, value: newKey);
    } on Object catch (_) {}
    return newKey;
  }

  Future<void> deleteDatabaseKey() async {
    try {
      await _storage.delete(key: _dbKeyName);
    } on Object catch (_) {}
  }

  String _generate256BitKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }
}
