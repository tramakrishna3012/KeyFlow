import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// The KeyFlow Light Theme, matching the light studio prototype.
///
/// Uses Plus Jakarta Sans / Inter as the primary display font and
/// JetBrains Mono for code/label elements.
class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    final textThemeBase = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.light().textTheme,
    );

    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,

      // ── Colors ────────────────────────────────────────────────────
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.destructive,
      ),

      // ── Typography ────────────────────────────────────────────────
      textTheme: textThemeBase.copyWith(
        // Screen titles / greeting: 20px Bold #0F172A
        headlineMedium: textThemeBase.headlineMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        // Section titles: 16px Semibold
        titleLarge: textThemeBase.titleLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        // Card titles / sub-headings: 14px Semibold
        titleMedium: textThemeBase.titleMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        // Body text: 12px Regular #334155
        bodyMedium: textThemeBase.bodyMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        // Body large: 14px Regular
        bodyLarge: textThemeBase.bodyLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        // Small labels: 10px Semibold #64748B
        labelSmall: textThemeBase.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textMuted,
        ),
        // Button text / links: 12px Semibold #2563EB
        labelMedium: textThemeBase.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 0.8),
        ),
      ),

      // ── Inputs ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.inputBorder,
            width: 0.8,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.inputBorder,
            width: 0.8,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),

      // ── Bottom Nav ────────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardSurface,
        selectedItemColor: AppColors.navActive,
        unselectedItemColor: AppColors.navInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 2,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
      ),

      // ── AppBar ────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.scaffoldBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: textThemeBase.headlineMedium?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      // ── Dialog Theme ──────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardSurface,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 0.8),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),

      // ── Divider ───────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder,
        thickness: 0.8,
      ),

      // ── Switch ────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.toggleKnob),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.toggleOn;
          }
          return AppColors.toggleOff;
        }),
        trackOutlineColor: WidgetStateProperty.all(AppColors.cardBorder),
      ),
    );
  }

  /// Dark theme alias pointing to dark theme properties if needed
  static ThemeData get dark => light;
}

