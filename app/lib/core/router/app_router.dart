import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_screen.dart';
import '../../features/emoji/emoji_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/translate/translate_screen.dart';
import '../theme/app_colors.dart';
import 'supabase_auth_notifier.dart';

final SupabaseAuthNotifier _authNotifier = SupabaseAuthNotifier();

/// Top-level GoRouter configuration with Auth routing and 5-tab shell route.
///
/// Tabs: Home, History, Translate, Emoji, Settings
/// Uses [StatefulShellRoute.indexedStack] for tab persistence.
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  refreshListenable: _authNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    final isLoggingIn = state.matchedLocation == '/login';
    final isAuthenticated = _authNotifier.isAuthenticated;

    // Unauthenticated users attempting to access protected routes -> redirect to /login
    if (!isAuthenticated && !isLoggingIn) {
      return '/login';
    }

    // Authenticated users hitting /login -> bypass directly to /home
    if (isAuthenticated && isLoggingIn) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const AuthScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          _ScaffoldWithNavBar(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/translate',
              builder: (context, state) => const TranslateScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/emoji',
              builder: (context, state) => const EmojiScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Shell scaffold that wraps all tabs with a persistent bottom nav bar.
class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 0.8),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.translate_rounded),
            activeIcon: Icon(Icons.translate_rounded),
            label: 'Translate',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_emotions_rounded),
            activeIcon: Icon(Icons.emoji_emotions_rounded),
            label: 'Emoji',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    ),
  );
}
