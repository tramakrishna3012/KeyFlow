import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auto_update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';
import '../../data/providers.dart';
import '../auth/auth_modal.dart';
import '../profile/profile_modal.dart';
import 'excluded_apps_screen.dart';
import 'settings_providers.dart';


class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(accessibilityServiceEnabledProvider);
      ref.read(capturePausedProvider.notifier).syncWithNative();
    }
  }

  @override
  Widget build(BuildContext context) {
    final exclusionAsync = ref.watch(exclusionListProvider);
    final retentionAsync = ref.watch(retentionDaysProvider);
    final autocorrectAsync = ref.watch(autocorrectEnabledProvider);
    final targetLangAsync = ref.watch(targetLanguageProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 20),

            // 0. USER ACCOUNT & PROFILE SECTION
            _buildSectionHeader('ACCOUNT & PROFILE'),
            const SizedBox(height: 8),
            _buildAccountCard(),

            const SizedBox(height: 24),

            // 1. TYPING CAPTURE CONTROL SECTION
            _buildSectionHeader('TYPING CAPTURE CONTROL'),
            const SizedBox(height: 8),
            _buildPauseCaptureCard(),
            const SizedBox(height: 12),
            _buildFloatingBubbleCard(),

            const SizedBox(height: 24),


            // 2. EXCLUSION LIST SECTION
            _buildSectionHeader('EXCLUSION LIST'),
            const SizedBox(height: 8),
            _buildExclusionCard(exclusionAsync),

            const SizedBox(height: 24),

            // 3. RETENTION POLICY SECTION
            _buildSectionHeader('DATA RETENTION'),
            const SizedBox(height: 8),
            _buildRetentionCard(retentionAsync),

            const SizedBox(height: 24),

            // 4. AUTOCORRECT & TYPING SECTION
            _buildSectionHeader('AUTOCORRECT & TYPING'),
            const SizedBox(height: 8),
            _buildAutocorrectCard(autocorrectAsync),

            const SizedBox(height: 24),

            // 5. TRANSLATION SECTION
            _buildSectionHeader('TRANSLATION'),
            const SizedBox(height: 8),
            _buildTranslationCard(targetLangAsync),

            const SizedBox(height: 24),

            // 6. DATA MANAGEMENT SECTION
            _buildSectionHeader('DATA MANAGEMENT'),
            const SizedBox(height: 8),
            _buildDataManagementCard(),

            const SizedBox(height: 24),

            // 7. ABOUT & UNINSTALL SECTION
            _buildSectionHeader('ABOUT & UNINSTALL'),
            const SizedBox(height: 8),
            _buildAboutCard(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: AppColors.textMuted,
    ),
  );

  // 0. User Account Card
  Widget _buildAccountCard() {
    final user = ref.watch(currentUserProvider);

    final name = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : (user?.email.split('@')[0] ?? 'Local User');
    final email = user?.email ?? 'Operating in Local-Only Mode';
    final role = user?.role == 'admin' ? 'Administrator' : 'Verified Member';

    return KeyFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => ProfileModal.show(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'K',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => ProfileModal.show(context),
                  icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                  label: const Text('Manage Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryLight,
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () {
                  AuthModal.show(context);
                },
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Switch Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Quick Typing Capture Control Card
  Widget _buildPauseCaptureCard() {
    final isPaused = ref.watch(capturePausedProvider);
    final a11yAsync = ref.watch(accessibilityServiceEnabledProvider);
    final isA11yEnabled = a11yAsync.value ?? false;

    return KeyFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPaused ? Icons.pause_circle_outline : Icons.play_circle_outline,
                size: 20,
                color: isPaused ? AppColors.accentOrange : AppColors.secondary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Pause Typing Capture',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: isPaused,
                onChanged: (val) {
                  ref.read(capturePausedProvider.notifier).setPaused(val);
                },
                activeColor: AppColors.accentOrange,
                activeTrackColor: AppColors.accentOrange.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Turn this off before using banking or payment apps that block accessibility services, then back on when done.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          if (isPaused) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentOrange.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.accentOrange,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Capture is paused. Keystrokes are not being recorded.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accentOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isA11yEnabled
                        ? 'Tap KeyFlow in the list, then toggle it off'
                        : 'Tap KeyFlow in the list, then toggle it on',
                  ),
                  duration: const Duration(seconds: 3),
                ),
              );
              ref.read(capturePausedProvider.notifier).openAccessibilitySettings();
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.accessibility_new_rounded,
                    size: 18,
                    color: isA11yEnabled ? AppColors.secondary : AppColors.accentOrange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Open Android Accessibility Settings',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isA11yEnabled
                              ? 'OS Permission: Active (Listening)'
                              : 'OS Permission: Disabled in Settings',
                          style: TextStyle(
                            fontSize: 11,
                            color: isA11yEnabled ? AppColors.secondary : AppColors.accentOrange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isA11yEnabled ? AppColors.secondary : AppColors.accentOrange)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isA11yEnabled ? AppColors.secondary : AppColors.accentOrange)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isA11yEnabled ? 'ON' : 'OFF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isA11yEnabled ? AppColors.secondary : AppColors.accentOrange,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Floating Assistant Overlay Card
  Widget _buildFloatingBubbleCard() {
    final isBubbleActive = ref.watch(floatingBubbleProvider);

    return KeyFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bubble_chart_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Floating Assistant Bubble',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: isBubbleActive,
                onChanged: (val) async {
                  if (val) {
                    final captureService = ref.read(captureServiceProvider);
                    final allowed = await captureService.canDrawOverlays();
                    if (!allowed) {
                      if (context.mounted) {
                        _showOverlayPermissionDialog(context);
                      }
                      return;
                    }
                  }
                  await ref.read(floatingBubbleProvider.notifier).toggleBubble();
                },
                activeColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Display a system-wide draggable assistant bubble on top of other apps for instant pause/resume capture controls.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  isBubbleActive
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 14,
                  color: isBubbleActive
                      ? AppColors.secondary
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isBubbleActive
                        ? 'Floating bubble is active on top of other apps'
                        : 'Requires "Display over other apps" system permission',
                    style: TextStyle(
                      fontSize: 11,
                      color: isBubbleActive
                          ? AppColors.secondary
                          : AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOverlayPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.layers_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Enable Floating Assistant', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'KeyFlow requires the "Display over other apps" permission to show a floating assistant bubble.\n\n'
          'This allows you to quickly pause typing capture before entering sensitive apps without switching windows.\n\n'
          'Tap "Open Settings", find KeyFlow, and enable "Allow display over other apps".',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(captureServiceProvider).requestOverlayPermission();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Exclusion List Card
  Widget _buildExclusionCard(
    AsyncValue<List<String>> exclusionAsync,
  ) => KeyFlowCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.block, size: 20, color: AppColors.primary),
                SizedBox(width: 10),
                Text(
                  'Excluded Applications',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            exclusionAsync.when(
              data: (exclusions) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryGhost,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${exclusions.length} Excluded',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Keystrokes typed in excluded apps are discarded immediately. Banking & payment apps are auto-protected.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.3),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => ExcludedAppsScreen.show(context),
          icon: const Icon(Icons.apps_rounded, size: 16),
          label: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Manage Installed App Exclusions'),
              Icon(Icons.arrow_forward_ios, size: 12),
            ],
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.cardBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        exclusionAsync.when(
          data: (exclusions) => exclusions.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: exclusions.map(
                    (app) => Chip(
                      label: Text(app, style: const TextStyle(fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 13),
                      onDeleted: () {
                        ref.read(settingsControllerProvider).removeExclusion(app);
                      },
                      backgroundColor: AppColors.cardSurface,
                      side: const BorderSide(color: AppColors.cardBorder),
                    ),
                  ).toList(),
                ),
          loading: () => const CircularProgressIndicator(),
          error: (err, _) => Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.destructive),
          ),
        ),
        const Divider(height: 24, color: AppColors.cardBorder),
        // Locked Secure Field Toggle (UIUX §2.4 Rule)
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Auto-exclude secure password fields',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Mandatory OS privacy policy (Locked ON)',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Switch(
              value: true,
              onChanged: null, // Locked ON by default per UIUX §2.4
              activeThumbColor: AppColors.secondary,
            ),
          ],
        ),
      ],
    ),
  );



  // 2. Retention Card
  Widget _buildRetentionCard(AsyncValue<int> retentionAsync) => KeyFlowCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.timer_outlined, size: 20, color: AppColors.accentOrange),
            SizedBox(width: 10),
            Text(
              'Retention Period',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Automatically purge history entries older than the configured duration.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        retentionAsync.when(
          data: (days) => DropdownButton<int>(
            value: days,
            isExpanded: true,
            dropdownColor: AppColors.cardSurface,
            items: const [
              DropdownMenuItem(value: 7, child: Text('7 Days')),
              DropdownMenuItem(value: 30, child: Text('30 Days (Default)')),
              DropdownMenuItem(value: 90, child: Text('90 Days')),
              DropdownMenuItem(value: 365, child: Text('365 Days (1 Year)')),
            ],
            onChanged: (val) {
              if (val != null) {
                ref.read(settingsControllerProvider).updateRetentionDays(val);
              }
            },
          ),
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.destructive),
          ),
        ),
      ],
    ),
  );

  // 3. Autocorrect Card
  Widget _buildAutocorrectCard(AsyncValue<bool> autocorrectAsync) =>
      KeyFlowCard(
        child: autocorrectAsync.when(
          data: (enabled) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enable Autocorrect Suggestions',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Context-aware typing corrections',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ),
              Switch(
                value: enabled,
                onChanged: (v) {
                  ref.read(settingsControllerProvider).setAutocorrectEnabled(v);
                },
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.destructive),
          ),
        ),
      );

  // 4. Translation Card
  Widget _buildTranslationCard(
    AsyncValue<String> targetLangAsync,
  ) => KeyFlowCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.translate, size: 20, color: AppColors.accentPink),
            SizedBox(width: 10),
            Text(
              'Default Target Language',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        targetLangAsync.when(
          data: (lang) => DropdownButton<String>(
            value: lang,
            isExpanded: true,
            dropdownColor: AppColors.cardSurface,
            items: const [
              DropdownMenuItem(value: 'es', child: Text('Spanish (Español)')),
              DropdownMenuItem(value: 'fr', child: Text('French (Français)')),
              DropdownMenuItem(value: 'de', child: Text('German (Deutsch)')),
              DropdownMenuItem(value: 'ja', child: Text('Japanese (日本語)')),
              DropdownMenuItem(value: 'zh', child: Text('Chinese (中文)')),
            ],
            onChanged: (val) {
              if (val != null) {
                ref.read(settingsControllerProvider).setTargetLanguage(val);
              }
            },
          ),
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Text(
            'Error: $err',
            style: const TextStyle(color: AppColors.destructive),
          ),
        ),
      ],
    ),
  );

  // 5. Data Management Card
  Widget _buildDataManagementCard() => KeyFlowCard(
    child: Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.download_rounded,
            color: AppColors.secondary,
          ),
          title: const Text(
            'Export My Data',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: const Text(
            'Export full history snapshot as JSON (SRS FR-21)',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          onTap: _exportData,
        ),
        const Divider(height: 1, color: AppColors.cardBorder),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.delete_forever_rounded,
            color: AppColors.destructive,
          ),
          title: const Text(
            'Delete All Data',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.destructive,
            ),
          ),
          subtitle: const Text(
            'Irreversibly clear all stored history entries immediately',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          onTap: _confirmDeleteAll,
        ),
      ],
    ),
  );

  Future<void> _exportData() async {
    final jsonStr = await ref
        .read(settingsControllerProvider)
        .exportHistoryData();
    if (!mounted) return;

    await showDialog(
      context: context,

      builder: (ctx) => AlertDialog(
        title: const Text('Export Data Snapshot'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonStr));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export JSON copied to clipboard!'),
                ),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Copy JSON'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All History Data?'),
        content: const Text(
          'This will immediately and irreversibly delete all captured snippet history from your local encrypted database.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(settingsControllerProvider).deleteAllHistoryData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All history data deleted.')),
                );
              }
            },
            child: const Text(
              'Delete All',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // 6. About & Uninstall Card
  Widget _buildAboutCard() => KeyFlowCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.info_outline, size: 20, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              'KeyFlow v1.0.0 (${defaultTargetPlatform.name})',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Status: Active & Transparently Running',
          style: TextStyle(fontSize: 12, color: AppColors.secondary),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking for updates...')),
              );
              final updater = AutoUpdateService();
              final update = await updater.checkForUpdate();
              if (mounted) {
                if (update != null) {
                  await updater.showUpdatePrompt(
                    context,
                    update,
                    isManualCheck: true,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Unable to reach update server.'),
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Check for Updates'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Uninstall & Data Cleanup Instructions',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                defaultTargetPlatform == TargetPlatform.windows
                    ? r'Windows Cleanup: Run "Delete All Data" above, then uninstall via Settings → Installed Apps. Local database at %APPDATA%\KeyFlow is wiped upon deletion.'
                    : 'Platform Cleanup: Run "Delete All Data" above to wipe your local encrypted database prior to uninstalling the app bundle.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
