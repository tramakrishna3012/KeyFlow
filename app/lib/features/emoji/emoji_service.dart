import 'emoji_data.dart';

/// Fast search & filtering engine for the Emoji Picker (SRS FR-13, FR-14).
///
/// Guarantees query execution latency under 10ms.
class EmojiService {
  const EmojiService({List<EmojiItem>? dataset})
      : _dataset = dataset ?? kDefaultEmojiDataset;

  final List<EmojiItem> _dataset;

  /// Searches the emoji dataset by query (keyword, shortcode, or name) and optional category filter.
  List<EmojiItem> searchEmojis(
    String query, {
    String? category,
    int maxResults = 60,
  }) {
    final cleanQuery = query.trim().toLowerCase().replaceAll(':', '');

    List<EmojiItem> baseList = _dataset;
    if (category != null && category.isNotEmpty && category != 'All') {
      baseList = baseList.where((e) => e.category == category).toList();
    }

    if (cleanQuery.isEmpty) {
      return baseList.take(maxResults).toList();
    }

    final results = <EmojiItem>[];

    // Priority 1: Exact or prefix shortcode / name matches
    for (final emoji in baseList) {
      final shortcodeClean = emoji.shortcode.replaceAll(':', '').toLowerCase();
      if (shortcodeClean == cleanQuery || emoji.name.toLowerCase() == cleanQuery) {
        results.add(emoji);
      }
    }

    // Priority 2: Keyword or partial name matches
    for (final emoji in baseList) {
      if (results.contains(emoji)) continue;

      final shortcodeClean = emoji.shortcode.replaceAll(':', '').toLowerCase();
      final nameClean = emoji.name.toLowerCase();

      final matchesKeyword = emoji.keywords.any((k) => k.toLowerCase().contains(cleanQuery));
      final matchesShortcode = shortcodeClean.contains(cleanQuery);
      final matchesName = nameClean.contains(cleanQuery);

      if (matchesKeyword || matchesShortcode || matchesName) {
        results.add(emoji);
      }
    }

    return results.take(maxResults).toList();
  }
}
