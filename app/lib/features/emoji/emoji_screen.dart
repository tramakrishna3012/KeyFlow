import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_search_bar.dart';
import 'emoji_data.dart';
import 'emoji_providers.dart';

class EmojiScreen extends ConsumerWidget {
  const EmojiScreen({super.key});

  void _onEmojiTapped(BuildContext context, WidgetRef ref, String emojiChar) {
    ref.read(emojiNotifierProvider).useEmoji(emojiChar);
    Clipboard.setData(ClipboardData(text: emojiChar));

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $emojiChar to clipboard!'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentAsync = ref.watch(recentEmojisProvider);
    final filteredEmojis = ref.watch(filteredEmojisProvider);
    final activeCategory = ref.watch(activeEmojiCategoryProvider);
    final searchQuery = ref.watch(emojiSearchQueryProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                'Emoji Picker',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: KeyFlowSearchBar(
                hintText: 'Search emojis (e.g. fire, heart, party)...',
                onChanged: (val) {
                  ref.read(emojiSearchQueryProvider.notifier).state = val;
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildCategoryTabs(ref, activeCategory),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (searchQuery.isEmpty && activeCategory == null) ...[
                    Text(
                      'Recently Used',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    recentAsync.when(
                      data: (recents) => _buildRecentRow(context, ref, recents),
                      loading: () => const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, stack) => Text(
                        'Error: $err',
                        style: const TextStyle(color: AppColors.destructive),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    activeCategory ??
                        (searchQuery.isNotEmpty
                            ? 'Search Results (${filteredEmojis.length})'
                            : 'All Emojis'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filteredEmojis.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No emojis match your search.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    )
                  else
                    _buildEmojiGrid(context, ref, filteredEmojis),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(WidgetRef ref, String? activeCategory) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            FilterChip(
              selected: activeCategory == null,
              label: const Text('All', style: TextStyle(fontSize: 12)),
              onSelected: (_) {
                ref.read(activeEmojiCategoryProvider.notifier).state = null;
              },
              backgroundColor: AppColors.cardSurface,
              selectedColor: AppColors.primarySubtle,
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            const SizedBox(width: 8),
            ...kEmojiCategories.map((cat) {
              final isSelected = activeCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  onSelected: (_) {
                    ref.read(activeEmojiCategoryProvider.notifier).state = cat;
                  },
                  backgroundColor: AppColors.cardSurface,
                  selectedColor: AppColors.primarySubtle,
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
              );
            }),
          ],
        ),
      );

  Widget _buildRecentRow(
    BuildContext context,
    WidgetRef ref,
    List<String> recents,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: recents
          .map(
            (emoji) => InkWell(
              onTap: () => _onEmojiTapped(context, ref, emoji),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _buildEmojiGrid(
    BuildContext context,
    WidgetRef ref,
    List<EmojiItem> emojis,
  ) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 6,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
    ),
    itemCount: emojis.length,
    itemBuilder: (ctx, idx) {
      final item = emojis[idx];
      return InkWell(
        onTap: () => _onEmojiTapped(context, ref, item.char),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Center(
            child: Tooltip(
              message: '${item.name} (${item.shortcode})',
              child: Text(item.char, style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
      );
    },
  );
}
