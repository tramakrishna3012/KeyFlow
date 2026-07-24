import 'package:flutter_test/flutter_test.dart';

import 'package:keyflow_app/data/history_repository.dart';
import 'package:keyflow_app/data/models/history_entry.dart';

/// A simple in-memory implementation for testing purposes.
class InMemoryHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> _entries = [];

  @override
  Future<List<HistoryEntry>> getAllEntries() async =>
      List.unmodifiable(_entries.reversed.toList());

  @override
  Future<List<HistoryEntry>> search(String query) async => _entries
      .where(
        (e) => e.text.toLowerCase().contains(query.toLowerCase()),
      )
      .toList()
      .reversed
      .toList();

  @override
  Future<HistoryEntry?> getEntry(String id) async {
    final matches = _entries.where((e) => e.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<void> insertEntry(HistoryEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> deleteAllEntries() async {
    _entries.clear();
  }

  @override
  Future<int> purgeOlderThan(int retentionDays) async {
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    final before = _entries.length;
    _entries.removeWhere((e) => e.capturedAt.isBefore(cutoff));
    return before - _entries.length;
  }

  @override
  Future<List<HistoryEntry>> searchEntries(String query) => search(query);

  @override
  Future<void> addEntry(HistoryEntry entry) => insertEntry(entry);

  @override
  Future<void> clearAll() => deleteAllEntries();

  @override
  Future<String> exportAll() async =>
      _entries.map((e) => '${e.capturedAt.toIso8601String()}\t${e.text}').join('\n');

  @override
  Future<int> count() async => _entries.length;

  final List<String> _exclusions = [];

  @override
  Future<List<String>> getExclusionList() async => List.unmodifiable(_exclusions);

  @override
  Future<void> addExclusion(String appIdentifier) async {
    _exclusions.add(appIdentifier);
  }

  @override
  Future<void> removeExclusion(String appIdentifier) async {
    _exclusions.remove(appIdentifier);
  }
}

void main() {
  late InMemoryHistoryRepository repo;

  setUp(() {
    repo = InMemoryHistoryRepository();
  });

  group('HistoryRepository contract', () {
    test('starts empty', () async {
      expect(await repo.count(), 0);
      expect(await repo.getAllEntries(), isEmpty);
    });

    test('insertEntry and getEntry round-trip', () async {
      final entry = HistoryEntry(
        id: '1',
        text: 'Hello world',
        sourceApp: 'com.example.mail',
        capturedAt: DateTime.now(),
      );
      await repo.insertEntry(entry);

      expect(await repo.count(), 1);
      final fetched = await repo.getEntry('1');
      expect(fetched, isNotNull);
      expect(fetched!.text, 'Hello world');
    });

    test('search finds matching entries', () async {
      await repo.insertEntry(HistoryEntry(
        id: '1',
        text: 'Thanks for reaching out',
        sourceApp: 'mail',
        capturedAt: DateTime.now(),
      ));
      await repo.insertEntry(HistoryEntry(
        id: '2',
        text: 'Please find attached',
        sourceApp: 'mail',
        capturedAt: DateTime.now(),
      ));

      final results = await repo.search('reaching');
      expect(results, hasLength(1));
      expect(results.first.id, '1');
    });

    test('search is case-insensitive', () async {
      await repo.insertEntry(HistoryEntry(
        id: '1',
        text: 'Hello World',
        sourceApp: 'chat',
        capturedAt: DateTime.now(),
      ));

      expect(await repo.search('hello'), hasLength(1));
      expect(await repo.search('HELLO'), hasLength(1));
    });

    test('deleteEntry removes only the targeted entry', () async {
      await repo.insertEntry(HistoryEntry(
        id: '1',
        text: 'First',
        sourceApp: 'app',
        capturedAt: DateTime.now(),
      ));
      await repo.insertEntry(HistoryEntry(
        id: '2',
        text: 'Second',
        sourceApp: 'app',
        capturedAt: DateTime.now(),
      ));

      await repo.deleteEntry('1');
      expect(await repo.count(), 1);
      expect(await repo.getEntry('1'), isNull);
      expect(await repo.getEntry('2'), isNotNull);
    });

    test('deleteAllEntries clears everything', () async {
      for (var i = 0; i < 5; i++) {
        await repo.insertEntry(HistoryEntry(
          id: '$i',
          text: 'Entry $i',
          sourceApp: 'app',
          capturedAt: DateTime.now(),
        ));
      }

      await repo.deleteAllEntries();
      expect(await repo.count(), 0);
    });

    test('purgeOlderThan removes expired entries', () async {
      final old = DateTime.now().subtract(const Duration(days: 45));
      final recent = DateTime.now();

      await repo.insertEntry(HistoryEntry(
        id: 'old',
        text: 'Expired entry',
        sourceApp: 'app',
        capturedAt: old,
      ));
      await repo.insertEntry(HistoryEntry(
        id: 'new',
        text: 'Recent entry',
        sourceApp: 'app',
        capturedAt: recent,
      ));

      final purged = await repo.purgeOlderThan(30);
      expect(purged, 1);
      expect(await repo.count(), 1);
      expect(await repo.getEntry('old'), isNull);
      expect(await repo.getEntry('new'), isNotNull);
    });

    test('exportAll includes all entries', () async {
      await repo.insertEntry(HistoryEntry(
        id: '1',
        text: 'Entry one',
        sourceApp: 'app',
        capturedAt: DateTime(2026, 7, 1),
      ));
      await repo.insertEntry(HistoryEntry(
        id: '2',
        text: 'Entry two',
        sourceApp: 'app',
        capturedAt: DateTime(2026, 7, 2),
      ));

      final exported = await repo.exportAll();
      expect(exported, contains('Entry one'));
      expect(exported, contains('Entry two'));
    });

    test('getAllEntries returns in reverse-chronological order', () async {
      await repo.insertEntry(HistoryEntry(
        id: '1',
        text: 'First',
        sourceApp: 'app',
        capturedAt: DateTime(2026, 7, 1),
      ));
      await repo.insertEntry(HistoryEntry(
        id: '2',
        text: 'Second',
        sourceApp: 'app',
        capturedAt: DateTime(2026, 7, 2),
      ));

      final all = await repo.getAllEntries();
      expect(all.first.id, '2');
      expect(all.last.id, '1');
    });

    test('getEntry returns null for non-existent id', () async {
      expect(await repo.getEntry('nonexistent'), isNull);
    });
  });

  group('HistoryEntry model', () {
    test('copyWith creates modified copy', () {
      final entry = HistoryEntry(
        id: '1',
        text: 'Original',
        sourceApp: 'app',
        capturedAt: DateTime(2026, 7, 1),
      );

      final modified = entry.copyWith(text: 'Modified');
      expect(modified.text, 'Modified');
      expect(modified.id, '1');
      expect(modified.sourceApp, 'app');
    });

    test('equality is based on id', () {
      final a = HistoryEntry(
        id: '1',
        text: 'Text A',
        sourceApp: 'app',
        capturedAt: DateTime(2026, 7, 1),
      );
      final b = HistoryEntry(
        id: '1',
        text: 'Text B',
        sourceApp: 'other',
        capturedAt: DateTime(2026, 7, 2),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
