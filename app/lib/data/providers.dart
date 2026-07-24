import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_helper.dart';
import 'history_repository.dart';
import 'retention_service.dart';
import 'secure_key_storage.dart';
import 'sqlite_history_repository.dart';

/// Provider for [SecureKeyStorage].
final secureKeyStorageProvider = Provider<SecureKeyStorage>(
  (ref) => SecureKeyStorage(),
);

/// Provider for [DatabaseHelper].
final databaseHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper(),
);

/// Provider for [SqliteHistoryRepository] typed as [HistoryRepository].
final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final keyStorage = ref.watch(secureKeyStorageProvider);
  return SqliteHistoryRepository(
    dbHelper: dbHelper,
    keyStorage: keyStorage,
  );
});

/// Provider for [RetentionService].
final retentionServiceProvider = Provider<RetentionService>((ref) {
  final repo = ref.watch(historyRepositoryProvider) as SqliteHistoryRepository;
  return RetentionService(repository: repo);
});
