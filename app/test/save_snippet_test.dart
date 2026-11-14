import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:keyflow_app/data/auth_service.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/data/models/user_model.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/history/history_providers.dart';
import 'package:keyflow_app/features/history/save_snippet_dialog.dart';
import 'package:uuid/uuid.dart';

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

class SyncTestAuth extends AuthService {
  final attempts = <HistoryEntry>[];

  @override
  String get token => 'test-session';

  @override
  bool get isAuthenticated => true;

  @override
  UserModel get currentUser => const UserModel(
    id: 'owner',
    email: 'owner@example.test',
    fullName: 'Owner',
  );

  @override
  Future<void> publishManualSnippet(
    HistoryEntry entry, {
    required String? ownerId,
  }) async {
    expect(ownerId, currentUser.id);
    attempts.add(entry);
    if (attempts.length == 1) {
      throw const SnippetSyncException('Dashboard sync failed. Try again.');
    }
  }
}

void main() {
  testWidgets('shared text is kept until a successful save or discard', (
    tester,
  ) async {
    final repository = ControlledHistoryRepository();
    final removals = <String>[];
    const channel = MethodChannel('com.keyflow.app/shared-snippets');
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'remove');
      removals.add(call.arguments as String);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final shared = HistoryEntry(
      id: const Uuid().v4(),
      text: 'A shared selection',
      sourceApp: 'Shared text',
      capturedAt: DateTime.utc(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [historyRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    SaveSnippetDialog.show(context, sharedSnippet: shared),
                child: const Text('Review'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text(shared.text), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(removals, isEmpty);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'password: example');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repository.attempts, isEmpty);
    expect(removals, isEmpty);

    const edited = 'Edited selection';
    await tester.enterText(find.byType(TextField), edited);
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(removals, isEmpty);
    repository.write.completeError(StateError('Test write failure'));
    await tester.pumpAndSettle();
    expect(removals, isEmpty);

    repository.write = Completer<void>();
    await tester.tap(find.text('Save'));
    repository.write.complete();
    await tester.pumpAndSettle();
    final saved = repository.entries.single;
    expect(saved.text, edited);
    expect(saved.id, shared.id);
    expect(saved.capturedAt, shared.capturedAt);
    expect(removals, [shared.id]);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(repository.entries, [saved]);
    expect(removals, [shared.id, shared.id]);
  });

  test(
    'publishing uses the signed-in account and the same id after failure',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'keyflow_jwt_token': 'test-session',
        'keyflow_user_data': jsonEncode({'id': 'owner'}),
      });
      final uploads = <http.Request>[];
      final auth = AuthService(
        apiBase: 'https://example.test/api/v1',
        httpClient: MockClient((request) async {
          if (request.method == 'GET') return http.Response('{}', 404);
          uploads.add(request);
          return http.Response('', uploads.length == 1 ? 503 : 204);
        }),
      );
      addTearDown(auth.dispose);
      await auth.initialize();
      final entry = HistoryEntry(
        id: 'test-snippet',
        text: 'An approved draft',
        sourceApp: 'Manual entry',
        capturedAt: DateTime.utc(2026),
      );
      await expectLater(
        auth.publishManualSnippet(entry, ownerId: 'other'),
        throwsA(isA<SnippetSyncException>()),
      );
      expect(uploads, isEmpty);
      await expectLater(
        auth.publishManualSnippet(entry, ownerId: 'owner'),
        throwsA(isA<SnippetSyncException>()),
      );
      await auth.publishManualSnippet(entry, ownerId: 'owner');
      expect(uploads, hasLength(2));
      expect(uploads.last.url, uploads.first.url);
      expect(uploads.last.body, uploads.first.body);
      expect(jsonDecode(uploads.last.body)['content'], entry.text);
      expect(uploads.last.headers['authorization'], 'Bearer test-session');
    },
  );

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

  testWidgets('Save & Sync keeps the local copy and retries the same snippet', (
    tester,
  ) async {
    final repository = MockHistoryRepository();
    final auth = SyncTestAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(repository),
          authServiceProvider.overrideWithValue(auth),
        ],
        child: const MaterialApp(home: Scaffold(body: SaveSnippetDialog())),
      ),
    );
    await tester.enterText(find.byType(TextField), 'An approved draft');
    await tester.tap(find.text('Save & Sync'));
    await tester.pumpAndSettle();
    expect(repository.entries, hasLength(1));
    expect(find.textContaining('Saved on this device'), findsOneWidget);
    await tester.tap(find.text('Retry Sync'));
    await tester.pumpAndSettle();
    expect(repository.entries, hasLength(1));
    expect(auth.attempts, [
      repository.entries.single,
      repository.entries.single,
    ]);
  });
}
