import 'models/history_entry.dart';

abstract class HistoryRepository {
  Future<void> addEntry(HistoryEntry entry);
  Future<void> insertEntry(HistoryEntry entry);
  Future<HistoryEntry?> getEntry(String id);
  Future<List<HistoryEntry>> search(String query);
  Future<List<HistoryEntry>> searchEntries(String query, {String? appName});
  Future<List<HistoryEntry>> getAllEntries();
  Future<void> deleteEntry(String id);
  Future<void> clearAll();
  Future<void> deleteAllEntries();
  Future<int> purgeOlderThan(int retentionDays);
  Future<int> count();
  Future<String> exportAll();

  // Settings & Exclusions
  Future<String?> getSetting(String key);
  Future<void> setSetting(String key, String value);
  Future<List<String>> getExclusionList();
  Future<void> addExclusion(String appIdentifier);
  Future<void> removeExclusion(String appIdentifier);
}

