import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/history_entry.dart';
import '../../data/providers.dart';

class AppVisualMeta {
  const AppVisualMeta({
    required this.displayName,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });
  final String displayName;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
}

AppVisualMeta getAppVisualMeta(String rawPackageOrName) {
  final lower = rawPackageOrName.toLowerCase();
  if (lower.contains('whatsapp')) {
    return const AppVisualMeta(
      displayName: 'WhatsApp',
      icon: Icons.chat_bubble_rounded,
      iconColor: Colors.white,
      iconBg: Color(0xFF059669), // Emerald 600
    );
  } else if (lower.contains('chrome')) {
    return const AppVisualMeta(
      displayName: 'Chrome',
      icon: Icons.public_rounded,
      iconColor: Colors.white,
      iconBg: Color(0xFFD97706), // Amber 600
    );
  } else if (lower.contains('word') || lower.contains('doc')) {
    return const AppVisualMeta(
      displayName: 'Microsoft Word',
      icon: Icons.description_rounded,
      iconColor: Colors.white,
      iconBg: Color(0xFF2563EB), // Blue 600
    );
  } else if (lower.contains('gmail') ||
      lower.contains('mail') ||
      lower.contains('email')) {
    return const AppVisualMeta(
      displayName: 'Gmail',
      icon: Icons.mail_rounded,
      iconColor: Colors.white,
      iconBg: Color(0xFFDC2626), // Red 600
    );
  } else if (lower.contains('telegram')) {
    return const AppVisualMeta(
      displayName: 'Telegram',
      icon: Icons.send_rounded,
      iconColor: Colors.white,
      iconBg: Color(0xFF0284C7), // Sky 600
    );
  } else if (lower.contains('keyflow')) {
    return const AppVisualMeta(
      displayName: 'KeyFlow',
      icon: Icons.keyboard_rounded,
      iconColor: Colors.white,
      iconBg: Color(0xFF7C3AED), // Violet 600
    );
  } else if (lower.contains('note') ||
      lower.contains('notepad') ||
      lower.contains('memo')) {
    return const AppVisualMeta(
      displayName: 'Notes',
      icon: Icons.edit_note_rounded,
      iconColor: Colors.white,
      iconBg: Color(0xFF9333EA), // Purple 600
    );
  } else if (lower.contains('terminal') ||
      lower.contains('term') ||
      lower.contains('shell')) {
    return const AppVisualMeta(
      displayName: 'Terminal',
      icon: Icons.terminal_rounded,
      iconColor: Colors.white,
      iconBg: Color(0xFF0F172A), // Slate 900
    );
  } else if (lower.contains('code') ||
      lower.contains('studio') ||
      lower.contains('vscode')) {
    return const AppVisualMeta(
      displayName: 'VS Code',
      icon: Icons.code_rounded,
      iconColor: Colors.white,
      iconBg: Color(0xFF0284C7), // Sky 600
    );
  } else {
    var cleanName = rawPackageOrName;
    if (cleanName.contains('.')) {
      final parts = cleanName.split('.');
      cleanName = parts.last;
    }
    if (cleanName.isNotEmpty) {
      cleanName = cleanName[0].toUpperCase() + cleanName.substring(1);
    } else {
      cleanName = 'App';
    }

    return AppVisualMeta(
      displayName: cleanName,
      icon: Icons.apps_rounded,
      iconColor: Colors.white,
      iconBg: const Color(0xFF64748B), // Slate 500
    );
  }
}

/// State provider for the current search query string.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// State provider for the active tag/app filter.
final activeTagProvider = StateProvider<String>((ref) => 'All Apps');

/// Dynamic app filter chips derived from all captured entries in the repository
final availableAppChipsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final repository = ref.watch(historyRepositoryProvider);
  final entries = await repository.getAllEntries();
  final appNames = <String>{'All Apps'};
  for (final e in entries) {
    final meta = getAppVisualMeta(e.sourceApp);
    appNames.add(meta.displayName);
  }
  return appNames.toList();
});

/// Async provider yielding history entries based on search query and filter tag.
final historyEntriesProvider = FutureProvider.autoDispose<List<HistoryEntry>>((
  ref,
) async {
  final repository = ref.watch(historyRepositoryProvider);
  final query = ref.watch(searchQueryProvider);
  final tag = ref.watch(activeTagProvider);

  final entries = await repository.search(query);

  if (tag == 'All' || tag == 'All Apps') {
    return entries;
  }

  return entries.where((e) {
    final meta = getAppVisualMeta(e.sourceApp);
    final lowerTag = tag.toLowerCase();
    return meta.displayName.toLowerCase() == lowerTag ||
        e.sourceApp.toLowerCase().contains(lowerTag) ||
        (e.category != null && e.category!.toLowerCase().contains(lowerTag));
  }).toList();
});

/// Async provider yielding ALL raw history entries for dashboard analytics.
final allHistoryEntriesProvider =
    FutureProvider.autoDispose<List<HistoryEntry>>((ref) async {
      final repository = ref.watch(historyRepositoryProvider);
      return repository.getAllEntries();
    });

/// Controller to perform history entry deletions.
class HistoryNotifier extends StateNotifier<AsyncValue<void>> {
  HistoryNotifier(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> deleteEntry(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(historyRepositoryProvider);
      await repository.deleteEntry(id);
      ref
        ..invalidate(historyEntriesProvider)
        ..invalidate(allHistoryEntriesProvider)
        ..invalidate(availableAppChipsProvider);
    });
  }

  Future<void> clearAll() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(historyRepositoryProvider);
      await repository.clearAll();
      ref
        ..invalidate(historyEntriesProvider)
        ..invalidate(allHistoryEntriesProvider)
        ..invalidate(availableAppChipsProvider);
    });
  }
}

final historyNotifierProvider =
    StateNotifierProvider<HistoryNotifier, AsyncValue<void>>(
      HistoryNotifier.new,
    );
