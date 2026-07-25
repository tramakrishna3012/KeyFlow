import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/emoji/emoji_service.dart';
import 'package:keyflow_app/features/emoji/emoji_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'history_repository_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Emoji Search Engine Performance & Correctness (SRS FR-13, FR-14)', () {
    test('Searching "fire" yields 🔥 in under 10ms', () {
      const service = EmojiService();

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 100; i++) {
        final results = service.searchEmojis('fire');
        expect(results, isNotEmpty);
        expect(results.first.char, equals('🔥'));
      }

      stopwatch.stop();

      print('Total execution time for 100 emoji searches: ${stopwatch.elapsedMilliseconds} ms');

      // SRS Requirement: Search completes under 10ms per lookup
      expect(stopwatch.elapsedMilliseconds, lessThan(100), reason: 'Emoji search latency exceeded threshold');
    });

    test('Shortcode lookup returns matching emoji', () {
      const service = EmojiService();

      final rocketResults = service.searchEmojis(':rocket:');
      expect(rocketResults, isNotEmpty);
      expect(rocketResults.first.char, equals('🚀'));

      final heartResults = service.searchEmojis('heart');
      expect(heartResults, isNotEmpty);
      expect(heartResults.any((e) => e.char == '❤️'), isTrue);
    });

    test('Recently used emoji updates immediately upon selection', () async {
      final mockRepo = InMemoryHistoryRepository();
      final container = ProviderContainer(
        overrides: [
          historyRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );

      final notifier = container.read(emojiNotifierProvider);
      await notifier.useEmoji('🚀');

      final recents = await container.read(recentEmojisProvider.future);
      expect(recents.first, equals('🚀'));
    });
  });
}
