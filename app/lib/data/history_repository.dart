import 'models/history_entry.dart';

/// Abstract repository interface for the encrypted local History Store.
///
/// Per Architecture §2, UI code never touches storage directly — all
/// access goes through this abstraction. Concrete implementations will
/// use SQLite/SQLCipher with encryption keys stored in the OS-native
/// secure store (TRD S-1).
abstract class HistoryRepository {
  /// Retrieves all history entries, ordered by [capturedAt] descending.
  Future<List<HistoryEntry>> getAllEntries();

  /// Searches entries matching [query], ranked by recency and relevance.
  ///
  /// Must return results in < 200ms for 100k entries (SRS §3.2).
  Future<List<HistoryEntry>> search(String query);

  /// Alias for [search] matching SRS specification.
  Future<List<HistoryEntry>> searchEntries(String query);

  /// Retrieves a single entry by its [id].
  Future<HistoryEntry?> getEntry(String id);

  /// Inserts a new captured text entry.
  Future<void> insertEntry(HistoryEntry entry);

  /// Alias for [insertEntry] matching SRS specification.
  Future<void> addEntry(HistoryEntry entry);

  /// Deletes a single entry by [id] (SRS FR-9).
  Future<void> deleteEntry(String id);

  /// Deletes all history entries (SRS FR-9, FR-21 "delete all my data").
  Future<void> deleteAllEntries();

  /// Alias for [deleteAllEntries] matching SRS specification.
  Future<void> clearAll();

  /// Purges entries older than [retentionDays] (SRS FR-10).
  ///
  /// Called by the scheduled retention job. Default retention: 30 days.
  Future<int> purgeOlderThan(int retentionDays);

  /// Exports all entries for the "export my data" action (SRS FR-21).
  Future<String> exportAll();

  /// Returns the total count of stored entries.
  Future<int> count();
}
