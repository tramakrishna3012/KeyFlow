import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/history_repository.dart';
import 'package:keyflow_app/data/models/history_entry.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/onboarding/onboarding_providers.dart';
import 'package:keyflow_app/features/onboarding/onboarding_screen.dart';

class MockOnboardingRepo implements HistoryRepository {
  final Map<String, String> settings = {};
  final List<String> exclusions = [];

  @override
  Future<void> addExclusion(String appIdentifier) async {
    exclusions.add(appIdentifier);
  }

  @override
  Future<List<String>> getExclusionList() async => exclusions;

  @override
  Future<void> removeExclusion(String appIdentifier) async {}

  @override
  Future<void> addEntry(HistoryEntry entry) async {}

  @override
  Future<void> insertEntry(HistoryEntry entry) async {}

  @override
  Future<List<HistoryEntry>> getAllEntries() async => [];

  @override
  Future<List<HistoryEntry>> search(String query) async => [];

  @override
  Future<List<HistoryEntry>> searchEntries(String query) async => [];

  @override
  Future<HistoryEntry?> getEntry(String id) async => null;

  @override
  Future<void> deleteEntry(String id) async {}

  @override
  Future<void> deleteAllEntries() async {}

  @override
  Future<void> clearAll() async {}

  @override
  Future<int> purgeOlderThan(int days) async => 0;

  @override
  Future<String> exportAll() async => '';

  @override
  Future<int> count() async => 0;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OnboardingScreen displays Screen 1: What KeyFlow Does', (WidgetTester tester) async {
    final mockRepo = MockOnboardingRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('What KeyFlow Does'), findsOneWidget);
    expect(find.textContaining('KeyFlow saves text you type on this device'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('Navigating through onboarding steps to Exclusion Setup displays default exclusions', (WidgetTester tester) async {
    final mockRepo = MockOnboardingRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: OnboardingScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Step 1 -> Step 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('What KeyFlow Does NOT Do'), findsOneWidget);

    // Step 2 -> Step 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('System Permission Request'), findsOneWidget);

    // Step 3 -> Step 4 (Exclusion Setup)
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Exclusion List Setup'), findsOneWidget);
    expect(find.text('1password.exe'), findsOneWidget);
    expect(find.text('bitwarden.exe'), findsOneWidget);
    expect(find.text('keepass.exe'), findsOneWidget);
  });
}
