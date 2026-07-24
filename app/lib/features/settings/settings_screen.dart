import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';

/// Settings screen matching the Figma "Settings" tab.
///
/// Shows: profile card, Typing section (autocorrect, haptic, layout),
/// Privacy section (local storage, clear history, analytics),
/// and Appearance section placeholder.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _autoCorrect = true;
  bool _hapticFeedback = true;
  bool _localStorageOnly = true;
  bool _usageAnalytics = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                'Settings',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              _buildProfileCard(context),
              const SizedBox(height: 24),
              _buildSectionLabel(context, 'TYPING'),
              const SizedBox(height: 8),
              _buildSection([
                _SettingsTile(
                  icon: Icons.auto_fix_high_rounded,
                  iconColor: AppColors.accentOrange,
                  title: 'Auto-Correct',
                  subtitle: 'Context-aware corrections',
                  trailing: Switch(
                    value: _autoCorrect,
                    onChanged: (v) => setState(() => _autoCorrect = v),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.vibration_rounded,
                  iconColor: AppColors.primary,
                  title: 'Haptic Feedback',
                  subtitle: 'Vibrate on key press',
                  trailing: Switch(
                    value: _hapticFeedback,
                    onChanged: (v) => setState(() => _hapticFeedback = v),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.keyboard_rounded,
                  iconColor: AppColors.textMuted,
                  title: 'Keyboard Layout',
                  subtitle: 'QWERTY',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionLabel(context, 'PRIVACY'),
              const SizedBox(height: 8),
              _buildSection([
                _SettingsTile(
                  icon: Icons.lock_rounded,
                  iconColor: AppColors.accentOrange,
                  title: 'Local Storage Only',
                  subtitle: 'Never sync to cloud',
                  trailing: Switch(
                    value: _localStorageOnly,
                    onChanged: (v) =>
                        setState(() => _localStorageOnly = v),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: AppColors.accentPink,
                  title: 'Clear History',
                  subtitle: '3,847 snippets',
                  trailing: GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        color: AppColors.destructive,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                _SettingsTile(
                  icon: Icons.bar_chart_rounded,
                  iconColor: AppColors.primary,
                  title: 'Usage Analytics',
                  subtitle: 'Anonymous telemetry off',
                  trailing: Switch(
                    value: _usageAnalytics,
                    onChanged: (v) =>
                        setState(() => _usageAnalytics = v),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _buildSectionLabel(context, 'APPEARANCE'),
              const SizedBox(height: 8),
              _buildSection([
                _SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  iconColor: AppColors.secondary,
                  title: 'Dark Mode',
                  subtitle: 'Currently active',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
      );

  Widget _buildProfileCard(BuildContext context) => KeyFlowCard(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text(
                  'A',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alex Johnson',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'alex@acme.com',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGhost,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Pro Plan',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
            ),
          ],
        ),
      );

  Widget _buildSectionLabel(BuildContext context, String label) => Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: AppColors.textMuted,
            ),
      );

  Widget _buildSection(List<_SettingsTile> tiles) => KeyFlowCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: List.generate(
            tiles.length,
            (index) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: tiles[index],
                ),
                if (index < tiles.length - 1)
                  const Divider(height: 0, indent: 52),
              ],
            ),
          ),
        ),
      );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      );
}
