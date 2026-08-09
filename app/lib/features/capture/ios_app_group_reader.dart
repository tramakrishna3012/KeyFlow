import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/history_repository.dart';
import '../../data/models/history_entry.dart';

/// Reads captured history entries written by the native iOS Swift keyboard extension
/// into the shared App Group container (`group.com.keyflow.app`).
class IosAppGroupReader {

  IosAppGroupReader(this._repository);
  static const String appGroupId = 'group.com.keyflow.app';
  static const String pendingFilename = 'keyflow_pending_entries.json';

  final HistoryRepository _repository;

  /// Synchronizes pending history entries from the shared App Group container
  /// into the encrypted local [HistoryRepository].
  Future<int> syncPendingEntries({String? customGroupPath}) async {
    if (defaultTargetPlatform != TargetPlatform.iOS && customGroupPath == null) {
      return 0;
    }

    try {
      final file = customGroupPath != null
          ? File('$customGroupPath/$pendingFilename')
          : File('/private/var/mobile/Containers/Shared/AppGroup/$appGroupId/$pendingFilename');

      if (!file.existsSync()) {
        return 0;
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) return 0;

      final dynamic decoded = jsonDecode(content);
      if (decoded is! List) return 0;

      var importedCount = 0;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final entry = HistoryEntry(
            id: item['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
            text: item['text']?.toString() ?? '',
            sourceApp: item['source_app']?.toString() ?? 'iOS Keyboard',
            capturedAt: DateTime.fromMillisecondsSinceEpoch(
              (item['captured_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
            ),
            language: item['language']?.toString() ?? 'en',
            wasTranslated: item['was_translated'] == true,
            deviceId: item['device_id']?.toString() ?? 'ios_keyboard',
          );

          if (entry.text.isNotEmpty) {
            await _repository.addEntry(entry);
            importedCount++;
          }
        }
      }

      // Clear pending file after successful sync
      await file.writeAsString('[]');
      return importedCount;
    } on Exception catch (e) {
      debugPrint('Error syncing iOS App Group pending entries: $e');
      return 0;
    }
  }

  /// Parses JSON raw content string (useful for testing or direct string processing).
  static List<HistoryEntry> parseAppGroupPayload(String jsonString) {
    try {
      final dynamic decoded = jsonDecode(jsonString);
      if (decoded is! List) return [];

      return decoded.map((item) {
        final map = item as Map<String, dynamic>;
        return HistoryEntry(
          id: map['id']?.toString() ?? '',
          text: map['text']?.toString() ?? '',
          sourceApp: map['source_app']?.toString() ?? 'iOS Keyboard',
          capturedAt: DateTime.fromMillisecondsSinceEpoch(
            (map['captured_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
          ),
          language: map['language']?.toString() ?? 'en',
          wasTranslated: map['was_translated'] == true,
          deviceId: map['device_id']?.toString() ?? 'ios_keyboard',
        );
      }).toList();
    } on Exception catch (_) {
      return [];
    }
  }

}
