import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers.dart';
import '../capture/capture_service.dart';
import 'onboarding_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  final List<String> _exclusions = [
    '1password.exe',
    'bitwarden.exe',
    'keepass.exe',
    'com.agilebits.onepassword',
    'com.bitwarden.Mobile',
    'bank',
  ];

  final TextEditingController _customExclusionController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _customExclusionController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    ref.read(onboardingControllerProvider.notifier).setStep(index);
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _finishOnboarding() async {
    final repo = ref.read(historyRepositoryProvider);

    // Save TRD S-3 default exclusions to database
    for (final app in _exclusions) {
      await repo.addExclusion(app);
    }

    // Mark onboarding completed in settings
    await ref.read(onboardingControllerProvider.notifier).completeOnboarding();

    // Now start the native capture engine
    final captureService = CaptureService(repo);
    await captureService.initialize();

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = ref.watch(onboardingControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Progress Bar
            LinearProgressIndicator(
              value: (currentStep + 1) / 5.0,
              backgroundColor: AppColors.cardSurface,
              color: AppColors.primary,
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildScreen1(),
                  _buildScreen2(),
                  _buildScreen3(),
                  _buildScreen4(),
                  _buildScreen5(),
                ],
              ),
            ),
            // Bottom Controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (currentStep > 0)
                    OutlinedButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  if (currentStep < 4)
                    ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Continue'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _finishOnboarding,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Activate KeyFlow & Finish'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Screen 1: What KeyFlow Does
  Widget _buildScreen1() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.keyboard_alt_outlined, size: 56, color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            'What KeyFlow Does',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'KeyFlow saves text you type on this device so you can search and reuse it later. It also offers autocorrect, translation, and emoji suggestions.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  // Screen 2: What KeyFlow Does NOT Do
  Widget _buildScreen2() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.security, size: 56, color: AppColors.secondary),
          const SizedBox(height: 20),
          Text(
            'What KeyFlow Does NOT Do',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          _buildFactPoint('No Password Capture', 'KeyFlow does NOT capture text from fields identified as secure or password fields by the operating system.'),
          const SizedBox(height: 12),
          _buildFactPoint('No Cloud Sync', 'KeyFlow stores text locally on this device, encrypted with AES-256. It does NOT sync data to any cloud server by default.'),
          const SizedBox(height: 12),
          _buildFactPoint('No Third-Party Sharing', 'KeyFlow does NOT share captured text with third parties.'),
        ],
      ),
    );
  }

  Widget _buildFactPoint(String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: AppColors.secondary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  // Screen 3: Permission Request
  Widget _buildScreen3() {
    String platformPermissionNote = 'Accessibility / Input Monitoring permission';
    if (defaultTargetPlatform == TargetPlatform.windows) {
      platformPermissionNote = 'Windows Low-level Keyboard Hook & System Tray Integration';
    } else if (defaultTargetPlatform == TargetPlatform.macOS) {
      platformPermissionNote = 'macOS Accessibility Permission (System Settings → Privacy & Security → Accessibility)';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      platformPermissionNote = 'Android KeyFlow Accessibility Service (Settings → Accessibility)';
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      platformPermissionNote = 'iOS Custom Keyboard Extension (Settings → General → Keyboard)';
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.admin_panel_settings_outlined, size: 56, color: AppColors.accentOrange),
          const SizedBox(height: 20),
          Text(
            'System Permission Request',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            'To observe text input across your applications, KeyFlow requires $platformPermissionNote.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Row(
              children: [
                Icon(Icons.visibility_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'KeyFlow runs transparently with an always-visible status indicator whenever capture is active.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Screen 4: Exclusion List Setup
  Widget _buildScreen4() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            'Exclusion List Setup',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Text typed in excluded applications is discarded immediately and never captured. KeyFlow pre-populates default password managers and banking identifiers:',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          // Exclusion Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _exclusions.map((app) {
              return Chip(
                label: Text(app, style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() {
                    _exclusions.remove(app);
                  });
                },
                backgroundColor: AppColors.cardSurface,
                side: const BorderSide(color: AppColors.cardBorder),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Custom Add Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _customExclusionController,
                  decoration: const InputDecoration(
                    hintText: 'Add executable or app bundle ID (e.g. keepass.exe)',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed: () {
                  final text = _customExclusionController.text.trim();
                  if (text.isNotEmpty && !_exclusions.contains(text)) {
                    setState(() {
                      _exclusions.add(text);
                      _customExclusionController.clear();
                    });
                  }
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Screen 5: Confirmation & Activation
  Widget _buildScreen5() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.secondary),
          const SizedBox(height: 20),
          Text(
            'KeyFlow is Ready to Activate',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          const Text(
            'KeyFlow stores text you type on this device, encrypted with AES-256, for 30 days by default.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          // Status Indicator Preview Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Status Indicator Preview: ⚡ KeyFlow - Active',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
