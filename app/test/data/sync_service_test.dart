import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/data/supabase_history_repository.dart';
import 'package:keyflow_app/data/sync_service.dart';

/// A fake [SupabaseHistoryRepository] for testing sync behavior.
class FakeSupabaseHistoryRepository implements SupabaseHistoryRepository {
  final List<HistoryEntry> upsertedEntries = [];
  final List<String> deletedIds = [];
  bool allDeleted = false;
  bool shouldFail = false;
  int failCount = 0; // Number of times to fail before succeeding
  int _currentFailCount = 0;

  @override
  Future<void> upsertEntry(HistoryEntry entry) async {
    if (shouldFail || _currentFailCount < failCount) {
      _currentFailCount++;
      throw Exception('Simulated network failure');
    }
    upsertedEntries.add(entry);
  }

  @override
  Future<void> deleteEntry(String id) async {
    if (shouldFail) throw Exception('Simulated network failure');
    deletedIds.add(id);
  }

  @override
  Future<void> deleteAllEntries() async {
    if (shouldFail) throw Exception('Simulated network failure');
    allDeleted = true;
  }

  @override
  Future<List<HistoryEntry>> getAllEntries() async {
    if (shouldFail) throw Exception('Simulated network failure');
    return List.from(upsertedEntries);
  }

  @override
  Future<int> purgeOlderThan(int retentionDays) async {
    if (shouldFail) throw Exception('Simulated network failure');
    return 0;
  }

  @override
  Future<int> count() async {
    if (shouldFail) throw Exception('Simulated network failure');
    return upsertedEntries.length;
  }

  void reset() {
    upsertedEntries.clear();
    deletedIds.clear();
    allDeleted = false;
    shouldFail = false;
    failCount = 0;
    _currentFailCount = 0;
  }
}

HistoryEntry _makeEntry({
  String id = 'test-id-1',
  String text = 'Hello world',
  String sourceApp = 'com.test.app',
}) => HistoryEntry(
  id: id,
  text: text,
  sourceApp: sourceApp,
  capturedAt: DateTime(2024, 1, 15, 10, 30),
);

void main() {
  group('SyncService', () {
    late SyncService syncService;
    late FakeSupabaseHistoryRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeSupabaseHistoryRepository();
      syncService = SyncService(cloudRepo: fakeRepo);
    });

    tearDown(() {
      syncService.dispose();
    });

    test('syncEntry uploads entry to cloud repository', () async {
      final entry = _makeEntry();
      await syncService.syncEntry(entry);

      expect(fakeRepo.upsertedEntries, hasLength(1));
      expect(fakeRepo.upsertedEntries.first.id, equals('test-id-1'));
    });

    test('syncEntry queues for retry on failure', () async {
      fakeRepo.shouldFail = true;
      final entry = _makeEntry();

      await syncService.syncEntry(entry);

      expect(fakeRepo.upsertedEntries, isEmpty);
      expect(syncService.pendingRetryCount, equals(1));
    });

    test('deleteEntry removes entry from cloud', () async {
      await syncService.deleteEntry('test-id-1');

      expect(fakeRepo.deletedIds, contains('test-id-1'));
    });

    test('deleteEntry handles failure gracefully', () async {
      fakeRepo.shouldFail = true;

      // Should not throw
      await syncService.deleteEntry('test-id-1');

      expect(fakeRepo.deletedIds, isEmpty);
    });

    test('deleteAllEntries clears cloud entries', () async {
      await syncService.deleteAllEntries();

      expect(fakeRepo.allDeleted, isTrue);
    });

    test('pullFromCloud returns cloud entries', () async {
      fakeRepo.upsertedEntries.add(_makeEntry(id: 'cloud-1'));
      fakeRepo.upsertedEntries.add(_makeEntry(id: 'cloud-2'));

      final entries = await syncService.pullFromCloud();

      expect(entries, hasLength(2));
    });

    test('pullFromCloud returns empty list on failure', () async {
      fakeRepo.shouldFail = true;

      final entries = await syncService.pullFromCloud();

      expect(entries, isEmpty);
    });

    test('purgeCloudOlderThan delegates to cloud repo', () async {
      final purged = await syncService.purgeCloudOlderThan(30);

      expect(purged, equals(0));
    });

    test('multiple entries sync independently', () async {
      final entry1 = _makeEntry(id: 'entry-1', text: 'First');
      final entry2 = _makeEntry(id: 'entry-2', text: 'Second');
      final entry3 = _makeEntry(id: 'entry-3', text: 'Third');

      await syncService.syncEntry(entry1);
      await syncService.syncEntry(entry2);
      await syncService.syncEntry(entry3);

      expect(fakeRepo.upsertedEntries, hasLength(3));
      expect(
        fakeRepo.upsertedEntries.map((e) => e.id),
        containsAll(['entry-1', 'entry-2', 'entry-3']),
      );
    });

    test('dispose clears retry queue', () async {
      fakeRepo.shouldFail = true;
      await syncService.syncEntry(_makeEntry());

      expect(syncService.pendingRetryCount, equals(1));

      syncService.dispose();

      expect(syncService.pendingRetryCount, equals(0));
    });
  });
}
