import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/capture/capture_service.dart';
import 'database_helper.dart';
import 'encryption_service.dart';
import 'history_repository.dart';
import 'retention_service.dart';
import 'secure_key_storage.dart';
import 'sqlite_history_repository.dart';
import 'supabase_history_repository.dart';
import 'sync_service.dart';

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

/// Provider for [EncryptionService].
///
/// Returns `null` if no user is signed in (encryption key derivation
/// requires the user's Supabase UID).
final encryptionServiceProvider = Provider<EncryptionService?>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  return EncryptionService(userId: user.id);
});

/// Provider for [SupabaseHistoryRepository].
///
/// Returns `null` if the user is not authenticated (no encryption service).
final supabaseHistoryRepositoryProvider =
    Provider<SupabaseHistoryRepository?>((ref) {
  final encryption = ref.watch(encryptionServiceProvider);
  if (encryption == null) return null;

  return SupabaseHistoryRepository(
    client: Supabase.instance.client,
    encryptionService: encryption,
  );
});

/// Provider for [SyncService].
///
/// Returns `null` if cloud repository is unavailable (user not signed in).
final syncServiceProvider = Provider<SyncService?>((ref) {
  final cloudRepo = ref.watch(supabaseHistoryRepositoryProvider);
  if (cloudRepo == null) return null;

  return SyncService(cloudRepo: cloudRepo);
});

/// Provider for [RetentionService].
final retentionServiceProvider = Provider<RetentionService>((ref) {
  final repo = ref.watch(historyRepositoryProvider) as SqliteHistoryRepository;
  return RetentionService(repository: repo);
});

/// Provider for [CaptureService].
final captureServiceProvider = Provider<CaptureService>((ref) {
  final repo = ref.watch(historyRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);
  return CaptureService(repo, syncService: syncService);
});
