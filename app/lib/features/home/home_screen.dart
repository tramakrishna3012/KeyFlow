import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/auto_update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';
import '../../data/models/history_entry.dart';
import '../../data/providers.dart';
import '../history/history_providers.dart';
import '../history/snippet_detail_screen.dart';

/// Dynamic, responsive Home dashboard screen showing real live typing data from SQLite repository.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(allHistoryEntriesProvider);

    return Scaffold(
      body: SafeArea(
        child: historyAsync.when(
          data: (entries) => _buildDashboard(context, ref, entries),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => _buildDashboard(context, ref, []),
        ),
      ),
    );
  }

  Widget _buildDashboard(
    BuildContext context,
    WidgetRef ref,
    List<HistoryEntry> entries,
  ) {
    final now = DateTime.now();

    // 1. Calculate Real Dynamic Statistics
    final totalSnippets = entries.length;

    // Filter today's entries
    final todayEntries = entries.where((e) =>
        e.capturedAt.year == now.year &&
        e.capturedAt.month == now.month &&
        e.capturedAt.day == now.day).toList();

    // Calculate total characters typed today
    final todayChars = todayEntries.fold<int>(
      0,
      (sum, item) => sum + item.text.length,
    );

    // Calculate total characters typed overall for time saved
    final totalCharsOverall = entries.fold<int>(
      0,
      (sum, item) => sum + item.text.length,
    );

    // Time saved calculation (assume 40 WPM ~ 200 chars/min savings)
    final totalMinutesSaved = (totalCharsOverall / 200).round();
    final timeSavedStr = totalMinutesSaved >= 60
        ? '${totalMinutesSaved ~/ 60}h ${totalMinutesSaved % 60}m'
        : '${totalMinutesSaved}m';

    // Unique active apps
    final uniqueAppsCount = entries.map((e) => e.sourceApp).toSet().length;

    // Weekly activity distribution (past 7 days: Mon..Sun)
    final weeklyCounts = _calculateWeeklyActivity(entries, now);

    // Top 3 recent snippets
    final recentSnippets = entries.take(3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final gridAspectRatio = isWide ? 2.2 : 1.55;

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.refresh(allHistoryEntriesProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              const _AutoUpdateBanner(),
              const SizedBox(height: 12),
              if (defaultTargetPlatform == TargetPlatform.android) ...[
                _KeyboardConnectionBanner(ref: ref),
                const SizedBox(height: 16),
              ],
              _buildStatsGrid(
                gridAspectRatio: gridAspectRatio,
                totalSnippets: totalSnippets,
                todayChars: todayChars,
                timeSavedStr: timeSavedStr,
                uniqueAppsCount: uniqueAppsCount,
              ),
              const SizedBox(height: 20),
              _buildActivityCard(context, weeklyCounts, now.weekday),
              const SizedBox(height: 24),
              _buildRecentSnippetsHeader(context),
              const SizedBox(height: 12),
              if (recentSnippets.isEmpty)
                _buildEmptySnippetsPrompt(context)
              else
                ...recentSnippets.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SnippetCard(entry: entry),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Good morning 👋';
    } else if (hour < 17) {
      greeting = 'Good afternoon 👋';
    } else {
      greeting = 'Good evening 👋';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formattedDate,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                greeting,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
        const CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.primary,
          child: Text(
            'K',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  String get _formattedDate {
    final now = DateTime.now();
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Widget _buildStatsGrid({
    required double gridAspectRatio,
    required int totalSnippets,
    required int todayChars,
    required String timeSavedStr,
    required int uniqueAppsCount,
  }) {
    final formattedTodayChars = todayChars >= 1000
        ? '${(todayChars / 1000).toStringAsFixed(1)}k'
        : '$todayChars';

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: gridAspectRatio,
      children: [
        _StatCard(
          icon: '⌨️',
          value: _formatNumber(totalSnippets),
          label: 'Snippets',
          dotColor: AppColors.primary,
        ),
        _StatCard(
          icon: '📝',
          value: formattedTodayChars,
          label: 'Chars today',
          dotColor: AppColors.secondary,
        ),
        _StatCard(
          icon: '⚡',
          value: timeSavedStr,
          label: 'Time saved',
          dotColor: AppColors.accentOrange,
        ),
        _StatCard(
          icon: '📱',
          value: '$uniqueAppsCount',
          label: 'Active apps',
          dotColor: AppColors.accentPink,
        ),
      ],
    );
  }

  Widget _buildActivityCard(
    BuildContext context,
    List<int> weeklyCounts,
    int currentWeekday,
  ) {
    final maxCount = weeklyCounts.fold<int>(1, (max, v) => v > max ? v : max);

    return KeyFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Typing Activity',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'This week',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (index) {
                final count = weeklyCounts[index];
                final fraction = count == 0 ? 0.08 : (count / maxCount);
                final isToday = (index + 1) == currentWeekday;
                return _buildBar(fraction, isToday: isToday);
              }),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
              final isToday = (index + 1) == currentWeekday;
              return Text(
                dayLabels[index],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? AppColors.primary : AppColors.textMuted,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(double heightFraction, {bool isToday = false}) => Container(
        width: 22,
        height: 64 * heightFraction.clamp(0.08, 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: isToday
                ? [AppColors.primary, AppColors.secondary]
                : [AppColors.cardSurface, AppColors.primary.withValues(alpha: 0.4)],
          ),
        ),
      );

  Widget _buildRecentSnippetsHeader(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Recent Snippets',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          InkWell(
            onTap: () => context.go('/history'),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'See all',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
            ),
          ),
        ],
      );

  Widget _buildEmptySnippetsPrompt(BuildContext context) => KeyFlowCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.keyboard_alt_outlined, size: 36, color: AppColors.primary),
            const SizedBox(height: 10),
            Text(
              'No snippets captured yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Start typing in any app or software to see your live snippets and history appear right here!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      );

  List<int> _calculateWeeklyActivity(
    List<HistoryEntry> entries,
    DateTime now,
  ) {
    // Determine Monday date of current week
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonday = DateTime(monday.year, monday.month, monday.day);

    final counts = List<int>.filled(7, 0);

    for (final entry in entries) {
      if (entry.capturedAt.isAfter(startOfMonday)) {
        final diffDays = entry.capturedAt.difference(startOfMonday).inDays;
        if (diffDays >= 0 && diffDays < 7) {
          counts[diffDays]++;
        }
      }
    }

    return counts;
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return '$number';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.dotColor,
  });

  final String icon;
  final String value;
  final String label;
  final Color dotColor;

  @override
  Widget build(BuildContext context) => KeyFlowCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      );
}

