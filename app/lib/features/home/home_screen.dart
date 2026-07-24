import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';

/// Home dashboard screen matching the Figma "Home" tab.
///
/// Shows: greeting, 4 stats cards, typing activity chart placeholder,
/// and recent snippets list.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildStatsGrid(),
              const SizedBox(height: 16),
              _buildActivityCard(context),
              const SizedBox(height: 20),
              _buildRecentSnippetsHeader(context),
              const SizedBox(height: 12),
              ..._buildRecentSnippets(),
            ],
          ),
        ),
      );

  Widget _buildHeader(BuildContext context) => Row(
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
                  'Good morning, Alex 👋',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary,
            child: Text(
              'A',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );

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

  Widget _buildStatsGrid() => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: const [
          _StatCard(
            icon: '⌨️',
            value: '3,847',
            label: 'Snippets',
            dotColor: AppColors.primary,
          ),
          _StatCard(
            icon: '📝',
            value: '12.4k',
            label: 'Today typed',
            dotColor: AppColors.secondary,
          ),
          _StatCard(
            icon: '⚡',
            value: '2h 18m',
            label: 'Time saved',
            dotColor: AppColors.accentOrange,
          ),
          _StatCard(
            icon: '🌍',
            value: '6',
            label: 'Languages',
            dotColor: AppColors.accentPink,
          ),
        ],
      );

  Widget _buildActivityCard(BuildContext context) => KeyFlowCard(
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
            const SizedBox(height: 24),
            // Placeholder chart bars
            SizedBox(
              height: 60,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildBar(0.6),
                  _buildBar(0.8),
                  _buildBar(0.4),
                  _buildBar(0.9),
                  _buildBar(0.7),
                  _buildBar(0.3),
                  _buildBar(0.5),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  .map(
                    (d) => Text(
                      d,
                      style: TextStyle(
                        fontSize: 10,
                        color: d == 'S'
                            ? AppColors.primary
                            : AppColors.textMuted,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );

  Widget _buildBar(double heightFraction) => Container(
        width: 24,
        height: 60 * heightFraction,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              AppColors.primary,
              AppColors.secondary,
            ],
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
          Text(
            'See all',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      );

  List<Widget> _buildRecentSnippets() => [
        const _SnippetCard(
          text: 'Hi! Thanks for reaching out. Let me get back to you shortly.',
          category: 'greeting',
          timeAgo: '2m ago',
        ),
        const SizedBox(height: 8),
        const _SnippetCard(
          text: 'Please find the attached document for your reference.',
          category: 'email',
          timeAgo: '15m ago',
        ),
        const SizedBox(height: 8),
        const _SnippetCard(
          text:
              'Let me know if you have any questions or need clarification.',
          category: 'closing',
          timeAgo: '1h ago',
        ),
      ];
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
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ),
      );
}

class _SnippetCard extends StatelessWidget {
  const _SnippetCard({
    required this.text,
    required this.category,
    required this.timeAgo,
  });

  final String text;
  final String category;
  final String timeAgo;

  Color get _categoryColor {
    switch (category) {
      case 'greeting':
        return AppColors.tagGreeting;
      case 'email':
        return AppColors.tagEmail;
      case 'closing':
        return AppColors.tagClosing;
      case 'meeting':
        return AppColors.tagMeeting;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) => KeyFlowCard(
        padding: const EdgeInsets.all(14),
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
                    text,
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
                          category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _categoryColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style:
                            Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      );
}
