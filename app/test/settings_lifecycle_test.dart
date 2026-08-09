import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/settings/settings_providers.dart';
import 'history_repository_test.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryHistoryRepository mockRepo;

  setUp(() {
    mockRepo = InMemoryHistoryRepository();
  });

  test('Export Data produces a complete, correct JSON snapshot of current History (SRS FR-21)', () async {
    final entry1 = HistoryEntry(
      id: 'exp_1',
      text: 'Export test text snippet 1',
      sourceApp: 'Chrome',
      capturedAt: DateTime(2026, 7, 24, 10),
    );
    final entry2 = HistoryEntry(
      id: 'exp_2',
      text: 'Export test text snippet 2',
      sourceApp: 'VSCode',
      capturedAt: DateTime(2026, 7, 24, 11),
    );

    await mockRepo.addEntry(entry1);
    await mockRepo.addEntry(entry2);

    final container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );

    final controller = container.read(settingsControllerProvider);
    final jsonOutput = await controller.exportHistoryData();

    final decoded = jsonDecode(jsonOutput) as List<dynamic>;
    expect(decoded.length, equals(2));
    expect(decoded[0]['id'], equals('exp_1'));
    expect(decoded[0]['text'], equals('Export test text snippet 1'));
    expect(decoded[1]['id'], equals('exp_2'));
    expect(decoded[1]['text'], equals('Export test text snippet 2'));
  });

  test('Delete All Data is immediate and clears repository (SRS FR-9, FR-21)', () async {
    await mockRepo.addEntry(
      HistoryEntry(
        id: 'del_1',
        text: 'Text to be deleted',
        sourceApp: 'Notepad',
        capturedAt: DateTime.now(),
      ),
    );

    expect(await mockRepo.count(), equals(1));

    final container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );

    final controller = container.read(settingsControllerProvider);
    await controller.deleteAllHistoryData();

    expect(await mockRepo.count(), equals(0));
  });
}
