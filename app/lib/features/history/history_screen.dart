import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_search_bar.dart';
import '../../data/models/history_entry.dart';
import 'history_providers.dart';

/// Redesigned KeyFlow History Screen matching the approved 2-level grouped layout:
/// Level 1: Date Section Header (Today, Yesterday, Mon, 24 Aug) + count badge
/// Level 2: App Card (Icon, App Title, Package) -> List of timestamped entries with copy affordance
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedEntryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
        ..invalidate(historyEntriesProvider)
        ..invalidate(allHistoryEntriesProvider)
        ..invalidate(availableAppChipsProvider);
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
      backgroundColor: AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Snippet History',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                    onPressed: () {
                      ref
                        ..invalidate(historyEntriesProvider)
                        ..invalidate(allHistoryEntriesProvider)
                        ..invalidate(availableAppChipsProvider);
                    },
                    tooltip: 'Refresh History',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
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
            const SizedBox(height: 14),
            _buildDynamicAppFilters(activeTag),
            const SizedBox(height: 10),
            Expanded(
              child: historyAsync.when(
                data: (entries) {
                  if (entries.isEmpty) {
                    return _buildEmptyState();
                  }

                  final grouped = _groupEntries(entries);

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 6,
                    ),
                    itemCount: grouped.length,
                    itemBuilder: (context, dateIndex) {
                      final dateHeader = grouped.keys.elementAt(dateIndex);
                      final appMap = grouped[dateHeader]!;

                      var totalEntriesForDate = 0;
                      for (final list in appMap.values) {
                        totalEntriesForDate += list.length;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Level 1 Date Header
                          _buildDateHeader(dateHeader, totalEntriesForDate),
                          // Level 2 App Cards
                          ...appMap.entries.map(
                            (appEntry) => _buildAppCard(
                              context,
                              appEntry.key,
                              appEntry.value,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
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

  Widget _buildDynamicAppFilters(String activeTag) {
    final chipsAsync = ref.watch(availableAppChipsProvider);

    return chipsAsync.when(
      data: (chips) => SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, index) {
            final tag = chips[index];
            final isActive = tag == activeTag;
            return GestureDetector(
              onTap: () {
                ref.read(activeTagProvider.notifier).state = tag;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive ? AppColors.primary : AppColors.cardBorder,
                    width: 0.8,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
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
      ),
      loading: () => const SizedBox(height: 34),
      error: (_, _) => const SizedBox(height: 34),
    );
  }

  Widget _buildDateHeader(String dateHeader, int totalCount) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          dateHeader.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFFB45309), // amber-700
            letterSpacing: 0.8,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: AppColors.scaffoldBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Text(
            '$totalCount ${totalCount == 1 ? 'entry' : 'entries'}',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildAppCard(
    BuildContext context,
    String sourceApp,
    List<HistoryEntry> items,
  ) {
    final meta = getAppVisualMeta(sourceApp);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Header
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: meta.iconBg,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: meta.iconBg.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(meta.icon, size: 14, color: meta.iconColor),
              ),
              const SizedBox(width: 8),
              Text(
                meta.displayName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  sourceApp,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 10),
          // Entries
          ...items.map((entry) => _buildEntryRow(context, entry)),
        ],
      ),
    );
  }

  Widget _buildEntryRow(BuildContext context, HistoryEntry entry) {
    final isSelected = _selectedEntryId == entry.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          SizedBox(
            width: 58,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _formatEntryTime(entry.capturedAt),
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Text box
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedEntryId = isSelected ? null : entry.id;
                });
              },
              onLongPress: () {
                _copyToClipboard(context, entry.text);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryGhost
                      : AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.cardBorder,
                    width: isSelected ? 1.2 : 0.8,
                  ),
                ),

                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 28),
                      child: Text(
                        entry.text,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: InkWell(
                        onTap: () => _copyToClipboard(context, entry.text),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isSelected
                                ? Icons.check_rounded
                                : Icons.copy_rounded,
                            size: 14,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Copied to clipboard'),
          ],
        ),
        backgroundColor: AppColors.textPrimary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  Map<String, Map<String, List<HistoryEntry>>> _groupEntries(
    List<HistoryEntry> entries,
  ) {
    final grouped = <String, Map<String, List<HistoryEntry>>>{};
    for (final entry in entries) {
      final dateHeader = _formatDateHeader(entry.capturedAt);
      grouped.putIfAbsent(dateHeader, () => {});
      grouped[dateHeader]!.putIfAbsent(entry.sourceApp, () => []).add(entry);
    }
    return grouped;
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(date).inDays;

    if (diffDays == 0) {
      return 'Today';
    } else if (diffDays == 1) {
      return 'Yesterday';
    } else {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final weekday = weekdays[dt.weekday - 1];
      final month = months[dt.month - 1];
      return '$weekday, ${dt.day} $month';
    }
  }

  String _formatEntryTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute $period';
  }
}
