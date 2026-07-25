import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/capture/capture_service.dart';
import 'package:keyflow_app/features/history/history_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'history_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyFlow E2E Smoke Pipeline Tests', () {
    test('E2E Pipeline: Mock Capture Stream -> DB Write -> History Search -> UI Provider Result', () async {
      final mockRepo = InMemoryHistoryRepository();

      final container = ProviderContainer(
        overrides: [
          historyRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final captureService = container.read(captureServiceProvider);

      // 1. Initialize capture engine and sync exclusions
      await captureService.initialize();
      expect(captureService.isCapturing, isTrue);

      // 2. Simulate incoming text capture event from native layer
      final capturedEntry = HistoryEntry(
        id: 'e2e-test-entry-1',
        text: 'The quick brown fox jumps over the lazy dog in KeyFlow E2E',
        capturedAt: DateTime.now(),
        sourceApp: 'code.exe',
      );

      await mockRepo.addEntry(capturedEntry);

      // 3. Set search query in history provider
      container.read(searchQueryProvider.notifier).state = 'fox jumps';

      // 4. Query search results via history provider
      final List<HistoryEntry> searchResults = await container.read(historyEntriesProvider.future);

      // 5. Verify E2E query returned captured entry
      expect(searchResults, isNotEmpty);
      expect(searchResults.first.id, equals('e2e-test-entry-1'));
      expect(searchResults.first.text, contains('fox jumps'));
      expect(searchResults.first.sourceApp, equals('code.exe'));
    });
  });
}
