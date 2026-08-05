import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/encryption_service.dart';

/// A minimal in-memory fake of [FlutterSecureStorage] for testing.
///
/// Uses [noSuchMethod] to avoid breaking when the upstream interface adds
/// new members. Only read/write/delete/containsKey are implemented.
class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.remove(key);

  @override
  Future<bool> containsKey({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      _store.containsKey(key);
}

void main() {
  group('EncryptionService', () {
    late EncryptionService service;
    late FakeSecureStorage fakeStorage;

    setUp(() {
      fakeStorage = FakeSecureStorage();
      service = EncryptionService(
        userId: 'test-user-id-123',
        storage: fakeStorage,
      );
    });

    test('encrypt → decrypt round-trip returns original plaintext', () async {
      const plaintext = 'Hello, KeyFlow! This is a test message.';

      final encrypted = await service.encryptText(plaintext);
      final decrypted = await service.decryptText(encrypted);

      expect(decrypted, equals(plaintext));
    });

    test('encrypt → decrypt works with unicode text', () async {
      const plaintext = '你好世界 🌍 Привет мир';

      final encrypted = await service.encryptText(plaintext);
      final decrypted = await service.decryptText(encrypted);

      expect(decrypted, equals(plaintext));
    });

    test('encrypt → decrypt works with empty string', () async {
      const plaintext = '';

      final encrypted = await service.encryptText(plaintext);
      final decrypted = await service.decryptText(encrypted);

      expect(decrypted, equals(plaintext));
    });

    test('each encryption produces a unique IV', () async {
      const plaintext = 'Same text encrypted twice';

      final first = await service.encryptText(plaintext);
      final second = await service.encryptText(plaintext);

      // IVs should be different (semantic security)
      expect(first.iv, isNot(equals(second.iv)));
    });

    test('each encryption produces different ciphertext', () async {
      const plaintext = 'Same text encrypted twice';

      final first = await service.encryptText(plaintext);
      final second = await service.encryptText(plaintext);

      // Ciphertexts should differ due to different IVs
      expect(first.ciphertext, isNot(equals(second.ciphertext)));
    });

    test('ciphertext is not plaintext', () async {
      const plaintext = 'This should not appear in ciphertext';

      final encrypted = await service.encryptText(plaintext);

      // Ciphertext should not contain the original text
      expect(encrypted.ciphertext, isNot(contains(plaintext)));
    });

    test('decryption with wrong key throws ArgumentError', () async {
      const plaintext = 'Secret message';

      final encrypted = await service.encryptText(plaintext);

      // Create a different service with a different user ID → different key
      final otherStorage = FakeSecureStorage();
      final otherService = EncryptionService(
        userId: 'different-user-id-456',
        storage: otherStorage,
      );

      expect(
        () => otherService.decryptText(encrypted),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('salt is persisted and reused across instances', () async {
      const plaintext = 'Persistent key test';

      final encrypted = await service.encryptText(plaintext);

      // Create a new instance with the SAME storage and user ID
      final service2 = EncryptionService(
        userId: 'test-user-id-123',
        storage: fakeStorage,
      );

      // Should decrypt successfully with the persisted salt
      final decrypted = await service2.decryptText(encrypted);
      expect(decrypted, equals(plaintext));
    });

    test('deleteSalt clears cached key', () async {
      const plaintext = 'Before salt deletion';
      final encrypted = await service.encryptText(plaintext);

      await service.deleteSalt();

      // After deleting salt, a new salt will be generated,
      // and decryption of old data should fail
      expect(
        () => service.decryptText(encrypted),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
