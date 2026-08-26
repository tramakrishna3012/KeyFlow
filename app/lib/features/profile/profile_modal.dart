import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/supabase_auth_notifier.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';
import '../../data/models/user_model.dart';
import '../../data/providers.dart';
import '../auth/auth_modal.dart';

/// Profile Modal (#profileModal)
/// Displays user profile header with gallery avatar picker, inline editable name & email,
/// 2FA configuration, Encrypted Cloud Sync toggle, Active Sessions manager with per-session
/// and bulk revoke actions, and account actions (Sign Out, Switch Account, Delete Account).
class ProfileModal extends ConsumerStatefulWidget {
  const ProfileModal({super.key});

  /// Helper to display ProfileModal responsively
  static Future<void> show(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    if (isDesktop) {
      return showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.scaffoldBackground,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.cardBorder),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 760),
            child: const ProfileModal(),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.scaffoldBackground,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: const FractionallySizedBox(
            heightFactor: 0.92,
            child: ProfileModal(),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends ConsumerState<ProfileModal> {
  // Inline editing controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;

  bool _isEditingName = false;
  bool _isEditingEmail = false;
  bool _isLoadingSessions = true;
  List<UserSession> _sessions = [];

  // Preset avatar identifiers for gallery picker (no camera required)
  final List<String> _avatarPresets = [
    'avatar_1',
    'avatar_2',
    'avatar_3',
    'avatar_4',
    'avatar_5',
    'avatar_6',
  ];

  final List<Color> _avatarColors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accentOrange,
    AppColors.accentPink,
    const Color(0xFF6C5CE7),
    const Color(0xFF00CEC9),
  ];

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _loadSessions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    final authService = ref.read(authServiceProvider);
    final sessions = await authService.fetchActiveSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoadingSessions = false;
      });
    }
  }

  void _showAvatarGalleryPicker(UserModel? user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text(
          'Choose Avatar',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select from gallery avatars (no camera permission needed):',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(_avatarPresets.length, (index) {
                final color = _avatarColors[index % _avatarColors.length];
                final isSelected = user?.avatarUrl == _avatarPresets[index];

                return InkWell(
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ref
                        .read(authServiceProvider)
                        .updateProfile(avatarUrl: _avatarPresets[index]);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(Icons.person_rounded, color: color, size: 24),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfigureTwoFactorDialog(UserModel? user) {
    final isEnabled = user?.mfaEnabled ?? false;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: Text(
          isEnabled
              ? 'Manage Two-Factor Authentication'
              : 'Enable Two-Factor Authentication',
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEnabled
                  ? 'Two-Factor Authentication (2FA) is currently protecting your account. You can disable or re-generate recovery codes.'
                  : 'Add an extra layer of security to your KeyFlow account using an authenticator app (Google Authenticator, Authy).',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(authServiceProvider)
                  .updateProfile(mfaEnabled: !isEnabled);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEnabled
                          ? '2FA disabled.'
                          : '2FA configured and enabled!',
                    ),
                    backgroundColor: isEnabled
                        ? AppColors.destructive
                        : AppColors.secondary,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isEnabled
                  ? AppColors.destructive
                  : AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(isEnabled ? 'Disable 2FA' : 'Enable 2FA'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.destructive),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.destructive,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Delete Account',
              style: TextStyle(fontSize: 16, color: AppColors.destructive),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This action is irreversible. All your local typing logs, synced cloud records, and encryption keys will be permanently destroyed.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Enter your password to confirm:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Current Password',
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.inputBorder),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text;
              if (password.isNotEmpty) {
                Navigator.of(ctx).pop(); // Close dialog
                Navigator.of(context).pop(); // Close profile modal
                await ref
                    .read(authServiceProvider)
                    .deleteAccount(password: password);
                AppAuthNotifier.debugAuthenticatedOverride = null;
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.destructive,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
  }

  void _showSignOutAllOtherSessionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text(
          'Sign out of other devices?',
          style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
        ),
        content: const Text(
          'This will terminate all active sessions on other laptops, phones, and workstations. You will remain signed in on this device.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(authServiceProvider).revokeAllOtherSessions();
              setState(() {
                _sessions = _sessions.where((s) => s.isCurrent).toList();
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All other sessions revoked.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Revoke Other Sessions'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final authService = ref.watch(authServiceProvider);

    final name = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : (user?.email.split('@')[0] ?? 'Offline User');
    final email = user?.email ?? 'Operating in Local-Only Mode';
    final role = user?.role == 'admin' ? 'Administrator' : 'Verified Member';
    final is2FaEnabled = user?.mfaEnabled ?? false;
    final isCloudSyncEnabled = user?.cloudSyncEnabled ?? true;

    return Material(
      color: AppColors.scaffoldBackground,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          // Drag handle for mobile / header
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.cardBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'User Profile & Security',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Main Scrollable Content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              children: [
                // 1. Profile Header Card
                KeyFlowCard(
                  child: Column(
                    children: [
                      // Avatar & Edit Picker
                      Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AppColors.primary.withValues(
                                  alpha: 0.2,
                                ),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'K',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () => _showAvatarGalleryPicker(user),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.scaffoldBackground,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.edit,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Inline Editable Name
                                if (_isEditingName)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _nameController,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 4,
                                                ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check,
                                          size: 18,
                                          color: AppColors.secondary,
                                        ),
                                        onPressed: () async {
                                          setState(
                                            () => _isEditingName = false,
                                          );
                                          await authService.updateProfile(
                                            fullName: _nameController.text
                                                .trim(),
                                          );
                                        },
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => setState(
                                          () => _isEditingName = true,
                                        ),
                                        child: const Icon(
                                          Icons.edit_outlined,
                                          size: 14,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 2),
                                // Inline Editable Email
                                if (_isEditingEmail)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _emailController,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 4,
                                                ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.check,
                                          size: 16,
                                          color: AppColors.secondary,
                                        ),
                                        onPressed: () async {
                                          setState(
                                            () => _isEditingEmail = false,
                                          );
                                          await authService.updateProfile(
                                            email: _emailController.text.trim(),
                                          );
                                        },
                                      ),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          email,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textMuted,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      InkWell(
                                        onTap: () => setState(
                                          () => _isEditingEmail = true,
                                        ),
                                        child: const Icon(
                                          Icons.edit_outlined,
                                          size: 12,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
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
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.cardBorder.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Re-verification required if email address is updated.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 2. Security & Key Backup Section
                _buildSectionHeader('SECURITY & CLOUD SYNC'),
                const SizedBox(height: 8),
                KeyFlowCard(
                  child: Column(
                    children: [
                      // 2FA row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  (is2FaEnabled
                                          ? AppColors.secondary
                                          : AppColors.textMuted)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.security_rounded,
                              size: 18,
                              color: is2FaEnabled
                                  ? AppColors.secondary
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Two-Factor Authentication (2FA)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  is2FaEnabled
                                      ? 'Active and protecting your workstation'
                                      : 'Not configured',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () =>
                                _showConfigureTwoFactorDialog(user),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.cardBorder,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              is2FaEnabled ? 'Manage' : 'Configure',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(color: AppColors.cardBorder, height: 1),
                      const SizedBox(height: 12),

                      // Encrypted Cloud Sync Toggle
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  (isCloudSyncEnabled
                                          ? AppColors.primary
                                          : AppColors.textMuted)
                                      .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.cloud_sync_rounded,
                              size: 18,
                              color: isCloudSyncEnabled
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Encrypted Cloud Sync',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Sync typing history encrypted at rest via AES-256-GCM',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: isCloudSyncEnabled,
                            onChanged: (val) async {
                              await authService.updateProfile(
                                cloudSyncEnabled: val,
                              );
                            },
                            activeThumbColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 3. Active Sessions Manager
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('ACTIVE SESSIONS'),
                    if (_sessions.where((s) => !s.isCurrent).isNotEmpty)
                      InkWell(
                        onTap: _showSignOutAllOtherSessionsDialog,
                        child: const Text(
                          'Sign out all others',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.destructive,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                KeyFlowCard(
                  child: _isLoadingSessions
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        )
                      : Column(
                          children: _sessions
                              .map(
                                (sess) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        sess.osInfo.toLowerCase().contains(
                                                  'android',
                                                ) ||
                                                sess.osInfo
                                                    .toLowerCase()
                                                    .contains('mobile')
                                            ? Icons.smartphone_rounded
                                            : Icons.laptop_chromebook_rounded,
                                        color: sess.isCurrent
                                            ? AppColors.secondary
                                            : AppColors.textMuted,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    sess.deviceName,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (sess.isCurrent) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.secondary
                                                          .withValues(
                                                            alpha: 0.15,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: const Text(
                                                      'This device',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color:
                                                            AppColors.secondary,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            Text(
                                              '${sess.osInfo} • ${sess.lastActive}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!sess.isCurrent)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.remove_circle_outline,
                                            size: 18,
                                            color: AppColors.destructive,
                                          ),
                                          tooltip: 'Revoke session',
                                          onPressed: () async {
                                            await authService.revokeSession(
                                              sess.id,
                                            );
                                            setState(() {
                                              _sessions.removeWhere(
                                                (s) => s.id == sess.id,
                                              );
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),

                const SizedBox(height: 18),

                // 4. Account Actions
                _buildSectionHeader('ACCOUNT ACTIONS'),
                const SizedBox(height: 8),
                KeyFlowCard(
                  child: Column(
                    children: [
                      // Switch Account
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.switch_account_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'Switch Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          AuthModal.show(context);
                        },
                      ),
                      const Divider(color: AppColors.cardBorder, height: 1),

                      // Sign Out
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.textPrimary,
                        ),
                        title: const Text(
                          'Sign Out',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                        onTap: () async {
                          AppAuthNotifier.setAuthenticatedOverride(null);
                          await authService.logout();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            context.go('/login');
                          }
                        },

                      ),
                      const Divider(color: AppColors.cardBorder, height: 1),

                      // Delete Account
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.delete_forever_outlined,
                          color: AppColors.destructive,
                        ),
                        title: const Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.destructive,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: AppColors.destructive,
                          size: 20,
                        ),
                        onTap: _showDeleteAccountDialog,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
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
}
