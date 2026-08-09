import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provides the global [SupabaseClient] instance for dependency injection.
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Fetches all rows from the `keys` Supabase table.
///
/// Returns raw `List<Map<String, dynamic>>` so consumers can map into
/// domain models as needed.
final supabaseKeysProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client.from('keys').select();
  return List<Map<String, dynamic>>.from(response);
});

/// Fetches all rows from the `emojis` Supabase table.
///
/// Each row is expected to have at minimum:
/// `char`, `name`, `shortcode`, `category`, `keywords` (JSON array).
final supabaseEmojisProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client.from('emojis').select();
  return List<Map<String, dynamic>>.from(response);
});

/// Fetches all rows from the `languages` Supabase table.
///
/// Each row is expected to have: `code`, `flag`, `name`.
final supabaseLanguagesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client.from('languages').select();
  return List<Map<String, dynamic>>.from(response);
});
