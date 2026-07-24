import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/features/autocorrect/autocorrect_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AutocorrectEngine engine;

  setUp(() {
    engine = AutocorrectEngine();
  });

  group('Autocorrect Engine Performance & Correctness Tests (SRS FR-11, FR-12)', () {
    test('Levenshtein search returns top-3 suggestions in under 10ms', () {
      final testTypos = [
        'teh',
        'recieve',
        'problm',
        'meetiing',
        'schedle',
        'profect',
        'keyboar',
        'applicaton',
        'develpment',
        'implemntation',
      ];

      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 10; i++) {
        for (final typo in testTypos) {
          final suggestions = engine.getSuggestions(typo);
          expect(suggestions, isNotEmpty);
          expect(suggestions.length, lessThanOrEqualTo(3));
        }
      }

      stopwatch.stop();
      final avgMsPerLookup = stopwatch.elapsedMicroseconds / (100 * 1000.0);

      print('Total execution time for 100 lookups: ${stopwatch.elapsedMilliseconds} ms (${avgMsPerLookup.toStringAsFixed(2)} ms/lookup)');

      // SRS Requirement: Under 10ms latency per lookup
      expect(stopwatch.elapsedMilliseconds, lessThan(100), reason: 'Total 100 lookups exceeded 100ms threshold');
    });

    test('Learned words persist and are suggested with high priority', () {
      // Input custom word
      const customWord = 'KeyFlowApp';

      // Before learning, typo "keyflowap" does not yield customWord
      final initialSuggestions = engine.getSuggestions('keyflowap');
      expect(initialSuggestions.contains(customWord), isFalse);

      // Learn word
      engine.learnWord(customWord);

      // After learning, typo "keyflowap" yields customWord
      final learnedSuggestions = engine.getSuggestions('keyflowap');
      expect(learnedSuggestions, contains(customWord));
      expect(learnedSuggestions.first, equals(customWord));

      // Re-initialize engine with learned words set
      final newEngine = AutocorrectEngine(initialLearnedWords: engine.learnedWords);
      final persistedSuggestions = newEngine.getSuggestions('keyflowap');
      expect(persistedSuggestions, contains(customWord));
    });

    test('Per-app overrides disable suggestions for specific source applications', () {
      const appName = 'com.apple.Terminal';

      // Enabled by default
      expect(engine.getSuggestions('teh', sourceApp: appName), isNotEmpty);

      // Set override to false
      engine.setAppOverride(appName, false);
      expect(engine.getSuggestions('teh', sourceApp: appName), isEmpty);

      // Other apps still get suggestions
      expect(engine.getSuggestions('teh', sourceApp: 'com.google.Chrome'), isNotEmpty);
    });
  });
}
