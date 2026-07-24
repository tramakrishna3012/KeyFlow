import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable glassmorphic card matching the Figma design system.
///
/// Uses 5% white background with 0.8px border at 7% opacity,
/// and 16px border radius.
class KeyFlowCard extends StatelessWidget {
  const KeyFlowCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.cardBorder,
            width: 0.8,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ),
      );
}
