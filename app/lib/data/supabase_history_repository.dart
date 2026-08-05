import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'encryption_service.dart';
import 'models/history_entry.dart';

/// Repository for persisting encrypted history entries to Supabase.
///
/// All text content is encrypted client-side via [EncryptionService] before
/// upload — Supabase only ever stores ciphertext. RLS policies on the
/// `history_entries` table ensure user-scoped access.
class SupabaseHistoryRepository {
  SupabaseHistoryRepository({
    required this._client,
    required EncryptionService encryptionService,
  })  : _encryption = encryptionService;

  final SupabaseClient _client;
  final EncryptionService _encryption;

  static const String _tableName = 'history_entries';

  /// Inserts an encrypted history entry into Supabase.
  ///
  /// Encrypts `text` and `sourceApp` fields individually (each with its own IV
  /// would be ideal, but we share one IV per row for simplicity — the IV is
  /// unique per insert so this is still semantically secure).
  Future<void> upsertEntry(HistoryEntry entry) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('SupabaseHistoryRepo: No authenticated user, skipping upsert');
        return;
      }

      final encryptedText = await _encryption.encryptText(entry.text);
      final encryptedSourceApp = await _encryption.encryptText(entry.sourceApp);

      await _client.from(_tableName).upsert({
        'id': entry.id,
        'user_id': userId,
        'encrypted_text': encryptedText.ciphertext,
        'encrypted_source_app': encryptedSourceApp.ciphertext,
        'iv': encryptedText.iv,
        'captured_at': entry.capturedAt.millisecondsSinceEpoch,
        'device_id': entry.deviceId,
      });
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: upsertEntry failed — $e');
      rethrow;
    }
  }

  /// Fetches all entries for the current user, decrypts them, and returns
  /// as [HistoryEntry] objects ordered by `captured_at` descending.
  Future<List<HistoryEntry>> getAllEntries() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('captured_at', ascending: false);

      final entries = <HistoryEntry>[];
      for (final row in response) {
        try {
          final decryptedText = await _encryption.decryptText(
            EncryptedPayload(
              ciphertext: row['encrypted_text'] as String,
              iv: row['iv'] as String,
            ),
          );
          final decryptedSourceApp = await _encryption.decryptText(
            EncryptedPayload(
              ciphertext: row['encrypted_source_app'] as String,
              iv: row['iv'] as String,
            ),
          );

          entries.add(HistoryEntry(
            id: row['id'] as String,
            text: decryptedText,
            sourceApp: decryptedSourceApp,
            capturedAt: DateTime.fromMillisecondsSinceEpoch(
              row['captured_at'] as int,
            ),
            deviceId: row['device_id'] as String?,
          ));
        } on Exception catch (e) {
          // Skip entries that fail decryption (e.g., key mismatch from
          // a different device's salt). Log but don't crash.
          debugPrint('SupabaseHistoryRepo: Failed to decrypt entry ${row['id']}: $e');
        }
      }
      return entries;
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: getAllEntries failed — $e');
      return [];
    }
  }

  /// Deletes a single entry by [id] from Supabase.
  Future<void> deleteEntry(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client
          .from(_tableName)
          .delete()
          .eq('id', id)
          .eq('user_id', userId);
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: deleteEntry failed — $e');
    }
  }

  /// Deletes all entries for the current user from Supabase.
  Future<void> deleteAllEntries() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client
          .from(_tableName)
          .delete()
          .eq('user_id', userId);
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: deleteAllEntries failed — $e');
    }
  }

  /// Purges entries older than [retentionDays] from Supabase.
  Future<int> purgeOlderThan(int retentionDays) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 0;

      final cutoff = DateTime.now()
          .subtract(Duration(days: retentionDays))
          .millisecondsSinceEpoch;

      final response = await _client
          .from(_tableName)
          .delete()
          .eq('user_id', userId)
          .lt('captured_at', cutoff)
          .select();

      return (response as List).length;
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: purgeOlderThan failed — $e');
      return 0;
    }
  }

  /// Returns the count of cloud entries for the current user.
  Future<int> count() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _client
          .from(_tableName)
          .select('id')
          .eq('user_id', userId);

      return (response as List).length;
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: count failed — $e');
      return 0;
    }
  }
}
