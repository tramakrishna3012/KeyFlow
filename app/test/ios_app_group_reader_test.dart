import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/history_repository.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/features/capture/ios_app_group_reader.dart';

class TestHistoryRepository implements HistoryRepository {
  final List<HistoryEntry> entries = [];
  final Map<String, String> settings = {};

  @override
  Future<void> addEntry(HistoryEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<void> insertEntry(HistoryEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<List<HistoryEntry>> getAllEntries() async => entries;

  @override
  Future<List<HistoryEntry>> search(String query) async => entries;

  @override
  Future<List<HistoryEntry>> searchEntries(
    String query, {
    String? appName,
  }) async => entries;

  @override
  Future<HistoryEntry?> getEntry(String id) async => null;

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<void> deleteAllEntries() async {
    entries.clear();
  }

  @override
  Future<void> clearAll() async {
    entries.clear();
  }

  @override
  Future<int> purgeOlderThan(int days) async => 0;

  @override
  Future<String> exportAll() async => '';

  @override
  Future<int> count() async => entries.length;

  @override
  Future<String?> getSetting(String key) async => settings[key];

  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }

  @override
  Future<List<String>> getExclusionList() async => [];

  @override
  Future<void> addExclusion(String appIdentifier) async {}

  @override
  Future<void> removeExclusion(String appIdentifier) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestHistoryRepository repository;
  late IosAppGroupReader reader;
  late Directory tempDir;

  setUp(() async {
    repository = TestHistoryRepository();
    reader = IosAppGroupReader(repository);
    tempDir = await Directory.systemTemp.createTemp('keyflow_ios_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'parseAppGroupPayload correctly parses JSON entries from keyboard extension',
    () {
      const rawJson = '''
    [
      {
        "id": "test_1",
        "text": "Hello from iOS Keyboard",
        "source_app": "Safari",
        "captured_at": 1721836800000,
        "language": "en",
        "was_translated": false,
        "device_id": "ios_keyboard"
      }
    ]
    ''';

      final parsed = IosAppGroupReader.parseAppGroupPayload(rawJson);
      expect(parsed.length, equals(1));
      expect(parsed.first.id, equals('test_1'));
      expect(parsed.first.text, equals('Hello from iOS Keyboard'));
      expect(parsed.first.sourceApp, equals('Safari'));
    },
  );

  test(
    'syncPendingEntries reads file from App Group directory and inserts into repository',
    () async {
      final pendingFile = File(
        '${tempDir.path}/${IosAppGroupReader.pendingFilename}',
      );
      const rawJson = '''
    [
      {
        "id": "entry_ios_1",
        "text": "Typed in Messages app",
        "source_app": "com.apple.MobileSMS",
        "captured_at": 1721836800000,
        "language": "en",
        "was_translated": false,
        "device_id": "ios_keyboard_extension"
      }
    ]
    ''';
      await pendingFile.writeAsString(rawJson);

      final count = await reader.syncPendingEntries(
        customGroupPath: tempDir.path,
      );
      expect(count, equals(1));
      expect(repository.entries.length, equals(1));
      expect(repository.entries.first.text, equals('Typed in Messages app'));

      // File content should be reset to empty array after sync
      final remaining = await pendingFile.readAsString();
      expect(remaining, equals('[]'));
    },
  );
}
