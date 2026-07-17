import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier(ThemeMode.system);

class MacroSnapTheme {
  // Modern vibrant palette - habit tracker inspired
  static const Color emerald = Color(0xFF059669);
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color emeraldDark = Color(0xFF047857);
  static const Color amber = Color(0xFFF59E0B);
  static const Color rose = Color(0xFFF43F5E);
  static const Color blue = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color teal = Color(0xFF14B8A6);
  static const Color orange = Color(0xFFF97316);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color surfaceDark = Color(0xFF0A0E1A);
  static const Color cardDark = Color(0xFF1E293B);
  static const Color glassDark = Color(0x1AFFFFFF);
  static const Color glassLight = Color(0x0A000000);

  static const List<Color> macroColors = [rose, amber, blue, emerald, purple];

  static InputDecorationTheme _inputTheme(bool dark) {
    final bg = dark ? cardDark : Colors.white;
    final border = dark ? Colors.white10 : const Color(0xFFE2E8F0);
    return InputDecorationTheme(
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: emerald, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: rose, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: rose, width: 2)),
      labelStyle: TextStyle(fontSize: 14, color: dark ? Colors.white54 : const Color(0xFF94A3B8)),
      hintStyle: TextStyle(fontSize: 14, color: dark ? Colors.white24 : const Color(0xFFCBD5E1)),
    );
  }

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: emerald,
        secondary: amber,
        tertiary: blue,
        surface: surface,
        error: rose,
      ),
      scaffoldBackgroundColor: surface,
      inputDecorationTheme: _inputTheme(false),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: emerald, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: surface,
        foregroundColor: const Color(0xFF0F172A),
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: emerald.withOpacity(0.08),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        selectedItemColor: emerald,
        unselectedItemColor: Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: emeraldLight,
        secondary: amber,
        tertiary: blue,
        surface: surfaceDark,
        error: rose,
      ),
      scaffoldBackgroundColor: surfaceDark,
      inputDecorationTheme: _inputTheme(true),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: emerald,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: emeraldLight, textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1, color: Colors.white),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Colors.white),
        headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white70),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white70),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: surfaceDark,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        selectedItemColor: emeraldLight,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Color(0xFF1E293B),
      ),
    );
  }

  /// Glass card decoration matching the habit tracker aesthetic
  static BoxDecoration glassDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? const Color(0xFF1E293B).withOpacity(0.85)
          : Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.04),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.3)
              : const Color(0xFF059669).withOpacity(0.08),
          blurRadius: 30,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  /// Gradient for glass border shine
  static BoxDecoration glassShine(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          isDark ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.5),
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.04),
      ),
    );
  }
}

