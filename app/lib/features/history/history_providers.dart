import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/history_entry.dart';
import '../../data/providers.dart';

/// State provider for the current search query string.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// State provider for the active tag/app filter.
final activeTagProvider = StateProvider<String>((ref) => 'All');

/// Async provider yielding history entries based on search query and filter tag.
final historyEntriesProvider = FutureProvider.autoDispose<List<HistoryEntry>>((ref) async {
  final repository = ref.watch(historyRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  final tag = ref.watch(activeTagProvider);

  final entries = await repository.search(query);

  if (tag == 'All') {
    return entries;
  }

  return entries.where((e) {
    final lowerTag = tag.toLowerCase();
    return e.sourceApp.toLowerCase().contains(lowerTag) ||
        (e.category != null && e.category!.toLowerCase().contains(lowerTag));
  }).toList();
});

/// Async provider yielding ALL raw history entries for dashboard analytics.
final allHistoryEntriesProvider = FutureProvider.autoDispose<List<HistoryEntry>>((ref) async {
  final repository = ref.watch(historyRepositoryProvider);
  return repository.getAllEntries();
});

/// Controller to perform history entry deletions (local + cloud).
class HistoryNotifier extends StateNotifier<AsyncValue<void>> {
  HistoryNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> deleteEntry(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(historyRepositoryProvider);
      await repository.deleteEntry(id);

      // Mirror delete to cloud (fire-and-forget)
      final syncService = ref.read(syncServiceProvider);
      unawaited(syncService?.deleteEntry(id));

      ref
        ..invalidate(historyEntriesProvider)
        ..invalidate(allHistoryEntriesProvider);
    });
  }

  Future<void> clearAll() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(historyRepositoryProvider);
      await repository.clearAll();

      // Mirror clear-all to cloud (fire-and-forget)
      final syncService = ref.read(syncServiceProvider);
      unawaited(syncService?.deleteAllEntries());

      ref
        ..invalidate(historyEntriesProvider)
        ..invalidate(allHistoryEntriesProvider);
    });
  }
}

final historyNotifierProvider = StateNotifierProvider<HistoryNotifier, AsyncValue<void>>(
  HistoryNotifier.new,
);
