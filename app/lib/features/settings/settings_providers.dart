import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../data/retention_service.dart';
import '../../data/sqlite_history_repository.dart';
import '../capture/capture_service.dart';
import '../history/history_providers.dart';
import 'models/installed_app_info.dart';

const String kKeyRetentionDays = 'retention_days';
const String kKeyAutocorrect = 'autocorrect_enabled';
const String kKeyTranslationLang = 'target_translation_language';
const String kKeyOverlayBubble = 'overlay_bubble_enabled';
const String kKeyBankingAutoExcluded = 'banking_auto_excluded_v1';

// Exclusion List provider.
// Uses an AsyncNotifier so toggles update the UI instantly (optimistic) while the
// database write and native sync happen in the background.
class ExclusionListNotifier extends AsyncNotifier<List<String>> {
  Future<void> _pending = Future<void>.value();

  @override
  Future<List<String>> build() {
    final repo = ref.watch(historyRepositoryProvider);
    return repo.getExclusionList();
  }

  Future<void> toggle(String appIdentifier) async {
    final current = state.value ?? await future;
    await setExcluded(
      appIdentifier,
      excluded: !current.contains(appIdentifier),
    );
  }

  Future<void> setExcluded(String appIdentifier, {required bool excluded}) {
    final previous = List<String>.of(state.value ?? const <String>[]);
    final next = List<String>.of(previous)..remove(appIdentifier);
    if (excluded) next.add(appIdentifier);

    // 1. Instant UI + capture-engine update
    state = AsyncData(next);
    final captureService = ref.read(captureServiceProvider);
    unawaited(captureService.syncExclusionList(next));

    // 2. Persist; writes are chained so rapid taps are applied in order.
    final repo = ref.read(historyRepositoryProvider);
    final op = _pending.then((_) async {
      try {
        if (excluded) {
          await repo.addExclusion(appIdentifier);
        } else {
          await repo.removeExclusion(appIdentifier);
        }
      } on Object catch (_) {
        // Roll back on failure so UI and native engine match the database.
        final persisted = await repo.getExclusionList();
        state = AsyncData(persisted);
        await captureService.syncExclusionList(persisted);
      }
    });
    _pending = op;
    return op;
  }
}

final exclusionListProvider =
    AsyncNotifierProvider<ExclusionListNotifier, List<String>>(
      ExclusionListNotifier.new,
    );

