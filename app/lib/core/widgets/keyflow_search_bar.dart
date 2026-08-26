import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Search input field matching the Figma design.
///
/// Rounded 16px corners, 7% white background, search icon prefix.
class KeyFlowSearchBar extends StatelessWidget {
  const KeyFlowSearchBar({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.controller,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    onChanged: onChanged,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      hintText: hintText,
      prefixIcon: const Icon(
        Icons.search_rounded,
        color: AppColors.textMuted,
        size: 18,
      ),
    ),
  );
}
