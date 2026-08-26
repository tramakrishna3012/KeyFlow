import 'dart:ui';

/// Design tokens extracted from the KeyFlow Light Theme prototype.
///
/// Matches the light theme design system:
/// - Slate-50 background base (#F8FAFC)
/// - Pure white card surfaces (#FFFFFF) with subtle Slate-200 borders (#E2E8F0)
/// - KeyFlow Brand Blue (#2563EB) primary actions
/// - High contrast dark typography (#0F172A / #334155 / #64748B)
class AppColors {
  const AppColors._();

  // ── Background & Canvas ─────────────────────────────────────────────
  /// Ambient light canvas / outer frame: #F1F5F9 (Slate-100)
  static const Color canvasBackground = Color(0xFFF1F5F9);

  /// Phone shell / scaffold background: #F8FAFC (Slate-50)
  static const Color scaffoldBackground = Color(0xFFF8FAFC);

  // ── Brand ───────────────────────────────────────────────────────────
  /// KeyFlow Brand Blue – primary action color: #2563EB (Blue-600)
  static const Color primary = Color(0xFF2563EB);

  /// Emerald – secondary brand color: #059669 (Emerald-600)
  static const Color secondary = Color(0xFF059669);

  // ── Accents ─────────────────────────────────────────────────────────
  /// Warm orange / amber – used for stats (Time Saved): #D97706 (Amber-600)
  static const Color accentOrange = Color(0xFFD97706);

  /// Accent pink / rose – used for stats (Languages): #E11D48 (Rose-600)
  static const Color accentPink = Color(0xFFE11D48);

  /// Destructive / clear action red: #DC2626 (Red-600)
  static const Color destructive = Color(0xFFDC2626);

  /// Error color alias for destructive
  static const Color error = Color(0xFFDC2626);

  /// Lighter shade of primary blue: #60A5FA (Blue-400)
  static const Color primaryLight = Color(0xFF60A5FA);

  /// Light surface color for containers: #F1F5F9 (Slate-100)
  static const Color surfaceLight = Color(0xFFF1F5F9);

  // ── Surfaces ────────────────────────────────────────────────────────
  /// Card surface: pure white #FFFFFF
  static const Color cardSurface = Color(0xFFFFFFFF);

  /// Card border: subtle light border #E2E8F0 (Slate-200)
  static const Color cardBorder = Color(0xFFE2E8F0);

  /// Input field background: pure white #FFFFFF / Slate-50 #F8FAFC
  static const Color inputBackground = Color(0xFFFFFFFF);

  /// Input field border: #CBD5E1 (Slate-300)
  static const Color inputBorder = Color(0xFFCBD5E1);

  /// Elevated surface (profile card, active states): #FFFFFF
  static const Color elevatedSurface = Color(0xFFFFFFFF);

  // ── Text ────────────────────────────────────────────────────────────
  /// Primary text: high-contrast dark #0F172A (Slate-900)
  static const Color textPrimary = Color(0xFF0F172A);

  /// Secondary text: dark slate #334155 (Slate-700)
  static const Color textSecondary = Color(0xFF334155);

  /// Muted / tertiary text: neutral slate #64748B (Slate-500)
  static const Color textMuted = Color(0xFF64748B);

  /// Disabled / placeholder text: soft slate #94A3B8 (Slate-400)
  static const Color textDisabled = Color(0xFF94A3B8);

  // ── Interactive States ──────────────────────────────────────────────
  /// Primary at 10% opacity – copy button background / ghost badge
  static const Color primaryGhost = Color(0x1A2563EB);

  /// Primary at 12% opacity – active language button
  static const Color primarySubtle = Color(0x1F2563EB);

  /// Primary border active: #93C5FD (Blue-300)
  static const Color primaryBorderActive = Color(0xFF93C5FD);

  // ── Toggle ──────────────────────────────────────────────────────────
  /// Toggle track ON: primary brand blue
  static const Color toggleOn = primary;

  /// Toggle track OFF: subtle slate border #CBD5E1
  static const Color toggleOff = Color(0xFFE2E8F0);

  /// Toggle knob: pure white
  static const Color toggleKnob = Color(0xFFFFFFFF);

  // ── Category Tag Colors ─────────────────────────────────────────────
  static const Color tagGreeting = primary;
  static const Color tagEmail = Color(0xFF16A34A);
  static const Color tagClosing = accentPink;
  static const Color tagMeeting = accentOrange;
  static const Color tagApology = Color(0xFF9333EA);

  // ── Navigation ──────────────────────────────────────────────────────
  /// Active nav icon/label: primary brand blue
  static const Color navActive = primary;

  /// Inactive nav icon/label: muted slate #64748B
  static const Color navInactive = textMuted;

  // ── Floating Bot Spotlight Overlay Tokens ───────────────────────────
  /// High-contrast dark frosted backdrop for floating bot bubble/panel
  static const Color botPanelBackground = Color(0xF20F172A);

  /// Bot cyan glow highlight: #38BDF8 (Sky-400)
  static const Color botGlow = Color(0xFF38BDF8);

  /// Bot border accent: 15% white opacity
  static const Color botBorder = Color(0x26FFFFFF);
}

