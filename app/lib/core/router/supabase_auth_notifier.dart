import 'package:flutter/foundation.dart';
import '../../data/auth_service.dart';

/// A [ChangeNotifier] that listens to unified authentication state changes.
///
/// Pass an instance of this to [GoRouter.refreshListenable] so the
/// router re-evaluates its `redirect` callback whenever the user
/// signs in, signs out, or switches offline.
class AppAuthNotifier extends ChangeNotifier {
  AppAuthNotifier({AuthService? authService})
    : _authService = authService ?? AuthService.instance {
    _globalInstance = this;
    _authService?.addListener(_onAuthChanged);
  }

  static AppAuthNotifier? _globalInstance;
  final AuthService? _authService;
  static bool? debugAuthenticatedOverride;

  static void setAuthenticatedOverride(bool? val) {
    debugAuthenticatedOverride = val;
    _globalInstance?.notifyListeners();
  }

  void _onAuthChanged() {
    notifyListeners();
  }

  /// Whether the user currently has an active session or offline access.
  bool get isAuthenticated {
    if (debugAuthenticatedOverride != null) {
      return debugAuthenticatedOverride!;
    }
    if (_authService != null) {
      return _authService.isAuthenticated;
    }
    return false;
  }

  @override
  void dispose() {
    _authService?.removeListener(_onAuthChanged);
    super.dispose();
  }
}

/// Backwards compatibility alias for existing router imports
typedef SupabaseAuthNotifier = AppAuthNotifier;
