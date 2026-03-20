import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// GigCredit Unified Dark Fintech Theme
/// Inspired by the reference app image:
///   - Deep navy background  (#0D1540)
///   - Mid-navy card surface (#172060 / #1C2A75)
///   - Vivid magenta accent  (#D72EF5 / #EE2BF5)
///   - Electric blue accent  (#3D7BFF)
///   - White bold typography
class GigTheme {
  // ── Color palette ──────────────────────────────────────
  static const Color bg         = Color(0xFF0B1340);  // deep nav bg
  static const Color bgDeep     = Color(0xFF070D2B);  // darkest - scaffold
  static const Color surface    = Color(0xFF152065);  // card / panel
  static const Color surfaceUp  = Color(0xFF1C2A80);  // raised card
  static const Color divider    = Color(0xFF243190);  // subtle border
  static const Color magenta    = Color(0xFFEE2BF5);  // primary accent
  static const Color blue       = Color(0xFF3D7BFF);  // secondary accent
  static const Color teal       = Color(0xFF00D4AA);  // success / tertiary
  static const Color txtPrimary = Color(0xFFFFFFFF);
  static const Color txtSecond  = Color(0xFFB0BEE8);  // muted white
  static const Color txtHint    = Color(0xFF6878B0);

  // ── Gradients ───────────────────────────────────────────
  static const LinearGradient heroGrad = LinearGradient(
    colors: [Color(0xFF0B1340), Color(0xFF1A2A7A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient accentGrad = LinearGradient(
    colors: [blue, magenta],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient cardGrad = LinearGradient(
    colors: [Color(0xFF172870), Color(0xFF1C3088)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Step accent colors ─────────────────────────────────
  static const Map<int, Color> stepColors = {
    1: Color(0xFF3D7BFF),
    2: Color(0xFFEE2BF5),
    3: Color(0xFF00D4AA),
    4: Color(0xFFFF8C42),
    5: Color(0xFF7C5DD8),
    6: Color(0xFF1EC97F),
    7: Color(0xFFFF4F7B),
    8: Color(0xFF2DC9F4),
    9: Color(0xFFFFBA00),
  };

  // ── Box decorations ─────────────────────────────────────
  static BoxDecoration surfaceCard({Color? accent}) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: accent != null ? accent.withAlpha(60) : divider,
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha(80),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration glassCard({Color? accent}) => BoxDecoration(
    gradient: cardGrad,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: accent != null ? accent.withAlpha(80) : divider,
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: (accent ?? blue).withAlpha(40),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
    ],
  );

  static BoxDecoration accentButton() => BoxDecoration(
    gradient: accentGrad,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: magenta.withAlpha(80),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );

  // ── ThemeData ────────────────────────────────────────────
  static ThemeData get themeData {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDeep,
      colorScheme: const ColorScheme.dark(
        primary: blue,
        secondary: magenta,
        surface: surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: txtPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: txtPrimary,
        titleTextStyle: TextStyle(
          color: txtPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        iconTheme: IconThemeData(color: txtPrimary),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: divider),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: const TextStyle(color: txtHint, fontSize: 14),
        labelStyle: const TextStyle(color: txtSecond),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: blue, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: blue,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: TextStyle(color: txtPrimary),
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
    );
  }
}

// Backward-compatible alias
class AppTheme {
  static ThemeData get light => GigTheme.themeData;

  static const LinearGradient primaryGradient = GigTheme.heroGrad;
  static const LinearGradient accentGradient  = GigTheme.accentGrad;
}
