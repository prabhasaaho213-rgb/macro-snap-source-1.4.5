import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

/// MacroSnap dark neon theme — Pop UPI inspired bold & vibrant aesthetic
class MacroSnapTheme {
  // ─── Pop UPI Inspired Neon Palette ─────────────────────────
  static const Color neonGreen = Color(0xFF00FF66);
  static const Color neonPink = Color(0xFFFF007F);
  static const Color neonPurple = Color(0xFF7C3AED);
  static const Color neonOrange = Color(0xFFFF6B00);
  static const Color neonCyan = Color(0xFF00D4FF);
  static const Color neonYellow = Color(0xFFFFD600);
  static const Color neonRed = Color(0xFFFF1744);

  // Legacy MacroSnap colors (kept for backward compat)
  static const Color emerald = Color(0xFF00C853);
  static const Color emeraldLight = Color(0xFF69F0AE);
  static const Color emeraldDark = Color(0xFF009624);
  static const Color amber = Color(0xFFFFAB00);
  static const Color rose = Color(0xFFFF1744);
  static const Color blue = Color(0xFF2979FF);
  static const Color purple = Color(0xFF7C4DFF);
  static const Color teal = Color(0xFF00E5FF);
  static const Color orange = Color(0xFFFF6D00);
  static const Color surface = Color(0xFFE8E2FF);

  // Pop UPI dark backgrounds (deeper noir + vibrant accents)
  static const Color surfaceDark = Color(0xFF07070A);
  static const Color cardDark = Color(0xFF111118);
  static const Color cardDarkBorder = Color(0xFF2E2E3E);
  static const Color cardDarkLight = Color(0xFF181822);

  // MacroSnap legacy backgrounds
  static const Color glassDark = Color(0x1AFFFFFF);
  static const Color glassLight = Color(0x0A000000);

  static const List<Color> macroColors = [neonPink, neonOrange, neonCyan, neonGreen, neonPurple, neonYellow];

  // ─── Pop UPI-style Card Decoration ─────────────────────────
  /// Dark gradient card with neon border (Pop UPI hero card style)
  static BoxDecoration habitlyHeroCard(BuildContext context) {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF050508), Color(0xFF181830), Color(0xFF11151E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFF353550)),
    );
  }

  /// Standard elevated card (Pop UPI style)
  static BoxDecoration habitlyCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? cardDark : Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: isDark ? const Color(0xFF303045) : const Color(0xFFC8BEFF),
      ),
    );
  }

  /// Mission-style emoji icon container
  static BoxDecoration emojiContainer(Color color) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(16),
    );
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: neonGreen, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: neonPink, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: neonPink, width: 2)),
      labelStyle: TextStyle(fontSize: 14, color: dark ? Colors.white54 : const Color(0xFF94A3B8)),
      hintStyle: TextStyle(fontSize: 14, color: dark ? Colors.white24 : const Color(0xFFCBD5E1)),
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
        surface: surface,
        error: neonPink,
      ),
      scaffoldBackgroundColor: surface,
      inputDecorationTheme: _inputTheme(false),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: neonGreen,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF1A1A1A),
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1, color: Colors.white),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: Colors.white),
        headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white70),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
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

  // ─── Legacy glass decoration (keep for backward compat) ───
  static BoxDecoration glassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? habitlyCard(context) : BoxDecoration(
      color: Colors.white.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF059669).withValues(alpha: 0.08),
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
        colors: [
          isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          isDark ? cardDark : const Color(0xFFF8FAFC),
          isDark ? cardDark : const Color(0xFFF8FAFC),
          isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.5),
        ],
      ),
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
      ),
    );
  }
}

