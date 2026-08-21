import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/supabase_providers.dart';
import 'translation_service.dart';

const List<Map<String, String>> kDefaultLanguages = [
  {'code': 'es', 'flag': '🇪🇸', 'name': 'Spanish'},
  {'code': 'fr', 'flag': '🇫🇷', 'name': 'French'},
  {'code': 'de', 'flag': '🇩🇪', 'name': 'German'},
  {'code': 'ja', 'flag': '🇯🇵', 'name': 'Japanese'},
  {'code': 'zh', 'flag': '🇨🇳', 'name': 'Chinese'},
  {'code': 'ar', 'flag': '🇸🇦', 'name': 'Arabic'},
  {'code': 'pt', 'flag': '🇧🇷', 'name': 'Portuguese'},
  {'code': 'ko', 'flag': '🇰🇷', 'name': 'Korean'},
];

/// Dynamically resolves available languages from Supabase with static fallback
final availableLanguagesProvider = Provider<List<Map<String, String>>>((ref) {
  final supabaseAsync = ref.watch(supabaseLanguagesProvider);
  return supabaseAsync.when(
    data: (rows) {
      if (rows.isEmpty) return kDefaultLanguages;
      return rows.map((r) => {
        'code': r['code'] as String? ?? 'es',
        'flag': r['flag'] as String? ?? '🌐',
        'name': r['name'] as String? ?? 'Unknown',
      }).toList();
    },
    loading: () => kDefaultLanguages,
    error: (_, _) => kDefaultLanguages,
  );
});

final translationServiceProvider = Provider<TranslationService>(
  (ref) => TranslationService(),
);

final sourceTextProvider = StateProvider<String>(
  (ref) => 'Hello, how are you?',
);

final targetLangProvider = StateProvider<String>((ref) => 'es');

final userApprovedCloudProvider = StateProvider<bool>((ref) => false);

final translationResultProvider = FutureProvider<TranslationResult>((
  ref,
) async {
  final service = ref.watch(translationServiceProvider);
  final text = ref.watch(sourceTextProvider);
  final targetLang = ref.watch(targetLangProvider);
  final approved = ref.watch(userApprovedCloudProvider);

  return service.translate(
    text: text,
    targetLang: targetLang,
    userApprovedCloud: approved,
  );
});
