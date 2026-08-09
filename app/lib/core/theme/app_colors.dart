import 'dart:ui';

/// Design tokens extracted from the KeyFlow Figma design.
///
/// All colors match the dark theme prototype at:
/// https://www.figma.com/make/QXF1EzInU2PZ2BRUdCIQp3/Dynamic-UI-for-KeyFlow
class AppColors {
  const AppColors._();

  // ── Background ──────────────────────────────────────────────────────
  /// Deep navy canvas background: #050810
  static const Color canvasBackground = Color(0xFF050810);

  /// Phone shell / scaffold background: #0F1117
  static const Color scaffoldBackground = Color(0xFF0F1117);

  // ── Brand ───────────────────────────────────────────────────────────
  /// Electric violet – primary brand color: #7C6EF8
  static const Color primary = Color(0xFF7C6EF8);

  /// Teal – secondary brand color: #00D4AA
  static const Color secondary = Color(0xFF00D4AA);

  // ── Accents ─────────────────────────────────────────────────────────
  /// Warm orange – used for stats (Time Saved): #FF9A3C
  static const Color accentOrange = Color(0xFFFF9A3C);

  /// Accent pink – used for stats (Languages): #FF6B8A
  static const Color accentPink = Color(0xFFFF6B8A);

  /// Destructive / clear action red
  static const Color destructive = Color(0xFFFF4D6A);

  /// Error color alias for destructive
  static const Color error = Color(0xFFFF4D6A);

  /// Lighter shade of primary violet
  static const Color primaryLight = Color(0xFF9E92FA);

  /// Light surface color
  static const Color surfaceLight = Color(0x1AFFFFFF);

  // ── Surfaces ────────────────────────────────────────────────────────
  /// Card surface: 5 % white opacity
  static const Color cardSurface = Color(0x0DFFFFFF);

  /// Card border: 7-8 % white opacity
  static const Color cardBorder = Color(0x12FFFFFF);

  /// Input field background: ~7 % white opacity
  static const Color inputBackground = Color(0x12FFFFFF);

  /// Input field border: ~8 % white opacity
  static const Color inputBorder = Color(0x14FFFFFF);

  /// Elevated surface (profile card, active states): ~10 % white
  static const Color elevatedSurface = Color(0x1AFFFFFF);

  // ── Text ────────────────────────────────────────────────────────────
  /// Primary text: pure white
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text: off-white #E8EAF0
  static const Color textSecondary = Color(0xFFE8EAF0);

  /// Muted / tertiary text: ~45 % white opacity
  static const Color textMuted = Color(0x73FFFFFF);

  /// Disabled / placeholder text: ~30 % white opacity
  static const Color textDisabled = Color(0x4DFFFFFF);

  // ── Interactive States ──────────────────────────────────────────────
  /// Primary at 18 % opacity – copy button background
  static const Color primaryGhost = Color(0x2E7C6EF8);

  /// Primary at 20 % opacity – active language button
  static const Color primarySubtle = Color(0x337C6EF8);

  /// Primary at 40 % opacity – active language button border
  static const Color primaryBorderActive = Color(0x667C6EF8);

  // ── Toggle ──────────────────────────────────────────────────────────
  /// Toggle track ON: primary violet
  static const Color toggleOn = primary;

  /// Toggle track OFF: ~12 % white
  static const Color toggleOff = Color(0x1FFFFFFF);

  /// Toggle knob: pure white
  static const Color toggleKnob = Color(0xFFFFFFFF);

  // ── Category Tag Colors ─────────────────────────────────────────────
  static const Color tagGreeting = primary;
  static const Color tagEmail = Color(0xFF4CAF50);
  static const Color tagClosing = accentPink;
  static const Color tagMeeting = accentOrange;
  static const Color tagApology = Color(0xFFCE93D8);

  // ── Navigation ──────────────────────────────────────────────────────
  /// Active nav icon/label: primary
  static const Color navActive = primary;

  /// Inactive nav icon/label: muted white
  static const Color navInactive = textMuted;
}
