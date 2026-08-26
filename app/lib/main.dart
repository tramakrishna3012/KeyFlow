import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/services/cache_cleanup_service.dart';
import 'core/services/permission_helper.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/auth_service.dart';
import 'data/providers.dart';
import 'data/secure_auth_storage.dart';
import 'features/history/history_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize unified authentication service
  await AuthService.instance.initialize();

  // Clear FLAG_SECURE only if built with --dart-define=DEMO_MODE=true for demo recordings
  const isDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
  if (isDemoMode) {
    try {
      const MethodChannel('com.keyflow.app/security')
          .invokeMethod('setSecureFlag', {'enabled': false});
    } on Object catch (_) {}
  }

  // Load configuration from environment defines (--dart-define) with fallback
  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nmvwjdtsgzttfrepqprr.supabase.co',
  );
  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5tdndqZHRzZ3p0dGZyZXBxcHJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxOTg4MTAsImV4cCI6MjEwMDc3NDgxMH0.93-OsJYSdfB32_Q0uNE1BVY-rtTJnN_8A06Go_yHsIQ',
  );


  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        publishableKey: supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          localStorage: SecureAuthStorage(),
        ),
      );
    } on Object catch (e) {
      debugPrint('Supabase init skipped/error: $e');
    }
  }

  // Setup app lifecycle listener to purge temp cache on exit
  AppLifecycleListener(
    onDetach: () {
      const CacheCleanupService().clearTempAndCache();
    },
  );

  runApp(const ProviderScope(child: KeyFlowApp()));
}

class KeyFlowApp extends ConsumerStatefulWidget {
  const KeyFlowApp({super.key});

  @override
  ConsumerState<KeyFlowApp> createState() => _KeyFlowAppState();
}

class _KeyFlowAppState extends ConsumerState<KeyFlowApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(captureServiceProvider).initialize();
      } on Exception catch (e) {
        debugPrint('CaptureService init error: $e');
      }

      final statuses = await requestStartupPermissions();
      if (mounted) {
        handlePermissionDegradation(context, statuses);
      }
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'KeyFlow',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    routerConfig: appRouter,
  );
}

class MainHomeScreen extends ConsumerStatefulWidget {
  const MainHomeScreen({super.key});

  @override
  ConsumerState<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends ConsumerState<MainHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(captureServiceProvider).startCapture();
    });
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(historyEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KeyFlow Snippet History'),
        backgroundColor: AppColors.scaffoldBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(historyEntriesProvider),
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Clear All History'),
                  content: const Text(
                    'Are you sure you want to clear all local and cloud history entries?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              );
              if (confirm ?? false) {
                await ref.read(historyNotifierProvider.notifier).clearAll();
              }
            },
          ),
        ],
      ),
      body: historyAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.keyboard,
                    size: 64,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No captured snippets yet.',
                    style: TextStyle(fontSize: 18, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => ref
                        .read(captureServiceProvider)
                        .openAccessibilitySettings(),
                    icon: const Icon(Icons.settings_accessibility),
                    label: const Text('Enable Accessibility Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                color: AppColors.cardSurface,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: AppColors.cardBorder,
                    width: 0.8,
                  ),
                ),
                child: ListTile(
                  title: Text(
                    entry.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${entry.sourceApp} • ${_formatTimestamp(entry.capturedAt)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      size: 20,
                      color: AppColors.destructive,
                    ),
                    onPressed: () => ref
                        .read(historyNotifierProvider.notifier)
                        .deleteEntry(entry.id),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error loading history: $err',
              style: const TextStyle(color: AppColors.destructive),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
}
