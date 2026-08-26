import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';
import '../../core/widgets/keyflow_search_bar.dart';
import '../../data/models/history_entry.dart';
import 'history_providers.dart';
import 'snippet_detail_screen.dart';

/// Snippet history screen matching SRS FR-7/FR-8 and UIUX §2.2-2.3.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const _tags = [
    'All',
    'notepad',
    'chrome',
    'code',
    'terminal',
    'safari',
    'email',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(historyEntriesProvider);
      ref.invalidate(allHistoryEntriesProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTag = ref.watch(activeTagProvider);
    final historyAsync = ref.watch(historyEntriesProvider);

    return Scaffold(
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: KeyFlowSearchBar(
                controller: _searchController,
                hintText: 'Search history entries...',
                onChanged: (value) {
                  ref.read(searchQueryProvider.notifier).state = value;
                },
              ),
            ),
            const SizedBox(height: 16),
            _buildTagFilters(activeTag),
            const SizedBox(height: 12),
            Expanded(
              child: historyAsync.when(
                data: (entries) => entries.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return Dismissible(
                            key: Key(entry.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),

                              child: const Icon(
                                Icons.delete_outline,
                                color: AppColors.error,
                              ),
                            ),
                            onDismissed: (_) {
                              ref
                                  .read(historyNotifierProvider.notifier)
                                  .deleteEntry(entry.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Entry deleted'),
                                  duration: Duration(seconds: 1),
                                ),
                              );
                            },
                            child: _buildSnippetCard(context, entry),
                          );
                        },
                      ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(
                  child: Text(
                    'Error loading history: $err',
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagFilters(String activeTag) => SizedBox(
    height: 34,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _tags.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (_, index) {
        final tag = _tags[index];
        final isActive = tag == activeTag;
        return GestureDetector(
          onTap: () {
            ref.read(activeTagProvider.notifier).state = tag;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.cardBorder,
                width: 0.8,
              ),
            ),
            child: Text(
              tag,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _buildSnippetCard(BuildContext context, HistoryEntry entry) {
    final categoryColor = _colorForApp(entry.sourceApp);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => SnippetDetailScreen(entry: entry),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: KeyFlowCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
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
                    entry.sourceApp,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: categoryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimeAgo(entry.capturedAt),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: entry.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied & ready to insert!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGhost,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Insert',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.history_toggle_off,
          size: 48,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: 12),
        const Text(
          'No history entries found',
          style: TextStyle(color: AppColors.textMuted, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          'Start typing in any app to build your history',
          style: TextStyle(
            color: AppColors.textMuted.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );

  Color _colorForApp(String sourceApp) {
    final lower = sourceApp.toLowerCase();
    if (lower.contains('chrome') ||
        lower.contains('browser') ||
        lower.contains('safari')) {
      return AppColors.tagEmail;
    } else if (lower.contains('code') || lower.contains('terminal')) {
      return AppColors.tagMeeting;
    } else if (lower.contains('1password') || lower.contains('bitwarden')) {
      return AppColors.tagApology;
    }
    return AppColors.primary;
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
