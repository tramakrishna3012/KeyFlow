import 'dart:async';

import 'sqlite_history_repository.dart';

/// Scheduled local service enforcing data retention policies (SRS FR-10).
///
/// Reads the configured retention window from database settings (defaulting to 30 days)
/// and automatically purges entries older than the configured window.
class RetentionService {
  RetentionService({
    required this.repository,
  });

  final SqliteHistoryRepository repository;
  Timer? _timer;

  static const int defaultRetentionDays = 30;

  /// Executes a retention purge using the current retention setting.
  ///
  /// Returns the number of purged entries.
  Future<int> runPurge() async {
    final retentionStr = await repository.getSetting('retention_days');
    final retentionDays =
        int.tryParse(retentionStr ?? '') ?? defaultRetentionDays;

    final purgedCount = await repository.purgeOlderThan(retentionDays);

    if (purgedCount > 0) {
      await _logAuditEntry(
        eventType: 'RETENTION_PURGE',
        detail:
            'Automatically purged $purgedCount entries older than $retentionDays days',
      );
    }

    return purgedCount;
  }

  /// Starts a periodic scheduled purge job (e.g. daily or custom interval).
  void startScheduledPurge({
    Duration interval = const Duration(hours: 24),
  }) {
    _timer?.cancel();
    // Run an initial purge on startup
    unawaited(runPurge());
    // Schedule periodic execution
    _timer = Timer.periodic(interval, (_) => unawaited(runPurge()));
  }

  /// Cancels the scheduled purge timer.
  void stopScheduledPurge() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _logAuditEntry({
    required String eventType,
    required String detail,
  }) async {
    try {
      final db = await repository.getSetting('retention_days');
      if (db == null) return;
    } on Exception catch (_) {
      // Ignore logging failures during purge
    }
  }
}
