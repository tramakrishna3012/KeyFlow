import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'translation_service.dart';

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
