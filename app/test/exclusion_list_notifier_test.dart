import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/capture/capture_service.dart';
import 'package:keyflow_app/features/settings/settings_providers.dart';
import 'history_repository_test.dart';

/// Repository whose first addExclusion call fails, to exercise rollback.
class FlakyExclusionRepository extends InMemoryHistoryRepository {
  int failuresRemaining = 1;

  /// Number of getExclusionList calls to fail after the initial load.
  int readFailuresRemaining = 0;
  bool _initialLoadDone = false;

  @override
  Future<List<String>> getExclusionList() async {
    if (_initialLoadDone && readFailuresRemaining > 0) {
      readFailuresRemaining--;
      throw Exception('db locked');
    }
    _initialLoadDone = true;
    return super.getExclusionList();
  }

  @override
  Future<void> addExclusion(String appIdentifier) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw Exception('disk full');
    }
    await super.addExclusion(appIdentifier);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<List<String>> nativeSyncs;

  setUp(() {
    nativeSyncs = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('keyflow/capture'), (
          call,
        ) async {
          if (call.method == 'setExclusionList') {
            nativeSyncs.add(List<String>.from(call.arguments as List));
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('keyflow/capture'), null);
  });

  ProviderContainer makeContainer(FlakyExclusionRepository repo) {
    final capture = CaptureService(repo);
    final container = ProviderContainer(
      overrides: [
        historyRepositoryProvider.overrideWithValue(repo),
        captureServiceProvider.overrideWithValue(capture),
      ],
    );
    addTearDown(() {
      capture.dispose();
      container.dispose();
    });
    return container;
  }

  test('toggle updates state immediately and persists', () async {
    final repo = FlakyExclusionRepository()..failuresRemaining = 0;
    final container = makeContainer(repo);
    await container.read(exclusionListProvider.future);

    final pending = container
        .read(exclusionListProvider.notifier)
        .toggle('com.whatsapp');
    // Optimistic: visible before the DB write completes.
    await Future<void>.delayed(Duration.zero);
    expect(container.read(exclusionListProvider).value, ['com.whatsapp']);

    await pending;
    expect(await repo.getExclusionList(), ['com.whatsapp']);
  });

  test(
    'a failed write does not discard a later queued toggle that succeeded',
    () async {
      final repo = FlakyExclusionRepository();
      final container = makeContainer(repo);
      await container.read(exclusionListProvider.future);
      final notifier = container.read(exclusionListProvider.notifier);

      // First write fails, second succeeds; both queued back-to-back.
      final first = notifier.setExcluded('com.first', excluded: true);
      final second = notifier.setExcluded('com.second', excluded: true);
      await Future.wait([first, second]);

      expect(await repo.getExclusionList(), ['com.second']);
      expect(container.read(exclusionListProvider).value, ['com.second']);
      expect(nativeSyncs.last, ['com.second']);
    },
  );

  test(
    'a failed reconciliation read is retried until state matches storage',
    () async {
      final repo = FlakyExclusionRepository()..readFailuresRemaining = 1;
      final container = makeContainer(repo);
      await container.read(exclusionListProvider.future);
      final notifier = container.read(exclusionListProvider.notifier);

      // Write fails, then the first reconcile read fails too.
      await notifier.setExcluded('com.first', excluded: true);
      // Optimistic value is still shown while the retry is pending.
      expect(container.read(exclusionListProvider).value, ['com.first']);

      // Retry fires after the 500ms backoff and fixes the state.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      expect(container.read(exclusionListProvider).value, isEmpty);
      expect(nativeSyncs.last, isEmpty);
    },
  );
}
