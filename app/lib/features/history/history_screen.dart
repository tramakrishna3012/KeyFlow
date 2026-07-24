import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';
import '../../core/widgets/keyflow_search_bar.dart';

/// Snippet history screen matching the Figma "History" tab.
///
/// Shows: search bar, horizontal tag filter pills, scrollable
/// snippet cards with category, use count, timestamp, and copy action.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _activeTag = 'All';

  static const _tags = [
    'All',
    'greeting',
    'email',
    'closing',
    'meeting',
    'apology',
    'legal',
    'signature',
    'code',
  ];

  static const _snippets = [
    _Snippet(
      text: 'Hi! Thanks for reaching out. Let me get back to you shortly.',
      category: 'greeting',
      uses: 284,
      timeAgo: '2m ago',
    ),
    _Snippet(
      text: 'Please find the attached document for your reference.',
      category: 'email',
      uses: 193,
      timeAgo: '15m ago',
    ),
    _Snippet(
      text: 'Let me know if you have any questions or need clarification.',
      category: 'closing',
      uses: 512,
      timeAgo: '1h ago',
    ),
    _Snippet(
      text: 'Can we schedule a quick call this week to discuss?',
      category: 'meeting',
      uses: 147,
      timeAgo: '3h ago',
    ),
    _Snippet(
      text:
          'Sorry for the delayed response — been swamped lately!',
      category: 'apology',
      uses: 89,
      timeAgo: '5h ago',
    ),
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
                  'Snippet History',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: KeyFlowSearchBar(hintText: 'Search snippets...'),
              ),
              const SizedBox(height: 16),
              _buildTagFilters(),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredSnippets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _buildSnippetCard(context, _filteredSnippets[index]),
                ),
              ),
            ],
          ),
        ),
      );

  List<_Snippet> get _filteredSnippets => _activeTag == 'All'
      ? _snippets
      : _snippets.where((s) => s.category == _activeTag).toList();

  Widget _buildTagFilters() => SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _tags.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final tag = _tags[index];
            final isActive = tag == _activeTag;
            return GestureDetector(
              onTap: () => setState(() => _activeTag = tag),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.cardBorder,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
              ),
            );
          },
        ),
      );

  Widget _buildSnippetCard(BuildContext context, _Snippet snippet) {
    final categoryColor = _colorForCategory(snippet.category);
    return KeyFlowCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            snippet.text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  snippet.category,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${snippet.uses} uses · ${snippet.timeAgo}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGhost,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Copy',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'greeting':
        return AppColors.tagGreeting;
      case 'email':
        return AppColors.tagEmail;
      case 'closing':
        return AppColors.tagClosing;
      case 'meeting':
        return AppColors.tagMeeting;
      case 'apology':
        return AppColors.tagApology;
      default:
        return AppColors.primary;
    }
  }
}

class _Snippet {
  const _Snippet({
    required this.text,
    required this.category,
    required this.uses,
    required this.timeAgo,
  });

  final String text;
  final String category;
  final int uses;
  final String timeAgo;
}