class _SnippetCard extends StatelessWidget {
  const _SnippetCard({required this.entry});

  final HistoryEntry entry;

  Color get _categoryColor {
    final cat = entry.category?.toLowerCase() ?? '';
    if (cat.contains('greeting')) return AppColors.tagGreeting;
    if (cat.contains('email')) return AppColors.tagEmail;
    if (cat.contains('closing')) return AppColors.tagClosing;
    if (cat.contains('meeting')) return AppColors.tagMeeting;
    return AppColors.primary;
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(entry.capturedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) => KeyFlowCard(
        padding: const EdgeInsets.all(14),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SnippetDetailScreen(entry: entry),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: _categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _categoryColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            entry.sourceApp,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _categoryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: entry.text));
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied snippet to clipboard!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
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
                    'Copy',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _KeyboardConnectionBanner extends StatefulWidget {
  const _KeyboardConnectionBanner({required this.ref});
  final WidgetRef ref;

  @override
  State<_KeyboardConnectionBanner> createState() => _KeyboardConnectionBannerState();
}

class _KeyboardConnectionBannerState extends State<_KeyboardConnectionBanner> {
  bool _isEnabled = true;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final captureService = widget.ref.read(captureServiceProvider);
    final enabled = await captureService.isAccessibilityServiceEnabled();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || _isEnabled) return const SizedBox.shrink();

    final captureService = widget.ref.read(captureServiceProvider);

    return KeyFlowCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.keyboard_alt_outlined, color: AppColors.accentOrange, size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Keyboard Connection Required',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'KeyFlow requires Accessibility Service permission in Android Settings to observe typed text across your apps.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                await captureService.openAccessibilitySettings();
                await Future.delayed(const Duration(seconds: 1));
                await _checkStatus();
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Connect Keyboard in Settings'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoUpdateBanner extends StatefulWidget {
  const _AutoUpdateBanner();

  @override
  State<_AutoUpdateBanner> createState() => _AutoUpdateBannerState();
}

class _AutoUpdateBannerState extends State<_AutoUpdateBanner> {
  UpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final service = AutoUpdateService();
    final info = await service.checkForUpdate();
    if (mounted && info != null && info.hasUpdate) {
      setState(() => _updateInfo = info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _updateInfo;
    if (info == null || !info.hasUpdate) return const SizedBox.shrink();

    final service = AutoUpdateService();

    return KeyFlowCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Update Available (v${info.latestVersion})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                onPressed: () => setState(() => _updateInfo = null),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'A new version of KeyFlow (v${info.latestVersion}) is available. Tap below to download the latest APK directly.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async => service.launchDownloadUrl(info.downloadUrl),
              icon: const Icon(Icons.download_rounded, size: 18),
              label: Text('Download Update (v${info.latestVersion})'),
            ),
          ),
        ],
      ),
    );
  }
}

