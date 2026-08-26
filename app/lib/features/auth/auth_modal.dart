import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/router/supabase_auth_notifier.dart';
import '../../core/theme/app_colors.dart';
import '../../data/providers.dart';

/// Tabbed Authentication Modal (#authModal)
/// Supports Sign In and Create Account with inline validation,
/// real-time password strength meter, SSO buttons, biometric quick access,
/// and dismissible error banner.
class AuthModal extends ConsumerStatefulWidget {
  const AuthModal({super.key, this.initialIsSignUp = false});

  final bool initialIsSignUp;

  /// Helper to display the AuthModal responsively
  static Future<bool?> show(
    BuildContext context, {
    bool initialIsSignUp = false,
  }) {
    final isDesktop = MediaQuery.of(context).size.width > 600;
    if (isDesktop) {
      return showDialog<bool>(
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
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
            child: AuthModal(initialIsSignUp: initialIsSignUp),
          ),
        ),
      );
    } else {
      return showModalBottomSheet<bool>(
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
          child: FractionallySizedBox(
            heightFactor: 0.92,
            child: AuthModal(initialIsSignUp: initialIsSignUp),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends ConsumerState<AuthModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign In Controllers
  final _signInFormKey = GlobalKey<FormState>();
  final _signInEmailController = TextEditingController();
  final _signInPasswordController = TextEditingController();
  bool _signInObscurePassword = true;

  // Create Account Controllers
  final _signUpFormKey = GlobalKey<FormState>();
  final _signUpNameController = TextEditingController();
  final _signUpEmailController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  final _signUpConfirmPasswordController = TextEditingController();
  bool _signUpObscurePassword = true;
  bool _signUpObscureConfirm = true;
  bool _enableBiometrics = false;
  bool _agreeToTerms = true;

  // Common State
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialIsSignUp ? 1 : 0,
    );
    _tabController.addListener(() {
      if (mounted) setState(() => _errorMessage = null);
    });
    _signUpPasswordController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _signInEmailController.dispose();
    _signInPasswordController.dispose();
    _signUpNameController.dispose();
    _signUpEmailController.dispose();
    _signUpPasswordController.dispose();
    _signUpConfirmPasswordController.dispose();
    super.dispose();
  }

  // Password strength calculation: 0 = none, 1 = weak, 2 = fair, 3 = strong
  int _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0;
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp('[A-Z]').hasMatch(password) &&
        RegExp('[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp('[0-9]').hasMatch(password) ||
        RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) {
      score++;
    }
    return score;
  }

  Color _getPasswordStrengthColor(int strength) {
    switch (strength) {
      case 1:
        return AppColors.destructive;
      case 2:
        return AppColors.accentOrange;
      case 3:
        return AppColors.secondary;
      default:
        return AppColors.cardBorder;
    }
  }

  String _getPasswordStrengthLabel(int strength) {
    switch (strength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Moderate';
      case 3:
        return 'Strong';
      default:
        return 'Enter password';
    }
  }

  Future<void> _handleSignIn() async {
    if (!_signInFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final email = _signInEmailController.text.trim();
    final password = _signInPasswordController.text;

    try {
      final res = await authService.login(email: email, password: password);
      if (!mounted) return;

      if (res.success) {
        AppAuthNotifier.debugAuthenticatedOverride = true;
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = res.errorMessage ?? 'Invalid email or password.';
        });
      }
    } on Exception {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      setState(() {
        _errorMessage = 'Please accept the Terms of Service & Privacy Policy.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = ref.read(authServiceProvider);
    final fullName = _signUpNameController.text.trim();
    final email = _signUpEmailController.text.trim();
    final password = _signUpPasswordController.text;

    try {
      final res = await authService.register(
        email: email,
        password: password,
        fullName: fullName.isEmpty ? email.split('@')[0] : fullName,
      );
      if (!mounted) return;

      if (res.success) {
        if (_enableBiometrics) {
          await authService.updateProfile(biometricsEnabled: true);
        }
        if (!mounted) return;
        AppAuthNotifier.debugAuthenticatedOverride = true;
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _errorMessage = res.errorMessage ?? 'Registration failed.';
        });
      }
    } on Exception {
      setState(() {
        _errorMessage = 'Connection error. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBiometricSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    // Simulate biometric authentication verification
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    final user = ref.read(currentUserProvider);
    if (user != null || AppAuthNotifier.debugAuthenticatedOverride == true) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _errorMessage =
            'No biometric credentials enrolled. Please sign in with password.';
        _isLoading = false;
      });
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(
      text: _signInEmailController.text,
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.scaffoldBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(fontSize: 18, color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your account email to receive a password reset link:',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'name@example.com',
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
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                await ref.read(authServiceProvider).requestPasswordReset(email);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Password reset instructions sent to $email',
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Material(
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

        // Header with Title & Close button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'KeyFlow Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Secure access & encrypted cloud sync',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
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

        const SizedBox(height: 16),

        // Tab Bar Switcher
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: const [
                Tab(text: 'Sign In'),
                Tab(text: 'Create Account'),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Dismissible Error Banner
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.destructive.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.destructive.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 18,
                    color: AppColors.destructive,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.destructive,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _errorMessage = null),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.destructive,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Tab Content Area
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildSignInTab(), _buildCreateAccountTab()],
          ),
        ),
      ],
    ),
  );

  // 1. SIGN IN TAB
  Widget _buildSignInTab() => Form(
    key: _signInFormKey,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      children: [
        // Email Field
        const Text(
          'Email Address',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _signInEmailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: _inputDecoration(
            hint: 'name@example.com',
            prefixIcon: Icons.email_outlined,
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter your email';
            }
            if (!RegExp(
              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
            ).hasMatch(val.trim())) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),

        const SizedBox(height: 14),

        // Password Field
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Password',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            InkWell(
              onTap: _showForgotPasswordDialog,
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _signInPasswordController,
          obscureText: _signInObscurePassword,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          decoration: _inputDecoration(
            hint: '••••••••',
            prefixIcon: Icons.lock_outline,
            suffixIcon: IconButton(
              icon: Icon(
                _signInObscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
                size: 18,
              ),
              onPressed: () => setState(
                () => _signInObscurePassword = !_signInObscurePassword,
              ),
            ),
          ),
          validator: (val) => (val == null || val.isEmpty)
              ? 'Please enter your password'
              : null,
        ),

        const SizedBox(height: 20),

        // Primary CTA + Biometric Quick-Access
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.fingerprint,
                  color: AppColors.primaryLight,
                  size: 24,
                ),
                tooltip: 'Quick Biometric Sign In',
                onPressed: _isLoading ? null : _handleBiometricSignIn,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // SSO Divider
        _buildDivider('OR CONTINUE WITH'),

        const SizedBox(height: 16),

        // SSO Buttons
        _buildSsoButtons(),
      ],
    ),
  );

  // 2. CREATE ACCOUNT TAB
  Widget _buildCreateAccountTab() {
    final strength = _calculatePasswordStrength(_signUpPasswordController.text);
    final strengthColor = _getPasswordStrengthColor(strength);
    final strengthLabel = _getPasswordStrengthLabel(strength);

    return Form(
      key: _signUpFormKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Full Name
          const Text(
            'Full Name',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _signUpNameController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Alex Morgan',
              prefixIcon: Icons.person_outline,
            ),
            validator: (val) => (val == null || val.trim().isEmpty)
                ? 'Please enter your name'
                : null,
          ),

          const SizedBox(height: 12),

          // Email
          const Text(
            'Email Address',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _signUpEmailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'name@example.com',
              prefixIcon: Icons.email_outlined,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(val.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Password
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _signUpPasswordController,
            obscureText: _signUpObscurePassword,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'At least 8 characters',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _signUpObscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                onPressed: () => setState(
                  () => _signUpObscurePassword = !_signUpObscurePassword,
                ),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please enter a password';
              }
              if (val.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),

          // Dynamic Password Strength Meter
          if (_signUpPasswordController.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: strength / 3.0,
                      backgroundColor: AppColors.cardBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  strengthLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: strengthColor,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),

          // Confirm Password
          const Text(
            'Confirm Password',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _signUpConfirmPasswordController,
            obscureText: _signUpObscureConfirm,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: _inputDecoration(
              hint: 'Re-enter your password',
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _signUpObscureConfirm
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.textMuted,
                  size: 18,
                ),
                onPressed: () => setState(
                  () => _signUpObscureConfirm = !_signUpObscureConfirm,
                ),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) {
                return 'Please confirm your password';
              }
              if (val != _signUpPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),

          const SizedBox(height: 12),

          // Biometrics Checkbox
          CheckboxListTile(
            value: _enableBiometrics,
            onChanged: (val) =>
                setState(() => _enableBiometrics = val ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            title: const Text(
              'Enable Face ID / Touch ID quick login',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),

          // Terms Checkbox
          CheckboxListTile(
            value: _agreeToTerms,
            onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            title: const Text(
              'I agree to the Terms of Service and Privacy Policy',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),

          const SizedBox(height: 12),

          // Create Account CTA
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSignUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 20),

          // SSO Divider
          _buildDivider('OR SIGN UP WITH'),

          const SizedBox(height: 16),

          // SSO Buttons
          _buildSsoButtons(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDivider(String text) => Row(
    children: [
      const Expanded(child: Divider(color: AppColors.cardBorder)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
            letterSpacing: 1.1,
          ),
        ),
      ),
      const Expanded(child: Divider(color: AppColors.cardBorder)),
    ],
  );

  Widget _buildSsoButtons() => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Google SSO authentication initiated...'),
              ),
            );
          },
          icon: const Icon(
            Icons.g_mobiledata_rounded,
            color: Colors.redAccent,
            size: 24,
          ),
          label: const Text(
            'Google',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.cardBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: AppColors.cardSurface,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('GitHub SSO authentication initiated...'),
              ),
            );
          },
          icon: const Icon(
            Icons.code_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
          label: const Text(
            'GitHub',
            style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.cardBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            backgroundColor: AppColors.cardSurface,
          ),
        ),
      ),
    ],
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 13),
    filled: true,
    fillColor: AppColors.inputBackground,
    prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 18),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.destructive),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.destructive, width: 1.5),
    ),
  );
}
