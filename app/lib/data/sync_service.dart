import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'models/history_entry.dart';
import 'supabase_history_repository.dart';

class SyncService {
  SyncService({
    required this.cloudRepo,
    http.Client? httpClient,
  })  : _client = httpClient ?? http.Client();

  final SupabaseHistoryRepository cloudRepo;
  SupabaseHistoryRepository get _cloudRepo => cloudRepo;
  final http.Client _client;
  final List<HistoryEntry> _retryQueue = [];
  Timer? _retryTimer;

  int _retryCount = 0;
  static const int _maxRetries = 5;

  Future<void> syncEntry(HistoryEntry entry) async {
    // 1. Primary sync to online Supabase PostgreSQL table
    try {
      await _cloudRepo.upsertEntry(entry);
      debugPrint('SyncService: Entry ${entry.id} synced to Supabase');
      _retryCount = 0;
    } on Exception catch (e) {
      debugPrint(
        'SyncService: Entry ${entry.id} failed to sync to Supabase — queuing for retry: $e',
      );
      _queueForRetry(entry);
    }

    // 2. Also send telemetry batch to Express backend for Web Dashboard
    try {
      final token = AuthService.instance.token;
      if (token != null && token.isNotEmpty) {
        final url = Uri.parse('https://keyflow-dnsd.onrender.com/api/v1/activity/batch');
        final payload = {
          'deviceName': 'Motorola Edge 40',
          'osInfo': 'Android 15',
          'agentVersion': '1.0.0',
          'entries': [
            {
              'id': entry.id,
              'appName': entry.sourceApp,
              'windowTitle': entry.sourceApp,
              'textRecord': entry.text,
              'durationSeconds': 5,
              'startedAt': entry.capturedAt.toIso8601String(),
              'endedAt': entry.capturedAt.add(const Duration(seconds: 5)).toIso8601String(),
            }
          ]
        };

        final response = await _client.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          debugPrint('SyncService: Entry ${entry.id} synced to Express backend');
        }
      }
    } on Object catch (e) {
      debugPrint('SyncService backend batch error (non-fatal): $e');
    }
  }


  Future<void> deleteEntry(String id) async {
    try {
      await _cloudRepo.deleteEntry(id);
      debugPrint('SyncService: Entry $id deleted from cloud');
    } on Exception catch (e) {
      debugPrint('SyncService: Failed to delete entry $id from cloud: $e');
    }
  }

  Future<void> deleteAllEntries() async {
    try {
      await _cloudRepo.deleteAllEntries();
      debugPrint('SyncService: All entries deleted from cloud');
    } on Exception catch (e) {
      debugPrint('SyncService: Failed to delete all entries from cloud: $e');
    }
  }

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

  Future<int> purgeCloudOlderThan(int retentionDays) async {
    try {
      final count = await _cloudRepo.purgeOlderThan(retentionDays);
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

    final pending = List<HistoryEntry>.from(_retryQueue);
    _retryQueue.clear();

    for (final entry in pending) {
      try {
        await _cloudRepo.upsertEntry(entry);
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
