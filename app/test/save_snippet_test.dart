import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/history/history_providers.dart';
import 'package:keyflow_app/features/history/save_snippet_dialog.dart';

import 'capture_service_test.dart' show MockHistoryRepository;

class ControlledHistoryRepository extends MockHistoryRepository {
  Completer<void> write = Completer<void>();
  final attempts = <HistoryEntry>[];

  @override
  Future<void> addEntry(HistoryEntry entry) async {
    attempts.add(entry);
    await write.future;
    await super.addEntry(entry);
  }
}

void main() {
  testWidgets(
    'manual save validates, rolls back, and retries with the same id',
    (tester) async {
      final repository = ControlledHistoryRepository();
      final container = ProviderContainer(
        overrides: [historyRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => SaveSnippetDialog.show(context),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Enter or paste text to save.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'password: example');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(repository.attempts, isEmpty);

      const snippet = '  First line\nSecond line 👋  ';
      await tester.enterText(find.byType(TextField), snippet);
      await tester.tap(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(repository.attempts, hasLength(1));
      expect(container.read(pendingSnippetsProvider).single.text, snippet);
      repository.write.completeError(StateError('test storage error'));
      await tester.pump();
      expect(container.read(pendingSnippetsProvider), isEmpty);
      expect(
        find.text('Could not save your snippet. Please try again.'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        snippet,
      );

      repository.write = Completer<void>();
      await tester.tap(find.text('Save'));
      repository.write.complete();
      await tester.pumpAndSettle();
      expect(repository.attempts.last.id, repository.attempts.first.id);
      expect(repository.entries.single.text, snippet);
      expect(container.read(pendingSnippetsProvider), isEmpty);
      expect(find.text('Snippet saved'), findsOneWidget);
    },
  );
}
