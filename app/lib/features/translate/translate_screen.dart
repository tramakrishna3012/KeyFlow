import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/keyflow_card.dart';

/// Translation screen matching the Figma "Translate" tab.
///
/// Shows: source language input textarea, target language output card,
/// and a grid of language picker buttons.
class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  State<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final _sourceController =
      TextEditingController(text: 'Hello, how are you?');
  String _selectedLang = 'ES';

  static const _languages = [
    _Language(code: 'ES', flag: '🇪🇸', name: 'Spanish'),
    _Language(code: 'FR', flag: '🇫🇷', name: 'French'),
    _Language(code: 'DE', flag: '🇩🇪', name: 'German'),
    _Language(code: 'JA', flag: '🇯🇵', name: 'Japanese'),
    _Language(code: 'ZH', flag: '🇨🇳', name: 'Chinese'),
    _Language(code: 'AR', flag: '🇸🇦', name: 'Arabic'),
    _Language(code: 'PT', flag: '🇧🇷', name: 'Portuguese'),
    _Language(code: 'KO', flag: '🇰🇷', name: 'Korean'),
  ];

  @override
  void dispose() {
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              Text(
                'Translate',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              _buildSourceInput(context),
              const SizedBox(height: 16),
              _buildTargetOutput(context),
              const SizedBox(height: 24),
              Text(
                'Choose language',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _buildLanguageGrid(),
            ],
          ),
        ),
      );

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
                  onTap: () => _sourceController.clear(),
                  child: Text(
                    'Clear',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sourceController,
              maxLines: 3,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Type text to translate...',
                fillColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                '${_sourceController.text.length} characters',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      );

  Widget _buildTargetOutput(BuildContext context) {
    final targetLang =
        _languages.firstWhere((l) => l.code == _selectedLang);
    return KeyFlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(targetLang.flag, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                targetLang.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryGhost,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Copy',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Hola, ¿cómo estás?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 12,
                color: AppColors.secondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Translated on-device',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.secondary,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageGrid() => GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: _languages
            .map(
              (lang) => _buildLanguageButton(lang),
            )
            .toList(),
      );

  Widget _buildLanguageButton(_Language lang) {
    final isActive = lang.code == _selectedLang;
    return GestureDetector(
      onTap: () => setState(() => _selectedLang = lang.code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primarySubtle
              : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.primaryBorderActive
                : AppColors.cardBorder,
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(lang.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              lang.code,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Language {
  const _Language({
    required this.code,
    required this.flag,
    required this.name,
  });

  final String code;
  final String flag;
  final String name;
}
