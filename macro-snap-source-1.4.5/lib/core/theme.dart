import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(
  ThemeMode.system,
);

/// MacroSnap dark neon theme — Pop UPI inspired bold & vibrant aesthetic
class MacroSnapTheme {
  // ─── Neon Palette ──────────────────────────────────────────
  static const Color neonGreen = Color(0xFF00FF66);
  static const Color neonPink = Color(0xFFFF007F);
  static const Color neonPurple = Color(0xFF7C3AED);
  static const Color neonOrange = Color(0xFFFF6B00);
  static const Color neonCyan = Color(0xFF00D4FF);
  static const Color neonYellow = Color(0xFFFFD600);
  static const Color neonRed = Color(0xFFFF1744);

  // ─── Semantic Macro Color Aliases ──────────────────────────
  /// Calories → amber/orange energy
  static const Color macroCalories = neonOrange;

  /// Protein → pink/rose
  static const Color macroProtein = neonPink;

  /// Carbs → yellow
  static const Color macroCarbs = neonYellow;

  /// Fats → cyan
  static const Color macroFats = neonCyan;

  /// Fiber → green
  static const Color macroFiber = neonGreen;

  // ─── General Purpose Semantic Tokens ───────────────────────
  // Dark-mode hierarchy: textPrimaryMuted (white70) is the BRIGHTEST token
  // (body text on dark gradient cards), then textSecondary (0.64, metadata),
  // then textTertiary (0.52, hints). Not a strict "primary > secondary"
  // ordering by name — brightness follows usage context. Keep it this way.
  /// Primary text color, slightly muted (body text, descriptions)
  static Color textPrimaryMuted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white70
      : const Color(0xFF475569);

