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
    try {
      _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
        data,
      ) {
        notifyListeners();
      });
    } on Object catch (_) {
      // Safe fallback when Supabase is uninitialized (e.g. unit tests or offline mode)
      _subscription = null;
    }
  }

  StreamSubscription<AuthState>? _subscription;

  /// Whether the user currently has an active Supabase session.
  bool get isAuthenticated {
    try {
      return Supabase.instance.client.auth.currentSession != null;
    } on Object catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
