import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';
import '../../data/supabase_providers.dart';
import 'translation_providers.dart';
import 'translation_service.dart';

class TranslateScreen extends ConsumerStatefulWidget {
  const TranslateScreen({super.key});

  @override
  ConsumerState<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends ConsumerState<TranslateScreen> {
  late final TextEditingController _sourceController;

  /// Local fallback language list, used when the Supabase fetch fails.
  static const List<Map<String, String>> _fallbackLanguages = [
    {'code': 'es', 'flag': '🇪🇸', 'name': 'Spanish'},
    {'code': 'fr', 'flag': '🇫🇷', 'name': 'French'},
    {'code': 'de', 'flag': '🇩🇪', 'name': 'German'},
    {'code': 'ja', 'flag': '🇯🇵', 'name': 'Japanese'},
    {'code': 'zh', 'flag': '🇨🇳', 'name': 'Chinese'},
    {'code': 'ar', 'flag': '🇸🇦', 'name': 'Arabic'},
    {'code': 'pt', 'flag': '🇧🇷', 'name': 'Portuguese'},
    {'code': 'ko', 'flag': '🇰🇷', 'name': 'Korean'},
  ];

  @override
  void initState() {
    super.initState();
    final initialText = ref.read(sourceTextProvider);
    _sourceController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  void _onSourceTextChanged(String val) {
    ref.read(sourceTextProvider.notifier).state = val;
    // Reset per-use approval when text changes
    ref.read(userApprovedCloudProvider.notifier).state = false;
  }

  void _requestCloudApproval(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Cloud Translation Approval', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: const Text(
          'This text requires cloud translation. Send only this single text snippet to the KeyFlow Translation Relay Service?\n\nKeyFlow will never log or persist your text content.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(userApprovedCloudProvider.notifier).state = true;
            },
            child: const Text('Approve & Translate', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translationAsync = ref.watch(translationResultProvider);
    final selectedLang = ref.watch(targetLangProvider);
    final languagesAsync = ref.watch(supabaseLanguagesProvider);

    // Resolve the language list: Supabase data → local fallback.
    final List<Map<String, String>> languages;
    final bool languagesLoading;
    if (languagesAsync.isLoading) {
      languages = _fallbackLanguages;
      languagesLoading = true;
    } else if (languagesAsync.hasError || !languagesAsync.hasValue || languagesAsync.value!.isEmpty) {
      languages = _fallbackLanguages;
      languagesLoading = false;
    } else {
      languages = languagesAsync.value!
          .map((row) => <String, String>{
                'code': row['code']?.toString() ?? '',
                'flag': row['flag']?.toString() ?? '',
                'name': row['name']?.toString() ?? '',
              })
          .toList();
      languagesLoading = false;
    }

    final currentLangObj = languages.firstWhere(
      (l) => l['code'] == selectedLang,
      orElse: () => languages.first,
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            Text(
              'Translate',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),

            // Source Text Input Box
            _buildSourceInput(context),

            const SizedBox(height: 16),

            // Target Translation Output Box
            _buildTargetOutput(context, translationAsync, currentLangObj),

            const SizedBox(height: 24),

            Text(
              'Choose Target Language',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (languagesLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              _buildLanguageGrid(selectedLang, languages),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceInput(BuildContext context) => KeyFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🇺🇸', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'English',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  _sourceController.clear();
                  _onSourceTextChanged('');
                },
                child: Text(
                  'Clear',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sourceController,
            maxLines: 3,
            onChanged: _onSourceTextChanged,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              hintText: 'Enter or paste text to translate...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );

  Widget _buildTargetOutput(
    BuildContext context,
    AsyncValue<TranslationResult> translationAsync,
    Map<String, String> langObj,
  ) => KeyFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(langObj['flag'] ?? '', style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                langObj['name'] ?? '',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          translationAsync.when(
            data: (res) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  res.translatedText.isEmpty ? 'Translation will appear here...' : res.translatedText,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: res.translatedText.isEmpty ? AppColors.textDisabled : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Status Badge Label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: res.isCloud ? AppColors.primarySubtle : AppColors.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: res.isCloud ? AppColors.primaryBorderActive : AppColors.secondary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            res.isCloud ? Icons.cloud_done_outlined : Icons.offline_bolt_outlined,
                            size: 14,
                            color: res.isCloud ? AppColors.primary : AppColors.secondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            res.attributionBadge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: res.isCloud ? AppColors.primary : AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (res.translatedText.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                        tooltip: 'Copy Translation',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: res.translatedText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Translation copied to clipboard!')),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) {
              if (err is CloudApprovalRequiredException) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'On-device model unavailable for this phrase.',
                      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _requestCloudApproval(context),
                      icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                      label: const Text('Approve Cloud Translation'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                    ),
                  ],
                );
              }

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.destructive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.destructive.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.destructive, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        err.toString(),
                        style: const TextStyle(fontSize: 12, color: AppColors.destructive, height: 1.3),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );

  Widget _buildLanguageGrid(String activeLangCode, List<Map<String, String>> languages) => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.5,
      ),
      itemCount: languages.length,
      itemBuilder: (ctx, idx) {
        final item = languages[idx];
        final isSelected = item['code'] == activeLangCode;

        return InkWell(
          onTap: () {
            ref.read(targetLangProvider.notifier).state = item['code']!;
            ref.read(userApprovedCloudProvider.notifier).state = false;
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primarySubtle : AppColors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primaryBorderActive : AppColors.cardBorder,
              ),
            ),
            child: Row(
              children: [
                Text(item['flag']!, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(
                  item['name']!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
}
