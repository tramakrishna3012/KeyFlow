import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/router/supabase_auth_notifier.dart';
import '../../core/services/auto_update_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';
import '../../data/providers.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _addExclusionController = TextEditingController();

  @override
  void dispose() {
    _addExclusionController.dispose();
    super.dispose();
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

            // 0. USER ACCOUNT & SYNC SECTION
            _buildSectionHeader('ACCOUNT & CLOUD SYNC'),
            const SizedBox(height: 8),
            _buildAccountCard(),

            const SizedBox(height: 24),

            // 1. EXCLUSION LIST SECTION
            _buildSectionHeader('EXCLUSION LIST'),
            const SizedBox(height: 8),
            _buildExclusionCard(exclusionAsync),

            const SizedBox(height: 24),

            // 2. RETENTION POLICY SECTION
            _buildSectionHeader('DATA RETENTION'),
            const SizedBox(height: 8),
            _buildRetentionCard(retentionAsync),

            const SizedBox(height: 24),

            // 3. AUTOCORRECT & TYPING SECTION
            _buildSectionHeader('AUTOCORRECT & TYPING'),
            const SizedBox(height: 8),
            _buildAutocorrectCard(autocorrectAsync),

            const SizedBox(height: 24),

            // 4. TRANSLATION SECTION
            _buildSectionHeader('TRANSLATION'),
            const SizedBox(height: 8),
            _buildTranslationCard(targetLangAsync),

            const SizedBox(height: 24),

            // 5. DATA MANAGEMENT SECTION
            _buildSectionHeader('DATA MANAGEMENT'),
            const SizedBox(height: 8),
            _buildDataManagementCard(),

            const SizedBox(height: 24),

            // 6. ABOUT & UNINSTALL SECTION
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
    final authService = ref.watch(authServiceProvider);

    final name = user?.fullName ?? user?.email.split('@')[0] ?? 'Offline User';
    final email = user?.email ?? 'Operating in Local-Only Mode';
    final role = user?.role == 'admin' ? 'Administrator' : 'Verified Member';

    return KeyFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'K',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                AppAuthNotifier.debugAuthenticatedOverride = null;
                await authService.logout();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('You have been signed out.')),
                  );
                }
              },
              icon: const Icon(Icons.logout, size: 16),
              label: const Text('Sign Out of KeyFlow Workstation'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side: BorderSide(
                  color: AppColors.destructive.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
        const SizedBox(height: 6),
        const Text(
          'Text typed in excluded applications is discarded immediately.',
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        exclusionAsync.when(
          data: (exclusions) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...exclusions.map(
                (app) => Chip(
                  label: Text(app, style: const TextStyle(fontSize: 12)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    ref.read(settingsControllerProvider).removeExclusion(app);
                  },
                  backgroundColor: AppColors.cardSurface,
                  side: const BorderSide(color: AppColors.cardBorder),
                ),
              ),
              ActionChip(
                avatar: const Icon(
                  Icons.add,
                  size: 16,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Add App',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
                onPressed: _showAddExclusionDialog,
                backgroundColor: AppColors.primaryGhost,
                side: BorderSide.none,
              ),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (err, stack) => Text(
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

  void _showAddExclusionDialog() {
    _addExclusionController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add App Exclusion'),
        content: TextField(
          controller: _addExclusionController,
          decoration: const InputDecoration(
            hintText: 'e.g. 1password.exe or com.apple.Safari',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = _addExclusionController.text.trim();
              if (text.isNotEmpty) {
                ref.read(settingsControllerProvider).addExclusion(text);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

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
            dropdownColor: AppColors.scaffoldBackground,
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
            dropdownColor: AppColors.scaffoldBackground,
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
