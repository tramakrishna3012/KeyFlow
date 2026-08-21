import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service responsible for wiping temporary directories, runtime diagnostic logs,
/// and unencrypted cache files to maintain zero-trace client privacy.
class CacheCleanupService {
  const CacheCleanupService();

  /// Recursively clears all files in the system temporary/cache directory.
  Future<void> clearTempAndCache() async {
    try {
      if (kIsWeb) return;

      final tempDir = await getTemporaryDirectory();
      if (tempDir.existsSync()) {
        final entities = tempDir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          try {
            if (entity is File) {
              await entity.delete();
            } else if (entity is Directory) {
              await entity.delete(recursive: true);
            }
          } on Object catch (e) {
            debugPrint(
              'CacheCleanupService: Failed to delete ${entity.path}: $e',
            );
          }
        }
      }
    } on Object catch (e) {
      debugPrint('CacheCleanupService: Error clearing temporary directory: $e');
    }
  }
}
