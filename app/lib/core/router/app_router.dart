import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../features/auth/auth_modal.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/emoji/emoji_screen.dart';
import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/profile/profile_modal.dart';
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

/// Shell scaffold that wraps all tabs with responsive navigation:
/// - Desktop / Tablet (> 600px): Uses [NavigationRail] on the left with desktop header & sidebar footer
/// - Mobile (<= 600px): Uses [BottomNavigationBar] inside [SafeArea]
class _ScaffoldWithNavBar extends StatelessWidget {
  const _ScaffoldWithNavBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final isWideScreen = constraints.maxWidth > 600;

      if (isWideScreen) {
        return Scaffold(
          body: Row(
            children: [
              SizedBox(
                width: 80,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // KeyFlow Brand Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.keyboard_command_key_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: NavigationRail(
                        selectedIndex: navigationShell.currentIndex,
                        onDestinationSelected: (index) => navigationShell.goBranch(
                          index,
                          initialLocation: index == navigationShell.currentIndex,
                        ),
                        labelType: NavigationRailLabelType.all,
                        destinations: const [
                          NavigationRailDestination(
                            icon: Icon(Icons.home_rounded),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: Text('Home'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.history_rounded),
                            selectedIcon: Icon(Icons.history_rounded),
                            label: Text('History'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.translate_rounded),
                            selectedIcon: Icon(Icons.translate_rounded),
                            label: Text('Translate'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.emoji_emotions_rounded),
                            selectedIcon: Icon(Icons.emoji_emotions_rounded),
                            label: Text('Emoji'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.settings_rounded),
                            selectedIcon: Icon(Icons.settings_rounded),
                            label: Text('Settings'),
                          ),
                        ],
                      ),
                    ),
                    // Desktop Sidebar Footer: Profile Trigger
                    const _DesktopSidebarFooter(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              const VerticalDivider(
                thickness: 1,
                width: 1,
                color: AppColors.cardBorder,
              ),
              Expanded(
                child: Column(
                  children: [
                    // Desktop Header Bar with Profile Dropdown
                    const _DesktopHeader(),
                    Expanded(child: navigationShell),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: SafeArea(
          child: Container(
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
              type: BottomNavigationBarType.fixed,
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
        ),
      );
    },
  );
}

/// Desktop Header with user avatar badge and dropdown menu
class _DesktopHeader extends ConsumerWidget {
  const _DesktopHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final name = user?.fullName.isNotEmpty == true
        ? user!.fullName
        : (user?.email.split('@')[0] ?? 'User');
    final initial = (name.isNotEmpty ? name[0] : 'K').toUpperCase();

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 0.8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Account Options',
            offset: const Offset(0, 44),
            color: AppColors.scaffoldBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            onSelected: (value) async {
              if (value == 'profile') {
                ProfileModal.show(context);
              } else if (value == 'switch') {
                AuthModal.show(context);
              } else if (value == 'logout') {
                AppAuthNotifier.debugAuthenticatedOverride = null;
                await ref.read(authServiceProvider).logout();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text('Profile ($name)', style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'switch',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 10),
                    Text('Switch Account', style: TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: AppColors.destructive),
                    SizedBox(width: 10),
                    Text('Sign Out', style: TextStyle(fontSize: 13, color: AppColors.destructive)),
                  ],
                ),
              ),
            ],
            child: Row(
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop Sidebar Footer tile opening ProfileModal
class _DesktopSidebarFooter extends ConsumerWidget {
  const _DesktopSidebarFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final initial = (user?.fullName.isNotEmpty == true
            ? user!.fullName[0]
            : (user?.email.isNotEmpty == true ? user!.email[0] : 'K'))
        .toUpperCase();

    return InkWell(
      onTap: () => ProfileModal.show(context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withValues(alpha: 0.2),
          child: Text(
            initial,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

