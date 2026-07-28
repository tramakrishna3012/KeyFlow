import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/services/permission_helper.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase — connected to KeyFlow project (nmvwjdtsgzttfrepqprr).
  await Supabase.initialize(
    url: 'https://nmvwjdtsgzttfrepqprr.supabase.co',
    publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5tdndqZHRzZ3p0dGZyZXBxcHJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxOTg4MTAsImV4cCI6MjEwMDc3NDgxMH0.93-OsJYSdfB32_Q0uNE1BVY-rtTJnN_8A06Go_yHsIQ',
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

