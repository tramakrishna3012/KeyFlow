import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/settings/settings_providers.dart';
import 'package:keyflow_app/features/settings/settings_screen.dart';
import 'history_repository_test.dart';

void main() {
  testWidgets(
    'SettingsScreen displays Quick Accessibility Toggle with helper text and paused banner',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = InMemoryHistoryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [historyRepositoryProvider.overrideWithValue(mockRepo)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify section header and toggle title
      expect(find.text('TYPING CAPTURE CONTROL'), findsOneWidget);
      expect(find.text('Pause Typing Capture'), findsOneWidget);

      // Verify exact required helper text
      expect(
        find.text(
          'Turn this off before using banking or payment apps that block accessibility services, then back on when done.',
        ),
        findsOneWidget,
      );

      // Verify accessibility settings deep-link
      expect(find.text('Open Android Accessibility Settings'), findsOneWidget);
    },
  );

  testWidgets('When paused, status banner is displayed in SettingsScreen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final mockRepo = InMemoryHistoryRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(mockRepo),
          capturePausedProvider.overrideWith((ref) => MockPausedNotifier(true)),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Verify warning status banner when paused
    expect(
      find.text('Capture is paused. Keystrokes are not being recorded.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}

class MockPausedNotifier extends StateNotifier<bool>
    implements CapturePausedNotifier {
  MockPausedNotifier(super.state);

  @override
  Future<void> togglePause() async {
    state = !state;
  }

  @override
  Future<void> setPaused(bool paused) async {
    state = paused;
  }

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<void> syncWithNative() async {}
}
