import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers.dart';
import '../../data/sqlite_history_repository.dart';
import 'emoji_data.dart';
import 'emoji_service.dart';

const String kKeyRecentEmojis = 'recent_emojis';

const List<String> kDefaultRecentEmojis = [
  '😊', '👍', '❤️', '🎉', '🔥', '💯', '😂', '🙏'
];

final emojiServiceProvider = Provider<EmojiService>((ref) => const EmojiService());

final emojiSearchQueryProvider = StateProvider<String>((ref) => '');

final activeEmojiCategoryProvider = StateProvider<String?>((ref) => null);

List<String> _inMemoryRecentEmojis = List.from(kDefaultRecentEmojis);

final recentEmojisProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(historyRepositoryProvider);
  if (repo is SqliteHistoryRepository) {
    final jsonStr = await repo.getSetting(kKeyRecentEmojis);
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        _inMemoryRecentEmojis = decoded.cast<String>();
      } on Object catch (_) {}
    }
  }
  return List.unmodifiable(_inMemoryRecentEmojis);
});

final filteredEmojisProvider = Provider<List<EmojiItem>>((ref) {
  final service = ref.watch(emojiServiceProvider);
  final query = ref.watch(emojiSearchQueryProvider);
  final category = ref.watch(activeEmojiCategoryProvider);
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
    _inMemoryRecentEmojis = trimmedList;

    final repo = ref.read(historyRepositoryProvider);
    if (repo is SqliteHistoryRepository) {
      final jsonStr = jsonEncode(trimmedList);
      await repo.setSetting(kKeyRecentEmojis, jsonStr);
    }

    ref.invalidate(recentEmojisProvider);
  }
}

final emojiNotifierProvider = Provider<EmojiNotifier>(EmojiNotifier.new);