// Installed Apps provider
final installedAppsProvider = FutureProvider<List<InstalledAppInfo>>((
  ref,
) async {
  final captureService = ref.watch(captureServiceProvider);
  final repo = ref.watch(historyRepositoryProvider);
  final apps = await captureService.getInstalledApps();

  // Auto-prepopulate detected banking/payment apps if not yet done
  if (repo is SqliteHistoryRepository) {
    final alreadyAutoExcluded = await repo.getSetting(kKeyBankingAutoExcluded);
    if (alreadyAutoExcluded != 'true') {
      final currentExclusions = await repo.getExclusionList();
      final currentExclusionSet = currentExclusions.toSet();
      for (final app in apps) {
        if (app.isBankingApp &&
            !currentExclusionSet.contains(app.packageName)) {
          await repo.addExclusion(app.packageName);
        }
      }
      await repo.setSetting(kKeyBankingAutoExcluded, 'true');
      final updatedList = await repo.getExclusionList();
      await captureService.syncExclusionList(updatedList);
      ref.invalidate(exclusionListProvider);
    }
  }

  return apps;
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

// Overlay Bubble setting provider
final overlayBubbleEnabledProvider = FutureProvider<bool>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo is SqliteHistoryRepository) {
    final val = await repo.getSetting(kKeyOverlayBubble);
    return val == 'true';
  }
  return false;
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

  Future<void> addExclusion(String appIdentifier) => ref
      .read(exclusionListProvider.notifier)
      .setExcluded(appIdentifier, excluded: true);

  Future<void> removeExclusion(String appIdentifier) => ref
      .read(exclusionListProvider.notifier)
      .setExcluded(appIdentifier, excluded: false);

  Future<void> toggleAppExclusion(String packageName) =>
      ref.read(exclusionListProvider.notifier).toggle(packageName);

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

  Future<void> setOverlayBubbleEnabled(bool enabled) async {
    final repo = ref.read(historyRepositoryProvider);
    if (repo is SqliteHistoryRepository) {
      await repo.setSetting(kKeyOverlayBubble, enabled.toString());
      ref.invalidate(overlayBubbleEnabledProvider);
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

final settingsControllerProvider = Provider<SettingsController>(
  SettingsController.new,
);

class CapturePausedNotifier extends StateNotifier<bool> {
  CapturePausedNotifier(this._captureService)
    : super(_captureService.isPaused) {
    _init();
  }

  final CaptureService _captureService;

  Future<void> _init() async {
    final paused = await _captureService.isCapturePaused();
    state = paused;
  }

  Future<void> togglePause() async {
    if (state) {
      await _captureService.resumeCapture();
      state = false;
    } else {
      await _captureService.pauseCapture();
      state = true;
    }
  }

  Future<void> setPaused(bool paused) async {
    if (paused) {
      await _captureService.pauseCapture();
      state = true;
    } else {
      await _captureService.resumeCapture();
      state = false;
    }
  }

  Future<void> syncWithNative() async {
    final paused = await _captureService.isCapturePaused();
    state = paused;
  }

  Future<void> openAccessibilitySettings() async {
    await _captureService.openAccessibilitySettings();
  }
}

final capturePausedProvider =
    StateNotifierProvider<CapturePausedNotifier, bool>((ref) {
      final captureService = ref.watch(captureServiceProvider);
      return CapturePausedNotifier(captureService);
    });

final accessibilityServiceEnabledProvider = FutureProvider<bool>((ref) async {
  final captureService = ref.watch(captureServiceProvider);
  return captureService.isAccessibilityServiceEnabled();
});

class FloatingBubbleNotifier extends StateNotifier<bool> {
  FloatingBubbleNotifier(this._captureService, this._ref) : super(false) {
    _init();
  }

  final CaptureService _captureService;
  final Ref _ref;

  Future<void> _init() async {
    final enabledSetting = await _ref.read(overlayBubbleEnabledProvider.future);
    final isShowing = await _captureService.isOverlayShowing();
    if (enabledSetting && !isShowing) {
      final allowed = await _captureService.canDrawOverlays();
      if (allowed) {
        await _captureService.showOverlayBubble();
        state = true;
        return;
      }
    }
    state = isShowing;
  }

  Future<bool> toggleBubble() async {
    if (state) {
      await _captureService.hideOverlayBubble();
      await _ref
          .read(settingsControllerProvider)
          .setOverlayBubbleEnabled(false);
      state = false;
      return true;
    } else {
      final allowed = await _captureService.canDrawOverlays();
      if (!allowed) {
        return false; // Caller should show explanation dialog and request permission
      }
      final success = await _captureService.showOverlayBubble();
      if (success) {
        await _ref
            .read(settingsControllerProvider)
            .setOverlayBubbleEnabled(true);
        state = true;
      }
      return success;
    }
  }

  Future<void> enableAfterPermission() async {
    final success = await _captureService.showOverlayBubble();
    if (success) {
      await _ref.read(settingsControllerProvider).setOverlayBubbleEnabled(true);
      state = true;
    }
  }

  Future<void> disableBubble() async {
    await _captureService.hideOverlayBubble();
    await _ref.read(settingsControllerProvider).setOverlayBubbleEnabled(false);
    state = false;
  }
}

final floatingBubbleProvider =
    StateNotifierProvider<FloatingBubbleNotifier, bool>((ref) {
      final captureService = ref.watch(captureServiceProvider);
      return FloatingBubbleNotifier(captureService, ref);
    });
