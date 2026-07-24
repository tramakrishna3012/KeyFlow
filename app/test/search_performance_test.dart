import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/database_helper.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/data/secure_key_storage.dart';
import 'package:keyflow_app/data/sqlite_history_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestKeyStorage implements SecureKeyStorage {
  @override
  Future<String> getOrCreateDatabaseKey() async => 'test_performance_key_12345';
  @override
  Future<void> deleteDatabaseKey() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop testing
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tempDir;
  late SqliteHistoryRepository repository;
  late DatabaseHelper dbHelper;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('keyflow_perf_test');
    dbHelper = DatabaseHelper(
      customPath: '${tempDir.path}/perf_test.db',
      databaseFactoryOverride: databaseFactoryFfi,
    );
    repository = SqliteHistoryRepository(
      dbHelper: dbHelper,
      keyStorage: TestKeyStorage(),
    );
  });

  tearDown(() async {
    await dbHelper.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('SRS §3.2 Performance Requirement: searchEntries completes in < 200ms', () async {
    // Seed database with 2,000 history entries
    final now = DateTime.now();
    const batchSize = 500;
    const totalEntries = 2000;

    final apps = ['Notepad', 'Chrome', 'VSCode', 'Slack', 'Terminal'];
    final samplePhrases = [
      'Meeting scheduled for tomorrow at 10 AM',
      'Please review the attached pull request for review',
      'Here is the secret API key configuration details',
      'Thanks for reaching out to customer support',
      'Quick update on the project roadmap deliverable',
    ];

    for (int i = 0; i < totalEntries; i += batchSize) {
      final entriesBatch = <HistoryEntry>[];
      for (int j = 0; j < batchSize; j++) {
        final idx = i + j;
        entriesBatch.add(
          HistoryEntry(
            id: 'perf_$idx',
            text: '${samplePhrases[idx % samplePhrases.length]} #$idx',
            sourceApp: apps[idx % apps.length],
            capturedAt: now.subtract(Duration(minutes: idx)),
            language: 'en',
            wasTranslated: idx % 10 == 0,
            deviceId: 'test_device',
          ),
        );
      }
      for (final e in entriesBatch) {
        await repository.addEntry(e);
      }
    }

    final totalCount = await repository.count();
    expect(totalCount, equals(totalEntries));

    // Benchmark search execution speed
    final stopwatch = Stopwatch()..start();
    final results = await repository.searchEntries('roadmap');
    stopwatch.stop();

    print('Search for "roadmap" returned ${results.length} results in ${stopwatch.elapsedMilliseconds} ms');

    // SRS §3.2 Requirement: Search must complete in under 200ms
    expect(stopwatch.elapsedMilliseconds, lessThan(200), reason: 'Search performance exceeded 200ms threshold');
    expect(results.isNotEmpty, isTrue);
  });
}
