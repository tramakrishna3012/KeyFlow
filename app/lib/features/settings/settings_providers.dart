import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../data/retention_service.dart';
import '../../data/sqlite_history_repository.dart';
import '../capture/capture_service.dart';
import '../history/history_providers.dart';

const String kKeyRetentionDays = 'retention_days';
const String kKeyAutocorrect = 'autocorrect_enabled';
const String kKeyTranslationLang = 'target_translation_language';

// Exclusion List provider
final exclusionListProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  return repo.getExclusionList();
});

// Retention Days provider (default 30)
final retentionDaysProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo is SqliteHistoryRepository) {
    final val = await repo.getSetting(kKeyRetentionDays);
    if (val != null) {
      return int.tryParse(val) ?? 30;
    }
  }
  return 30;
});

// Autocorrect setting provider
final autocorrectEnabledProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo is SqliteHistoryRepository) {
    final val = await repo.getSetting(kKeyAutocorrect);
    return val != 'false';
  }
  return true;
});

// Target Translation Language provider
final targetLanguageProvider = FutureProvider<String>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo is SqliteHistoryRepository) {
    final val = await repo.getSetting(kKeyTranslationLang);
    return val ?? 'es';
  }
  return 'es';
});

class SettingsController {
  SettingsController(this.ref);
  final Ref ref;

  Future<void> addExclusion(String appIdentifier) async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.addExclusion(appIdentifier);
    ref.invalidate(exclusionListProvider);

    // Sync updated list to native platform channel
    final list = await repo.getExclusionList();
    final captureService = CaptureService(repo);
    await captureService.syncExclusionList(list);
  }

  Future<void> removeExclusion(String appIdentifier) async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.removeExclusion(appIdentifier);
    ref.invalidate(exclusionListProvider);

    // Sync updated list to native platform channel
    final list = await repo.getExclusionList();
    final captureService = CaptureService(repo);
    await captureService.syncExclusionList(list);
  }

  Future<void> updateRetentionDays(int days) async {
    final repo = ref.read(historyRepositoryProvider);
    if (repo is SqliteHistoryRepository) {
      await repo.setSetting(kKeyRetentionDays, days.toString());
      ref.invalidate(retentionDaysProvider);

      // Trigger immediate auto-purge with new retention window
      final retentionService = RetentionService(repository: repo);
      await retentionService.runPurge();
      ref.invalidate(historyEntriesProvider);
    }
  }

  Future<void> setAutocorrectEnabled(bool enabled) async {
    final repo = ref.read(historyRepositoryProvider);
    if (repo is SqliteHistoryRepository) {
      await repo.setSetting(kKeyAutocorrect, enabled.toString());
      ref.invalidate(autocorrectEnabledProvider);
    }
  }

  Future<void> setTargetLanguage(String langCode) async {
    final repo = ref.read(historyRepositoryProvider);
    if (repo is SqliteHistoryRepository) {
      await repo.setSetting(kKeyTranslationLang, langCode);
      ref.invalidate(targetLanguageProvider);
    }
  }

  Future<String> exportHistoryData() async {
    final repo = ref.read(historyRepositoryProvider);
    final entries = await repo.getAllEntries();
    final jsonList = entries.map((e) => e.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(jsonList);
  }

  Future<void> deleteAllHistoryData() async {
    final repo = ref.read(historyRepositoryProvider);
    await repo.clearAll();
    ref.invalidate(historyEntriesProvider);
  }
}

final settingsControllerProvider = Provider<SettingsController>(SettingsController.new);
