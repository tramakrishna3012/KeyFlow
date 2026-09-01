import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/features/capture/session_aggregator.dart';

void main() {
  group('DartSessionAggregator Tests', () {
    test(
      'Groups typing keystrokes into persistent paragraph session',
      () async {
        AggregatedTypingSession? lastUpdated;
        final aggregator = DartSessionAggregator(
          inactivityDebounceMs: 100,
          sessionTimeoutMs: 1000,
          onSessionUpdate: (s) => lastUpdated = s,
        );

        final session1 = aggregator.handleTypingInput(
          appName: 'Chrome',
          windowTitle: 'Google Docs',
          deviceName: 'Motorola Edge 40',
          text: 'First draft sentence.',
        );

        expect(session1, isNotNull);
        expect(session1!.wordCount, equals(3));
        expect(session1.characterCount, equals(21));

        // Continuous typing in same app updates existing session ID
        final session2 = aggregator.handleTypingInput(
          appName: 'Chrome',
          windowTitle: 'Google Docs',
          deviceName: 'Motorola Edge 40',
          text: 'First draft sentence. Second paragraph added.',
        );

        expect(session2!.id, equals(session1.id));
        expect(session2.wordCount, equals(6));

        // Wait for debounce timer
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(lastUpdated, isNotNull);
        expect(lastUpdated!.id, equals(session1.id));
        expect(
          lastUpdated!.content,
          equals('First draft sentence. Second paragraph added.'),
        );

        aggregator.dispose();
      },
    );

    test(
      'Excludes password and sensitive inputs while allowing calculator',
      () {
        final aggregator = DartSessionAggregator();

        // Password excluded
        final passSession = aggregator.handleTypingInput(
          appName: 'Chrome',
          windowTitle: 'Login Screen',
          text: 'SecretPass123!',
          isPasswordField: true,
        );
        expect(passSession, isNull);

        // Banking window title excluded
        final bankSession = aggregator.handleTypingInput(
          appName: 'Chrome',
          windowTitle: 'Chase Banking - Card Details',
          text: '4111 2222 3333 4444',
        );
        expect(bankSession, isNull);

        // Calculator allowed
        final calcSession = aggregator.handleTypingInput(
          appName: 'Calculator',
          windowTitle: 'Calculator',
          text: '45000 + 15000 = 60000',
        );
        expect(calcSession, isNotNull);
        expect(calcSession!.content, equals('45000 + 15000 = 60000'));

        aggregator.dispose();
      },
    );
  });
}
