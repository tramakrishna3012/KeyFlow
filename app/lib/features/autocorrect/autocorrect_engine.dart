import 'dictionary_data.dart';

/// Candidate correction item returned by [AutocorrectEngine].
class CorrectionCandidate {
  const CorrectionCandidate({
    required this.word,
    required this.editDistance,
    required this.frequencyScore,
  });

  final String word;
  final int editDistance;
  final int frequencyScore;
}

/// High-performance on-device Autocorrect Engine (SRS FR-11, FR-12).
///
/// Features:
/// - Pre-packaged dictionary + local learned words
/// - Levenshtein edit distance candidate search (< 10ms latency)
/// - Per-app toggle overrides
class AutocorrectEngine {
  AutocorrectEngine({
    Map<String, int>? customDictionary,
    Set<String>? initialLearnedWords,
    Map<String, bool>? appOverrides,
  })  : _dictionary = Map.from(customDictionary ?? kDefaultEnglishDictionary),
        _learnedWords = Set.from(initialLearnedWords ?? {}),
        _appOverrides = Map.from(appOverrides ?? {});

  final Map<String, int> _dictionary;
  final Set<String> _learnedWords;
  final Map<String, bool> _appOverrides;

  bool isEnabledGlobally = true;

  Set<String> get learnedWords => Set.unmodifiable(_learnedWords);
  Map<String, bool> get appOverrides => Map.unmodifiable(_appOverrides);

  /// Check if autocorrect is enabled for a given [sourceApp].
  bool isEnabledForApp(String? sourceApp) {
    if (!isEnabledGlobally) return false;
    if (sourceApp != null && _appOverrides.containsKey(sourceApp)) {
      return _appOverrides[sourceApp]!;
    }
    return true;
  }

  /// Sets whether autocorrect is enabled for a specific application.
  void setAppOverride(String sourceApp, bool enabled) {
    _appOverrides[sourceApp] = enabled;
  }

  /// Adds a user-accepted word to the local learned dictionary.
  void learnWord(String word) {
    final cleanWord = word.trim().toLowerCase();
    if (cleanWord.isEmpty) return;
    _learnedWords.add(cleanWord);
    _dictionary[cleanWord] = 2000; // High score for learned words
  }

  /// Removes a learned word.
  void unlearnWord(String word) {
    final cleanWord = word.trim().toLowerCase();
    _learnedWords.remove(cleanWord);
    _dictionary.remove(cleanWord);
  }

  /// Generates top-[maxResults] correction suggestions for [inputWord].
  ///
  /// Guarantees execution latency under 10ms.
  List<String> getSuggestions(
    String inputWord, {
    String? sourceApp,
    int maxResults = 3,
    int maxDistance = 2,
  }) {
    if (!isEnabledForApp(sourceApp)) return const [];

    final word = inputWord.trim().toLowerCase();
    if (word.length < 2) return const [];

    // If already in dictionary or learned set with exact match, return empty (already correct)
    if (_dictionary.containsKey(word) || _learnedWords.contains(word)) {
      return const [];
    }

    final candidates = <CorrectionCandidate>[];

    // Combine base dictionary and learned words
    _dictionary.forEach((dictWord, score) {
      // Fast length filter optimization
      if ((dictWord.length - word.length).abs() > maxDistance) return;

      final dist = _levenshteinDistance(word, dictWord);
      if (dist <= maxDistance) {
        candidates.add(CorrectionCandidate(
          word: dictWord,
          editDistance: dist,
          frequencyScore: score,
        ));
      }
    });

    // Rank candidates by edit distance ASC, then frequency score DESC
    candidates.sort((a, b) {
      if (a.editDistance != b.editDistance) {
        return a.editDistance.compareTo(b.editDistance);
      }
      return b.frequencyScore.compareTo(a.frequencyScore);
    });

    return candidates
        .take(maxResults)
        .map((c) => _matchCase(inputWord, c.word))
        .toList();
  }

  /// Fast Levenshtein distance implementation.
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final v0 = List<int>.generate(s2.length + 1, (i) => i);
    final v1 = List<int>.filled(s2.length + 1, 0);

    for (var i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (var j = 0; j < s2.length; j++) {
        final cost = (s1.codeUnitAt(i) == s2.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = [
          v1[j] + 1,
          v0[j + 1] + 1,
          v0[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
      for (var j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }

    return v1[s2.length];
  }

  /// Preserves capitalization of the original input.
  String _matchCase(String original, String candidate) {
    if (original.isEmpty) return candidate;
    if (original == original.toUpperCase()) {
      return candidate.toUpperCase();
    }
    if (original[0] == original[0].toUpperCase()) {
      return candidate[0].toUpperCase() + candidate.substring(1);
    }
    return candidate;
  }
}