  /// Secondary text color (subtle, for metadata/descriptions)
  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.64)
      : const Color(0xFF64748B);

  /// Tertiary text color (very subtle, for hints/placeholders)
  static Color textTertiary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.52)
      : const Color(0xFF94A3B8);

  /// Quaternary text color (barely visible, decorative)
  static Color textQuaternary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white38
      : const Color(0xFFCBD5E1);

  /// Green used for TEXT (not fills/icons). Neon green (#00FF66) has terrible
  /// contrast on white/light cards, so light mode swaps it for a darker,
  /// readable green while dark mode keeps the bright neon accent.
  static Color greenText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? neonGreen
      : const Color(0xFF008A43);

  /// Card background color (themed)
  static Color cardBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? cardDark : Colors.white;

  /// Subtle border color
  static Color borderSubtle(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Colors.white10
      : const Color(0xFFE2E8F0);

  /// Convenience: list of all macro colors for cycling
  static const List<Color> macroColors = [
    neonPink,
    neonOrange,
    neonCyan,
    neonGreen,
    neonPurple,
    neonYellow,
  ];

  // ─── Background & Surface Colors ───────────────────────────
  static const Color surfaceDark = Color(0xFF07070A);
  static const Color surfaceLight = Color(0xFFE8E2FF);
  static const Color cardDark = Color(0xFF111118);
  static const Color cardDarkBorder = Color(0xFF2E2E3E);
  static const Color cardDarkLight = Color(0xFF181822);

  // ─── Card Decorations ──────────────────────────────────────
  /// Hero gradient card with neon border (Pop UPI hero card style).
  ///
  /// Theme-aware: dark mode keeps the signature near-black hero gradient;
  /// light mode uses the matching light gradient (same as [habitlyCard]) so
  /// hero cards like "Calorie goal" and "Make it count" never stay dark when
  /// the app is in light theme.
  static BoxDecoration habitlyHeroCard(
    BuildContext context, {
    BorderRadius? borderRadius = const BorderRadius.all(Radius.circular(28)),
    bool showBorder = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF050508), Color(0xFF181830), Color(0xFF11151E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: borderRadius,
        border: showBorder ? Border.all(color: const Color(0xFF353550)) : null,
      );
    }
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF4EFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: borderRadius,
      border: showBorder ? Border.all(color: const Color(0xFFC8BEFF)) : null,
    );
  }

  /// Standard elevated card (Pop UPI style).
  ///
  /// Shares the exact same rich gradient background as the hero "Make it
  /// count" card in dark mode so every card across the app looks uniform.
  /// Light mode uses a matching light gradient to preserve readability.
  static BoxDecoration habitlyCard(
    BuildContext context, {
    BorderRadius? borderRadius = const BorderRadius.all(Radius.circular(28)),
    bool showBorder = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      // Identical to the hero card → uniform dark gradient cards everywhere.
      return habitlyHeroCard(
        context,
        borderRadius: borderRadius,
        showBorder: showBorder,
      );
    }
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFF4EFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: borderRadius,
      border: showBorder ? Border.all(color: const Color(0xFFC8BEFF)) : null,
    );
  }

  /// Mission-style emoji icon container — a vivid tinted tile with a
  /// strong colored border and glow so emoji glyphs pop with rich color
  /// instead of looking washed out.
  static BoxDecoration emojiContainer(Color color) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0.26)],
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.65), width: 1.4),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  /// Style for emoji glyphs — FLAT, with no text shadows.
  ///
  /// Shadows on emoji glyphs previously painted a dark "ghost reflection"
  /// under the emoji (visible when swiping cards or on tinted chips). Every
  /// emoji surface in the app now renders flat; the vivid tinted tile behind
  /// it ([emojiContainer]) provides the depth instead.
  static TextStyle emojiStyle({double fontSize = 25}) {
    return TextStyle(fontSize: fontSize);
  }

  /// Neon accent pill
  static BoxDecoration neonPill(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    );
  }

  // ─── Input Theme ───────────────────────────────────────────
  static InputDecorationTheme _inputTheme(bool dark) {
    final bg = dark ? cardDark : Colors.white;
    final border = dark ? Colors.white10 : const Color(0xFFE8DEFF);
    return InputDecorationTheme(
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: neonGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: neonPink, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: neonPink, width: 2),
      ),
      labelStyle: TextStyle(
        fontSize: 14,
        color: dark
            ? Colors.white.withValues(alpha: 0.64)
            : const Color(0xFF94A3B8),
      ),
      hintStyle: TextStyle(
        fontSize: 14,
        color: dark
            ? Colors.white.withValues(alpha: 0.4)
            : const Color(0xFFCBD5E1),
      ),
    );
  }

  // ─── Light Theme ───────────────────────────────────────────
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: neonGreen,
        secondary: neonPink,
        tertiary: neonCyan,
        surface: surfaceLight,
        error: neonPink,
      ),
      scaffoldBackgroundColor: surfaceLight,
      inputDecorationTheme: _inputTheme(false),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neonGreen,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      // Inter is bundled as an asset (assets/fonts/Inter.ttf) — referenced
      // directly so there is no runtime font fetch. The variable font covers
      // every weight the theme uses.
      textTheme: ThemeData.light().textTheme
          .apply(fontFamily: 'Inter')
          .copyWith(
            displayLarge: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              fontFamily: 'Inter',
            ),
            displayMedium: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              fontFamily: 'Inter',
            ),
            headlineLarge: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
            ),
            headlineMedium: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
            ),
            titleLarge: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
            bodyLarge: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
            ),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFamily: 'Inter',
            ),
          ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1A1A1A),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF1A1A1A),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        shadowColor: neonGreen.withValues(alpha: 0.08),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        selectedItemColor: neonGreen,
        unselectedItemColor: Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
      ),
    );
  }

  // ─── Dark Theme (Habitly Noir) ─────────────────────────────
  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: neonGreen,
        secondary: neonPink,
        tertiary: neonCyan,
        surface: surfaceDark,
        error: neonPink,
      ),
      scaffoldBackgroundColor: surfaceDark,
      inputDecorationTheme: _inputTheme(true),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: neonGreen,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textTheme: ThemeData.dark().textTheme
          .apply(fontFamily: 'Inter')
          .copyWith(
            displayLarge: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
            displayMedium: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
            headlineLarge: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
            headlineMedium: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
            titleLarge: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
            titleMedium: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
            bodyLarge: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
              fontFamily: 'Inter',
            ),
            bodyMedium: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
              fontFamily: 'Inter',
            ),
            labelLarge: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        selectedItemColor: neonGreen,
        unselectedItemColor: Colors.white30,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFF17171D),
      ),
    );
  }

  // ─── Glass Decoration (unified) ────────────────────────────
  static BoxDecoration glassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? habitlyCard(context)
        : BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF4EFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFC8BEFF)),
            boxShadow: [
              BoxShadow(
                color: neonGreen.withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          );
  }

  static BoxDecoration glassShine(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
                Color(0xFF050508),
                Color(0xFF181830),
                Color(0xFF11151E),
                Color(0xFF181830),
              ]
            : [
                Colors.white,
                const Color(0xFFF8FAFC),
                const Color(0xFFF8FAFC),
                Colors.white.withValues(alpha: 0.5),
              ],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: isDark
            ? const Color(0xFF353550)
            : Colors.black.withValues(alpha: 0.04),
      ),
    );
  }
}
