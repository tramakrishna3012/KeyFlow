import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(
    const ProviderScope(
      child: KeyFlowApp(),
    ),
  );
}

/// Root widget for the KeyFlow application.
///
/// Wraps [MaterialApp.router] with the Figma-extracted dark theme
/// and GoRouter navigation.
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
