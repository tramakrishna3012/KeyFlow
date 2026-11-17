import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/capture/capture_service.dart';
import '../features/history/history_providers.dart';
import 'auth_service.dart';
import 'database_helper.dart';
import 'encryption_service.dart';
import 'history_repository.dart';
import 'models/user_model.dart';
import 'retention_service.dart';
import 'secure_key_storage.dart';
import 'sqlite_history_repository.dart';
import 'supabase_history_repository.dart';
import 'sync_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService.instance;
  void refresh() => ref.notifyListeners();
  service.addListener(refresh);
  ref.onDispose(() => service.removeListener(refresh));
  return service;
});

final currentUserProvider = Provider<UserModel?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

final secureKeyStorageProvider = Provider<SecureKeyStorage>(
  (ref) => SecureKeyStorage(),
);

final databaseHelperProvider = Provider<DatabaseHelper>(
  (ref) => DatabaseHelper(),
);

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final keyStorage = ref.watch(secureKeyStorageProvider);
  return SqliteHistoryRepository(dbHelper: dbHelper, keyStorage: keyStorage);
});

final encryptionServiceProvider = Provider<EncryptionService?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user != null) {
    return EncryptionService(userId: user.id);
  }
  try {
    final supaUser = Supabase.instance.client.auth.currentUser;
    if (supaUser != null) {
      return EncryptionService(userId: supaUser.id);
    }
  } on Object catch (_) {}

  return EncryptionService(userId: 'usr_active_device_sync');
});

final supabaseHistoryRepositoryProvider = Provider<SupabaseHistoryRepository?>((
  ref,
) {
  final encryption = ref.watch(encryptionServiceProvider);
  if (encryption == null) return null;

  try {
    return SupabaseHistoryRepository(
      client: Supabase.instance.client,
      encryptionService: encryption,
    );
  } on Object catch (_) {
    return null;
  }
});

// Always returns a SyncService so captured text keeps reaching the web dashboard
// (via the Express backend inside SyncService) even when Supabase isn't configured.
// `cloudRepo` is passed through as-is (nullable) — SyncService treats a null cloudRepo
// as "no Supabase cloud storage configured" and simply skips that half of the sync,
// without affecting the backend sync the dashboard depends on.
final syncServiceProvider = Provider<SyncService>((ref) {
  final cloudRepo = ref.watch(supabaseHistoryRepositoryProvider);
  return SyncService(cloudRepo: cloudRepo);
});

final retentionServiceProvider = Provider<RetentionService>((ref) {
  final repo = ref.watch(historyRepositoryProvider) as SqliteHistoryRepository;
  return RetentionService(repository: repo);
});

final captureServiceProvider = Provider<CaptureService>((ref) {
  final repo = ref.watch(historyRepositoryProvider);
  final syncService = ref.watch(syncServiceProvider);
  return CaptureService(
    repo,
    syncService: syncService,
    syncServiceGetter: () => ref.read(syncServiceProvider),
    onEntryCaptured: (_) {
      ref
        ..invalidate(historyEntriesProvider)
        ..invalidate(allHistoryEntriesProvider);
    },
  );
});
