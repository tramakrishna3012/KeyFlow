import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../data/supabase_providers.dart';
import 'emoji_data.dart';
import 'emoji_service.dart';

const String kKeyRecentEmojis = 'recent_emojis';

const List<String> kDefaultRecentEmojis = [
  '😊',
  '👍',
  '❤️',
  '🎉',
  '🔥',
  '💯',
  '😂',
  '🙏',
];

final emojiServiceProvider = Provider<EmojiService>(
  (ref) => const EmojiService(),
);

final emojiSearchQueryProvider = StateProvider<String>((ref) => '');

final activeEmojiCategoryProvider = StateProvider<String?>((ref) => null);

final recentEmojisProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  final jsonStr = await repo.getSetting(kKeyRecentEmojis);
  if (jsonStr != null) {
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.cast<String>();
    } on Exception catch (_) {}
  }
  return kDefaultRecentEmojis;
});

/// Dynamically resolves all emojis from Supabase cloud database with static fallback
final allEmojisProvider = Provider<List<EmojiItem>>((ref) {
  final supabaseAsync = ref.watch(supabaseEmojisProvider);
  return supabaseAsync.when(
    data: (rows) {
      if (rows.isEmpty) return kDefaultEmojiDataset;
      return rows.map((r) => EmojiItem(
        char: r['char'] as String? ?? '😀',
        name: r['name'] as String? ?? '',
        shortcode: r['shortcode'] as String? ?? '',
        category: r['category'] as String? ?? 'Symbols & Flags',
        keywords: (r['keywords'] as List<dynamic>?)?.cast<String>() ?? [],
      )).toList();
    },
    loading: () => kDefaultEmojiDataset,
    error: (_, _) => kDefaultEmojiDataset,
  );
});

final filteredEmojisProvider = Provider<List<EmojiItem>>((ref) {
  final query = ref.watch(emojiSearchQueryProvider);
  final category = ref.watch(activeEmojiCategoryProvider);
  final allEmojis = ref.watch(allEmojisProvider);
  final service = EmojiService(dataset: allEmojis);
  return service.searchEmojis(query, category: category);
});

class EmojiNotifier {
  EmojiNotifier(this.ref);
  final Ref ref;

  Future<void> useEmoji(String emojiChar) async {
    final currentList = await ref.read(recentEmojisProvider.future);
    final newList = List<String>.from(currentList)
      ..remove(emojiChar)
      ..insert(0, emojiChar);

    // Keep top 12 recent emojis
    final trimmedList = newList.take(12).toList();

    final repo = ref.read(historyRepositoryProvider);
    final jsonStr = jsonEncode(trimmedList);
    await repo.setSetting(kKeyRecentEmojis, jsonStr);

    ref.invalidate(recentEmojisProvider);
  }
}

final emojiNotifierProvider = Provider<EmojiNotifier>(EmojiNotifier.new);
