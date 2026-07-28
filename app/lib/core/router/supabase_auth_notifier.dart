import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A [ChangeNotifier] that listens to Supabase auth state changes.
///
/// Pass an instance of this to [GoRouter.refreshListenable] so the
/// router re-evaluates its `redirect` callback whenever the user
/// signs in, signs out, or the session token refreshes.
class SupabaseAuthNotifier extends ChangeNotifier {
  SupabaseAuthNotifier() {
    _init();
  }

  StreamSubscription<AuthState>? _subscription;

  void _init() {
    try {
      _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (data) {
          notifyListeners();
        },
      );
    } catch (_) {
      // Supabase is not initialized (e.g. in unit/widget tests)
    }
  }

  /// Whether the user currently has an active Supabase session.
  bool get isAuthenticated {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      return session != null;
    } catch (_) {
      // If Supabase is not initialized (e.g. in tests), default to true
      return true;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
