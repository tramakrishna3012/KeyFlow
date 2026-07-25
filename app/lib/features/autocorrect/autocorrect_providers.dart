import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../data/sqlite_history_repository.dart';
import 'autocorrect_engine.dart';

const String kKeyLearnedWords = 'learned_words';
const String kKeyAppOverrides = 'autocorrect_app_overrides';

final autocorrectEngineProvider = FutureProvider<AutocorrectEngine>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  var learnedWords = <String>{};
  var appOverrides = <String, bool>{};

  if (repo is SqliteHistoryRepository) {
    // Load learned words
    final learnedStr = await repo.getSetting(kKeyLearnedWords);
    if (learnedStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(learnedStr);
        learnedWords = decoded.cast<String>().toSet();
      } on Object catch (_) {}
    }

    // Load app overrides
    final overridesStr = await repo.getSetting(kKeyAppOverrides);
    if (overridesStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(overridesStr);
        appOverrides = decoded.map((k, v) => MapEntry(k, v as bool));
      } on Object catch (_) {}
    }
  }

  final engine = AutocorrectEngine(
    initialLearnedWords: learnedWords,
    appOverrides: appOverrides,
  );

  return engine;
});

class AutocorrectNotifier {
  AutocorrectNotifier(this.ref);
  final Ref ref;

  Future<void> learnWord(String word) async {
    final engine = await ref.read(autocorrectEngineProvider.future);
    engine.learnWord(word);

    final repo = ref.read(historyRepositoryProvider);
    if (repo is SqliteHistoryRepository) {
      final jsonStr = jsonEncode(engine.learnedWords.toList());
      await repo.setSetting(kKeyLearnedWords, jsonStr);
    }
    ref.invalidate(autocorrectEngineProvider);
  }

  Future<void> setAppOverride(String appName, bool enabled) async {
    final engine = await ref.read(autocorrectEngineProvider.future);
    engine.setAppOverride(appName, enabled);

    final repo = ref.read(historyRepositoryProvider);
    if (repo is SqliteHistoryRepository) {
      final jsonStr = jsonEncode(engine.appOverrides);
      await repo.setSetting(kKeyAppOverrides, jsonStr);
    }
    ref.invalidate(autocorrectEngineProvider);
  }
}

final autocorrectNotifierProvider = Provider<AutocorrectNotifier>(AutocorrectNotifier.new);
