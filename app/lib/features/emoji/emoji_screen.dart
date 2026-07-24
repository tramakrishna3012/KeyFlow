import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_search_bar.dart';

/// Emoji picker screen matching the Figma "Emoji" tab.
///
/// Shows: search bar, category tabs, recently used row,
/// and a scrollable emoji grid.
class EmojiScreen extends StatefulWidget {
  const EmojiScreen({super.key});

  @override
  State<EmojiScreen> createState() => _EmojiScreenState();
}

class _EmojiScreenState extends State<EmojiScreen> {
  int _activeCategory = 0;

  static const _categories = ['😊', '👋', '❤️', '💡', '✨'];

  static const _recentEmojis = ['😊', '👍', '❤️', '🎉', '🔥', '💯', '😂', '🙏'];

  static const _smileys = [
    '😀', '😃', '😄', '😁', '😆', '🥹', '😅', '🤣',
    '😂', '🙂', '🙃', '😉', '😊', '😇', '🥰', '😍',
    '🤩', '😘', '😗', '😚', '😙', '🥲', '😋', '😛',
    '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
    '🫡', '🤐', '🤨', '😐', '😑', '😶', '🫥', '😏',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: KeyFlowSearchBar(hintText: 'Search emojis...'),
              ),
              const SizedBox(height: 16),
              _buildCategoryTabs(),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    Text(
                      'Recently used',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textMuted,
                              ),
                    ),
                    const SizedBox(height: 12),
                    _buildEmojiRow(_recentEmojis),
                    const SizedBox(height: 24),
                    Text(
                      'Smileys',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textMuted,
                              ),
                    ),
                    const SizedBox(height: 12),
                    _buildEmojiGrid(_smileys),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildCategoryTabs() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            _categories.length,
            (index) => GestureDetector(
              onTap: () => setState(() => _activeCategory = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _activeCategory == index
                      ? AppColors.primarySubtle
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _activeCategory == index
                        ? AppColors.primaryBorderActive
                        : AppColors.cardBorder,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  _categories[index],
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _buildEmojiRow(List<String> emojis) => Wrap(
        spacing: 8,
        children: emojis
            .map(
              (emoji) => GestureDetector(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.cardBorder,
                      width: 0.8,
                    ),
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
            )
            .toList(),
      );

  Widget _buildEmojiGrid(List<String> emojis) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: emojis.length,
        itemBuilder: (_, index) => GestureDetector(
          onTap: () {},
          child: Center(
            child: Text(
              emojis[index],
              style: const TextStyle(fontSize: 26),
            ),
          ),
        ),
      );
}
