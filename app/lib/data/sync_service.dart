import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'models/history_entry.dart';
import 'supabase_history_repository.dart';

class SyncService {
  // `cloudRepo` is nullable: Supabase is optional cloud storage, not a prerequisite for
  // reaching the web dashboard. The dashboard is fed by `_syncToBackend` (the Express API),
  // which works independently of Supabase and runs whether or not `cloudRepo` is set. Keeping
  // them independent means a Supabase outage/misconfiguration never silently stops captured
  // text from reaching the dashboard.
  SyncService({this.cloudRepo, http.Client? httpClient})
    : _client = httpClient ?? http.Client();

  final SupabaseHistoryRepository? cloudRepo;
  final http.Client _client;
  final List<HistoryEntry> _retryQueue = [];
  Timer? _retryTimer;

  int _retryCount = 0;
  static const int _maxRetries = 5;

  // Exposed (not underscore-prefixed) and marked @visibleForTesting rather than kept
  // fully private, so the device-metadata fallback this PR's review flagged can be
  // unit-tested directly without needing to drive AuthService's singleton token through
  // a full login flow just to reach the HTTP call that uses it.
  @visibleForTesting
  static String get defaultDeviceName =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? 'iPhone'
      : 'Motorola Edge 40';

  @visibleForTesting
  static String get defaultOsInfo =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'iOS' : 'Android 15';

  Future<void> syncEntry(HistoryEntry entry) async {
    // Both destinations are independent, so push to them concurrently so the
    // web dashboard sees new text without waiting on the Supabase round-trip.
    await Future.wait<void>([_syncToSupabase(entry), _syncToBackend(entry)]);
  }

  Future<void> _syncToSupabase(HistoryEntry entry) async {
    final repo = cloudRepo;
    if (repo == null) return;
    try {
      await repo.upsertEntry(entry);
      debugPrint('SyncService: Entry ${entry.id} synced to Supabase');
      _retryCount = 0;
    } on Exception catch (e) {
      debugPrint(
        'SyncService: Entry ${entry.id} failed to sync to Supabase — queuing for retry: $e',
      );
      _queueForRetry(entry);
    }
  }

  Future<void> _syncToBackend(HistoryEntry entry) async {
    try {
      final token = AuthService.instance.token;
      if (token != null && token.isNotEmpty) {
        final url = Uri.parse(
          'https://keyflow-dnsd.onrender.com/api/v1/activity/batch',
        );
        final payload = {
          // Android's CaptureService always sets entry.deviceId, so this keeps today's
          // behavior there unchanged. iOS's manually-saved snippets leave deviceId null
          // (there is no capture-time device context to stamp), so they fall back to an
          // iOS-appropriate default instead of being mislabeled as the Android device —
          // otherwise the dashboard attributes/merges iPhone snippets into that device's
          // history.
          'deviceName': entry.deviceId ?? defaultDeviceName,
          'osInfo': defaultOsInfo,
          'agentVersion': '1.0.0',
          'entries': [
            {
              'id': entry.id,
              'appName': entry.sourceApp,
              'windowTitle': entry.sourceApp,
              'textRecord': entry.text,
              'durationSeconds': 5,
              'startedAt': entry.capturedAt.toIso8601String(),
              'endedAt': entry.capturedAt
                  .add(const Duration(seconds: 5))
                  .toIso8601String(),
            },
          ],
        };

        final response = await _client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(payload),
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint(
            'SyncService: Entry ${entry.id} synced to Express backend',
          );
        }
      }
    } on Object catch (e) {
      debugPrint('SyncService backend batch error (non-fatal): $e');
    }
  }

  Future<void> deleteEntry(String id) async {
    final repo = cloudRepo;
    if (repo == null) return;
    try {
      await repo.deleteEntry(id);
      debugPrint('SyncService: Entry $id deleted from cloud');
    } on Exception catch (e) {
      debugPrint('SyncService: Failed to delete entry $id from cloud: $e');
    }
  }

  Future<void> deleteAllEntries() async {
    final repo = cloudRepo;
    if (repo == null) return;
    try {
      await repo.deleteAllEntries();
      debugPrint('SyncService: All entries deleted from cloud');
    } on Exception catch (e) {
      debugPrint('SyncService: Failed to delete all entries from cloud: $e');
    }
  }

  Future<List<HistoryEntry>> pullFromCloud() async {
    final repo = cloudRepo;
    if (repo == null) return [];
    try {
      final entries = await repo.getAllEntries();
      debugPrint('SyncService: Pulled ${entries.length} entries from cloud');
      return entries;
    } on Exception catch (e) {
      debugPrint('SyncService: Failed to pull from cloud: $e');
      return [];
    }
  }

  Future<int> purgeCloudOlderThan(int retentionDays) async {
    final repo = cloudRepo;
    if (repo == null) return 0;
    try {
      final count = await repo.purgeOlderThan(retentionDays);
      debugPrint(
        'SyncService: Purged $count cloud entries older than $retentionDays days',
      );
      return count;
    } on Exception catch (e) {
      debugPrint('SyncService: Failed to purge cloud entries: $e');
      return 0;
    }
  }

  void _queueForRetry(HistoryEntry entry) {
    if (!_retryQueue.any((e) => e.id == entry.id)) {
      _retryQueue.add(entry);
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive ?? false) return;
    if (_retryCount >= _maxRetries) {
      debugPrint(
        'SyncService: Max retries ($_maxRetries) reached, stopping retry loop',
      );
      return;
    }

    final delay = Duration(seconds: 1 << _retryCount);
    _retryCount++;
    debugPrint(
      'SyncService: Scheduling retry #$_retryCount in ${delay.inSeconds}s',
    );

    _retryTimer = Timer(delay, _processRetryQueue);
  }

  Future<void> _processRetryQueue() async {
    if (_retryQueue.isEmpty) return;
    final repo = cloudRepo;
    if (repo == null) {
      _retryQueue.clear();
      return;
    }

    final pending = List<HistoryEntry>.from(_retryQueue);
    _retryQueue.clear();

    for (final entry in pending) {
      try {
        await repo.upsertEntry(entry);
        debugPrint(
          'SyncService: Retried entry ${entry.id} synced successfully',
        );
      } on Exception catch (_) {
        _retryQueue.add(entry);
      }
    }

    if (_retryQueue.isNotEmpty) {
      _scheduleRetry();
    } else {
      _retryCount = 0;
    }
  }

  int get pendingRetryCount => _retryQueue.length;

  void dispose() {
    _retryTimer?.cancel();
    _retryQueue.clear();
  }
}
