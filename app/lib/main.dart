import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/services/permission_helper.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase — replace placeholders with your project credentials.
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    publishableKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  // Request camera, storage, and notification permissions on mobile.
  await requestStartupPermissions();

  runApp(
    const ProviderScope(
      child: KeyFlowApp(),
    ),
  );
}

/// Root widget for the KeyFlow application.
///
/// Wraps [MaterialApp.router] with the Figma-extracted dark theme
/// and GoRouter navigation. Authentication is handled by the GoRouter
/// `redirect` callback and [SupabaseAuthNotifier] — see `app_router.dart`.
class KeyFlowApp extends StatelessWidget {
  const KeyFlowApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'KeyFlow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: appRouter,
      );
}

