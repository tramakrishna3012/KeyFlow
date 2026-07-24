import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/database_helper.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/data/retention_service.dart';
import 'package:keyflow_app/data/secure_key_storage.dart';
import 'package:keyflow_app/data/sqlite_history_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Setup FFI database factory for headless unit tests
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late String dbPath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('keyflow_test_');
    dbPath = p.join(tempDir.path, 'test_keyflow_encrypted.db');
    FlutterSecureStorage.setMockInitialValues({});
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Encrypted Storage & Security Tests (SRS FR-6, Security S-1)', () {
    test('Key generation on first run stored securely via FlutterSecureStorage', () async {
      const mockStorage = FlutterSecureStorage();
      final keyStorage = SecureKeyStorage(storage: mockStorage);

      // Key should not exist initially
      final initialRead = await mockStorage.read(key: 'keyflow_db_encryption_key');
      expect(initialRead, isNull);

      // Generating key stores it
      final generatedKey = await keyStorage.getOrCreateDatabaseKey();
      expect(generatedKey, isNotEmpty);

      // Subsequent call retrieves the SAME key
      final retrievedKey = await keyStorage.getOrCreateDatabaseKey();
      expect(retrievedKey, equals(generatedKey));
    });

    test('Entries are encrypted at rest and unreadable without key', () async {
      const dbPasscode = 'SuperSecretEncryptionKey123!';
      final dbHelper = DatabaseHelper(customPath: dbPath);

      const sensitiveText = 'SECRET_PAYROLL_DATA_CONFIDENTIAL_12345';
      final entry = HistoryEntry(
        id: 'sec-1',
        text: sensitiveText,
        sourceApp: 'com.acme.finance',
        capturedAt: DateTime.now(),
      );

      // Initialize DB with correct key and insert entry
      final db = await dbHelper.getDatabase(dbPasscode);
      await db.insert('history_entries', {
        'id': entry.id,
        'text': entry.text,
        'source_app': entry.sourceApp,
        'captured_at': entry.capturedAt.millisecondsSinceEpoch,
        'language': entry.language,
        'was_translated': 0,
        'use_count': 0,
      });

      await dbHelper.close();

      // Verify the raw database file on disk does NOT contain the plaintext string in raw bytes
      final dbBytes = File(dbPath).readAsBytesSync();
      final dbContentString = String.fromCharCodes(dbBytes);

      // Plaintext captured text must never appear as cleartext in raw database bytes
      expect(dbContentString.contains(sensitiveText), isFalse);

      // Opening with WRONG key fails
      expect(
        () async => openDatabase(dbPath, password: 'WrongPassword456!'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('Retention Purge Job Tests (SRS FR-10)', () {
    test('purgeOlderThan removes ONLY entries older than configured retention window', () async {
      const dbPasscode = 'RetentionTestKey123!';
      final dbHelper = DatabaseHelper(customPath: dbPath);

      final repo = SqliteHistoryRepository(
        dbHelper: dbHelper,
        keyStorage: SecureKeyStorage(),
      );

      await dbHelper.getDatabase(dbPasscode);

      final now = DateTime.now();
      final day45Ago = now.subtract(const Duration(days: 45));
      final day35Ago = now.subtract(const Duration(days: 35));
      final day10Ago = now.subtract(const Duration(days: 10));
      final day1Ago = now.subtract(const Duration(days: 1));

      // Insert test entries spanning different ages
      await repo.insertEntry(HistoryEntry(
        id: 'old-45',
        text: 'Typed 45 days ago',
        sourceApp: 'email',
        capturedAt: day45Ago,
      ));

      await repo.insertEntry(HistoryEntry(
        id: 'old-35',
        text: 'Typed 35 days ago',
        sourceApp: 'chat',
        capturedAt: day35Ago,
      ));

      await repo.insertEntry(HistoryEntry(
        id: 'recent-10',
        text: 'Typed 10 days ago',
        sourceApp: 'doc',
        capturedAt: day10Ago,
      ));

      await repo.insertEntry(HistoryEntry(
        id: 'recent-1',
        text: 'Typed 1 day ago',
        sourceApp: 'browser',
        capturedAt: day1Ago,
      ));

      expect(await repo.count(), equals(4));

      // Run purge for 30 days retention
      final purged = await repo.purgeOlderThan(30);

      // 45-day and 35-day entries should be purged (2 entries)
      expect(purged, equals(2));
      expect(await repo.count(), equals(2));

      // Verify remaining entries
      expect(await repo.getEntry('old-45'), isNull);
      expect(await repo.getEntry('old-35'), isNull);
      expect(await repo.getEntry('recent-10'), isNotNull);
      expect(await repo.getEntry('recent-1'), isNotNull);
    });

    test('RetentionService reads settings and executes scheduled purge', () async {
      const dbPasscode = 'ServicePurgeTestKey!';
      final dbHelper = DatabaseHelper(customPath: dbPath);

      final repo = SqliteHistoryRepository(
        dbHelper: dbHelper,
        keyStorage: SecureKeyStorage(),
      );

      await dbHelper.getDatabase(dbPasscode);
      final retentionService = RetentionService(repository: repo);

      // Set custom retention to 7 days in settings table
      await repo.setSetting('retention_days', '7');

      final now = DateTime.now();
      await repo.insertEntry(HistoryEntry(
        id: 'entry-10d',
        text: '10 days old entry',
        sourceApp: 'notes',
        capturedAt: now.subtract(const Duration(days: 10)),
      ));

      await repo.insertEntry(HistoryEntry(
        id: 'entry-3d',
        text: '3 days old entry',
        sourceApp: 'notes',
        capturedAt: now.subtract(const Duration(days: 3)),
      ));

      // Execute retention service purge
      final purgedCount = await retentionService.runPurge();

      // 10-day entry purged based on 7-day retention setting
      expect(purgedCount, equals(1));
      expect(await repo.getEntry('entry-10d'), isNull);
      expect(await repo.getEntry('entry-3d'), isNotNull);
    });
  });

  group('HistoryRepository CRUD & Search Tests (SRS FR-6, FR-9)', () {
    test('addEntry, searchEntries, deleteEntry, clearAll contracts', () async {
      const dbPasscode = 'CrudTestPasscode!';
      final dbHelper = DatabaseHelper(customPath: dbPath);

      final repo = SqliteHistoryRepository(
        dbHelper: dbHelper,
        keyStorage: SecureKeyStorage(),
      );

      await dbHelper.getDatabase(dbPasscode);

      // addEntry
      final e1 = HistoryEntry(
        id: 'id-1',
        text: 'Quick brown fox jumps over lazy dog',
        sourceApp: 'com.apple.Mail',
        capturedAt: DateTime.now(),
        category: 'email',
      );

      final e2 = HistoryEntry(
        id: 'id-2',
        text: 'Meeting at 3pm tomorrow',
        sourceApp: 'com.slack.Slack',
        capturedAt: DateTime.now(),
        category: 'meeting',
      );

      await repo.addEntry(e1);
      await repo.addEntry(e2);

      expect(await repo.count(), equals(2));

      // searchEntries
      final searchResults = await repo.searchEntries('fox');
      expect(searchResults.length, equals(1));
      expect(searchResults.first.id, equals('id-1'));

      // deleteEntry
      await repo.deleteEntry('id-1');
      expect(await repo.count(), equals(1));
      expect(await repo.getEntry('id-1'), isNull);

      // clearAll
      await repo.clearAll();
      expect(await repo.count(), equals(0));
    });
  });
}
