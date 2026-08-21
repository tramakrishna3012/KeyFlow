import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure token storage adapter backed by [FlutterSecureStorage] (Keystore/Keychain).
///
/// Ensures JWTs, refresh tokens, and session credentials are never stored in plaintext
/// in standard SharedPreferences / UserDefaults.
class SecureAuthStorage extends LocalStorage {
  SecureAuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;
  static const String _sessionKey = 'supabase_auth_token';

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async {
    final token = await _storage.read(key: _sessionKey);
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> accessToken() => _storage.read(key: _sessionKey);

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(key: _sessionKey, value: persistSessionString);
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: _sessionKey);
  }
}
