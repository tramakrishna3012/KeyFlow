import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../data/auth_service.dart';

/// Screen displayed during web-to-mobile pairing handshake (`keyflow://pair?token=...`).
class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key, required this.token});

  final String token;

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _executePairing());
  }

  Future<void> _executePairing() async {
    if (widget.token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid pairing link: missing token.';
      });
      return;
    }

    try {
      final response = await AuthService.instance.verifyAndPair(
        pairingToken: widget.token,
      );

      if (!mounted) return;

      if (response.success) {
        setState(() => _isLoading = false);
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (mounted) {
          context.go('/home');
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              response.errorMessage ??
              'Pairing verification failed or token expired.';
        });
      }
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Connection error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.scaffoldBackground,
    body: Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.phonelink_lock_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'KeyFlow Device Pairing',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isLoading
                  ? 'Verifying cryptographic pairing token...'
                  : (_errorMessage != null
                      ? 'Pairing could not be completed'
                      : 'Authenticated! Loading your workspace...'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _errorMessage != null
                    ? AppColors.destructive
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const CircularProgressIndicator(color: AppColors.primary)
            else if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.destructive,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ] else
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.green,
                size: 40,
              ),
          ],
        ),
      ),
    ),
  );
}
