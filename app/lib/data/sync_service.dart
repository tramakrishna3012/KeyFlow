import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'models/history_entry.dart';
import 'supabase_history_repository.dart';

/// Orchestrates local → cloud sync of history entries.
///
/// After a local insert succeeds, [SyncService.syncEntry] uploads the entry
/// to Supabase in a fire-and-forget manner. If the upload fails (e.g., no
/// network), the entry is queued and retried with exponential backoff.
///
/// Sync is **unidirectional by default** (local → cloud). Call [pullFromCloud]
/// to fetch cloud entries not present locally (e.g., on a fresh install).
class SyncService {
  SyncService({
    required SupabaseHistoryRepository cloudRepo,
  }) : _cloudRepo = cloudRepo;

  final SupabaseHistoryRepository _cloudRepo;

  /// In-memory retry queue for entries that failed to upload.
  final Queue<_SyncTask> _retryQueue = Queue<_SyncTask>();

  Timer? _retryTimer;
  bool _isProcessingQueue = false;

  static const int _maxRetries = 5;
  static const Duration _baseRetryDelay = Duration(seconds: 2);

  /// Uploads a single entry to Supabase (fire-and-forget).
  ///
  /// If the upload fails, the entry is added to the retry queue.
  Future<void> syncEntry(HistoryEntry entry) async {
    try {
      await _cloudRepo.upsertEntry(entry);
      debugPrint('SyncService: Entry ${entry.id} synced to cloud');
    } on Exception catch (e) {
      debugPrint('SyncService: Entry ${entry.id} failed to sync — queuing for retry: $e');
      _retryQueue.add(_SyncTask(entry: entry, retryCount: 0));
      _scheduleRetryProcessing();
    }
  }

  /// Deletes a single entry from Supabase (fire-and-forget).
  Future<void> deleteEntry(String id) async {
    try {
      await _cloudRepo.deleteEntry(id);
      debugPrint('SyncService: Entry $id deleted from cloud');
    } on Exception catch (e) {
      debugPrint('SyncService: Failed to delete entry $id from cloud: $e');
    }
  }

  /// Deletes all cloud entries for the current user (fire-and-forget).
  Future<void> deleteAllEntries() async {
    try {
      await _cloudRepo.deleteAllEntries();
      debugPrint('SyncService: All entries deleted from cloud');
    } on Exception catch (e) {
      debugPrint('SyncService: Failed to delete all entries from cloud: $e');
    }
  }

  /// Pulls all cloud entries for the current user.
  ///
  /// Returns a list of decrypted [HistoryEntry] objects. The caller is
  /// responsible for merging these into the local database.
  Future<List<HistoryEntry>> pullFromCloud() async {
    try {
      final entries = await _cloudRepo.getAllEntries();
      debugPrint('SyncService: Pulled ${entries.length} entries from cloud');
      return entries;
    } on Exception catch (e) {
      debugPrint('SyncService: Failed to pull from cloud: $e');
      return [];
    }
  }

  /// Runs a cloud-side retention purge mirroring the local purge.
  Future<int> purgeCloudOlderThan(int retentionDays) async {
    try {
      final purged = await _cloudRepo.purgeOlderThan(retentionDays);
      debugPrint('SyncService: Purged $purged cloud entries older than $retentionDays days');
      return purged;
    } on Exception catch (e) {
      debugPrint('SyncService: Cloud purge failed: $e');
      return 0;
    }
  }

  /// Returns the number of entries currently queued for retry.
  int get pendingRetryCount => _retryQueue.length;

  // ── Retry Queue Processing ────────────────────────────────────────

  void _scheduleRetryProcessing() {
    if (_retryTimer != null && _retryTimer!.isActive) return;

    _retryTimer = Timer(_baseRetryDelay, _processRetryQueue);
  }

  Future<void> _processRetryQueue() async {
    if (_isProcessingQueue || _retryQueue.isEmpty) return;

    _isProcessingQueue = true;

    try {
      final batch = <_SyncTask>[];
      while (_retryQueue.isNotEmpty) {
        batch.add(_retryQueue.removeFirst());
      }

      for (final task in batch) {
        try {
          await _cloudRepo.upsertEntry(task.entry);
          debugPrint('SyncService: Retry succeeded for entry ${task.entry.id}');
        } on Exception catch (e) {
          if (task.retryCount < _maxRetries) {
            final nextTask = _SyncTask(
              entry: task.entry,
              retryCount: task.retryCount + 1,
            );
            _retryQueue.add(nextTask);
            debugPrint(
              'SyncService: Retry ${task.retryCount + 1}/$_maxRetries '
              'failed for ${task.entry.id}: $e',
            );
          } else {
            debugPrint(
              'SyncService: Giving up on entry ${task.entry.id} '
              'after $_maxRetries retries: $e',
            );
          }
        }
      }

      // If there are still items in the queue, schedule another round
      // with exponential backoff
      if (_retryQueue.isNotEmpty) {
        final nextDelay = _baseRetryDelay * (1 << _retryQueue.first.retryCount);
        _retryTimer = Timer(nextDelay, _processRetryQueue);
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Cancels any pending retry timers. Call when the service is disposed.
  void dispose() {
    _retryTimer?.cancel();
    _retryQueue.clear();
  }
}

/// Internal task tracking an entry and its retry count.
class _SyncTask {
  const _SyncTask({
    required this.entry,
    required this.retryCount,
  });

  final HistoryEntry entry;
  final int retryCount;
}
