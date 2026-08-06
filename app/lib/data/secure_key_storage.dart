import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages encryption key generation and storage via [FlutterSecureStorage].
///
/// Under the hood, [FlutterSecureStorage] uses:
/// - Windows: Windows Credential Manager
/// - macOS/iOS: Keychain
/// - Android: EncryptedSharedPreferences / Android Keystore
///
/// The encryption key is NEVER stored in plain text or written to the database file itself.
class SecureKeyStorage {
  SecureKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _dbKeyName = 'keyflow_db_encryption_key';

  /// Retrieves the existing database encryption key or generates a new 256-bit key on first run.
  ///
  /// Handles Android Keystore corruption (e.g. BAD_DECRYPT after app update/reinstall)
  /// gracefully by resetting corrupted keys rather than crashing.
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

  /// Deletes the stored key (e.g. during full application wipe).
  Future<void> deleteDatabaseKey() async {
    try {
      await _storage.delete(key: _dbKeyName);
    } on Object catch (_) {}
  }

  /// Generates a cryptographically secure 256-bit (32-byte) hex string.
  String _generate256BitKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(values);
  }
}
