import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/providers.dart';
import 'features/history/history_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Supabase.initialize(
      url: 'https://nmvwjdtsgzttfrepqprr.supabase.co',
      publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5tdndqZHRzZ3p0dGZyZXBxcHJyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg3NTUyMDAsImV4cCI6MjA1NDMzMTIwMH0.sampleKey',
    );
  } on Exception catch (e) {
    debugPrint('Supabase init skipped/error: $e');
  }

  runApp(const ProviderScope(child: KeyFlowApp()));
}

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
        backgroundColor: const Color(0xFF1E1B2E),
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
                  content: const Text('Are you sure you want to clear all local and cloud history entries?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Clear All')),
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
                  const Icon(Icons.keyboard, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No captured snippets yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(captureServiceProvider).openAccessibilitySettings(),
                    icon: const Icon(Icons.settings_accessibility),
                    label: const Text('Enable Accessibility Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C4DFF),
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
                color: const Color(0xFF1E1B2E),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(
                    entry.text,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${entry.sourceApp} • ${_formatTimestamp(entry.capturedAt)}',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.redAccent),
                    onPressed: () => ref.read(historyNotifierProvider.notifier).deleteEntry(entry.id),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error loading history: $err',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}/${dt.year}';
}
