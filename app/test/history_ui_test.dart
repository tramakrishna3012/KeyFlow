import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/history_repository.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/history/history_screen.dart';
import 'package:keyflow_app/features/history/snippet_detail_screen.dart';

class MockHistoryRepo implements HistoryRepository {
  final List<HistoryEntry> items = [
    HistoryEntry(
      id: 'h1',
      text: 'First captured snippet text',
      sourceApp: 'Notepad',
      capturedAt: DateTime.now(),
    ),
    HistoryEntry(
      id: 'h2',
      text: 'Second captured snippet text',
      sourceApp: 'Chrome',
      capturedAt: DateTime.now(),
    ),
  ];

  @override
  Future<void> addEntry(HistoryEntry entry) async {
    items.add(entry);
  }

  @override
  Future<void> insertEntry(HistoryEntry entry) async {
    items.add(entry);
  }

  @override
  Future<List<HistoryEntry>> getAllEntries() async => items;

  @override
  Future<List<HistoryEntry>> search(String query) async {
    if (query.isEmpty) return items;
    return items.where((e) => e.text.toLowerCase().contains(query.toLowerCase())).toList();
  }

  @override
  Future<List<HistoryEntry>> searchEntries(String query) async => search(query);

  @override
  Future<HistoryEntry?> getEntry(String id) async {
    final matches = items.where((e) => e.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  @override
  Future<void> deleteEntry(String id) async {
    items.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> deleteAllEntries() async {
    items.clear();
  }

  @override
  Future<void> clearAll() async {
    items.clear();
  }

  @override
  Future<int> purgeOlderThan(int days) async => 0;

  @override
  Future<String> exportAll() async => '';

  @override
  Future<int> count() async => items.length;

  @override
  Future<List<String>> getExclusionList() async => [];

  @override
  Future<void> addExclusion(String appIdentifier) async {}

  @override
  Future<void> removeExclusion(String appIdentifier) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HistoryScreen renders entries from repository', (WidgetTester tester) async {
    final mockRepo = MockHistoryRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: HistoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Snippet History'), findsOneWidget);
    expect(find.text('First captured snippet text'), findsOneWidget);
    expect(find.text('Second captured snippet text'), findsOneWidget);
  });

  testWidgets('SnippetDetailScreen renders full text and metadata', (WidgetTester tester) async {
    final entry = HistoryEntry(
      id: 'd1',
      text: 'Detailed snippet content for testing',
      sourceApp: 'VSCode',
      capturedAt: DateTime(2026, 7, 24, 12, 0),
      language: 'en',
      deviceId: 'desktop_win',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: SnippetDetailScreen(entry: entry),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Snippet Details'), findsOneWidget);
    expect(find.text('Detailed snippet content for testing'), findsOneWidget);
    expect(find.text('VSCode'), findsOneWidget);
    expect(find.text('Insert at Cursor'), findsOneWidget);
  });
}
