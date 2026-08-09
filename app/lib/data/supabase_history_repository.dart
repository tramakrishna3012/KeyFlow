import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'encryption_service.dart';
import 'models/history_entry.dart';

class SupabaseHistoryRepository {
  SupabaseHistoryRepository({
    required this._client,
    required EncryptionService encryptionService,
  }) : _encryption = encryptionService;

  final SupabaseClient _client;
  final EncryptionService _encryption;

  static const String _tableName = 'history_entries';

  Future<void> upsertEntry(HistoryEntry entry) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint(
          'SupabaseHistoryRepo: No authenticated user, skipping upsert',
        );
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

  Future<List<HistoryEntry>> getAllEntries() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _client
          .from(_tableName)
          .select()
          .order('captured_at', ascending: false);

      final entries = <HistoryEntry>[];

      for (final row in response as List<dynamic>) {
        try {
          final rowMap = row as Map<String, dynamic>;
          final iv = rowMap['iv'] as String;

          final decryptedText = await _encryption.decryptText(
            EncryptedPayload(
              ciphertext: rowMap['encrypted_text'] as String,
              iv: iv,
            ),
          );

          final decryptedApp = await _encryption.decryptText(
            EncryptedPayload(
              ciphertext: rowMap['encrypted_source_app'] as String,
              iv: iv,
            ),
          );

          entries.add(
            HistoryEntry(
              id: rowMap['id'] as String,
              text: decryptedText,
              sourceApp: decryptedApp,
              capturedAt: DateTime.fromMillisecondsSinceEpoch(
                rowMap['captured_at'] as int,
              ),
              deviceId: rowMap['device_id'] as String?,
            ),
          );
        } on Exception catch (e) {
          debugPrint(
            'SupabaseHistoryRepo: Skipping entry — decryption failed: $e',
          );
        }
      }

      return entries;
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: getAllEntries failed — $e');
      return [];
    }
  }

  Future<void> deleteEntry(String id) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from(_tableName).delete().eq('id', id);
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: deleteEntry failed — $e');
      rethrow;
    }
  }

  Future<void> deleteAllEntries() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from(_tableName).delete().eq('user_id', userId);
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: deleteAllEntries failed — $e');
      rethrow;
    }
  }

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
          .lt('captured_at', cutoff)
          .select();

      return (response as List<dynamic>).length;
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: purgeOlderThan failed — $e');
      return 0;
    }
  }

  Future<int> count() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return 0;

      final response = await _client.from(_tableName).select('id');

      return (response as List<dynamic>).length;
    } on Exception catch (e) {
      debugPrint('SupabaseHistoryRepo: count failed — $e');
      return 0;
    }
  }
}
