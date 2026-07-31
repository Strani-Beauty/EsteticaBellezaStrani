import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño oficial — Estética y Belleza Strani
/// Basado en el documento ui-design-system.md
class AppTheme {
  AppTheme._();

  // ── Color Palette ──────────────────────────────────────────
  static const Color cDeepAccent   = Color(0xFF6B4F71); // Púrpura profundo (brand primario)
  static const Color cPastelPink   = Color(0xFFF7D6E0);
  static const Color cPastelBlue   = Color(0xFFBEE1E6);
  static const Color cPastelPurple = Color(0xFFE2ECE9);
  static const Color cPastelGold   = Color(0xFFFFF3CD);
  static const Color cDarkText     = Color(0xFF2B2D42);
  static const Color cMutedText    = Color(0xFF6C757D);
  static const Color cBrandGreen   = Color(0xFF1D4A38);
  static const Color cGoldAccent   = Color(0xFF856404);
  static const Color cStripe       = Color(0xFF6772E5);
  static const Color cSuccess      = Color(0xFF198754);
  static const Color cWarning      = Color(0xFFFFC107);
  static const Color cError        = Color(0xFFDC3545);
  static const Color cSurface      = Color(0xFFF9F9F9);
  static const Color cWhite        = Colors.white;

  // ── Gradients ──────────────────────────────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    colors: [cPastelPink, cPastelBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF8B6B9A), Color(0xFF6B4F71)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Border Radius ──────────────────────────────────────────
  static const double radiusXs = 6;
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 18;
  static const double radiusXl = 24;

  // ── Spacing ────────────────────────────────────────────────
  static const double spXs  = 4;
  static const double spSm  = 8;
  static const double spMd  = 16;
  static const double spLg  = 24;
  static const double spXl  = 32;
  static const double spXxl = 48;

  // ── Shadows ────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevatedShadow => [
    BoxShadow(
      color: cDeepAccent.withValues(alpha: 0.18),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  // ── Input Decoration ───────────────────────────────────────
  static InputDecoration fieldDecoration({
    required String label,
    String? hint,
    Widget? prefix,
    Widget? suffix,
    String? error,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      errorText: error,
      filled: true,
      fillColor: cPastelPurple.withValues(alpha: 0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: cDeepAccent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: cError, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: cError, width: 1.5),
      ),
      labelStyle: const TextStyle(color: cMutedText, fontSize: 13),
    );
  }

  // ── ThemeData ──────────────────────────────────────────────
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: cDeepAccent,
        secondary: cBrandGreen,
        surface: cSurface,
        error: cError,
        onPrimary: cWhite,
        onSecondary: cWhite,
        onSurface: cDarkText,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32, fontWeight: FontWeight.bold, color: cDarkText,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 22, fontWeight: FontWeight.bold, color: cDarkText,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 17, fontWeight: FontWeight.w600, color: cDarkText,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14, color: cDarkText,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12, color: cMutedText,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 11, color: cMutedText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cDeepAccent,
          foregroundColor: cWhite,
          elevation: 0,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cDeepAccent,
          side: const BorderSide(color: cDeepAccent),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cDeepAccent,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      cardTheme: CardThemeData(
        color: cWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: Colors.grey.shade100),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: cWhite,
        foregroundColor: cDarkText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: cDarkText,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cPastelPurple,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: cDeepAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cDarkText,
        contentTextStyle: GoogleFonts.inter(color: cWhite, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
