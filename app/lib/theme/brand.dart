import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

/// ClosetIQ Studio brand. Cream, ink and gold match the consumer app's palette
/// and the Studio mockups.
class Brand {
  static const cream = Color(0xFFF5EFE6);
  static const card = Color(0xFFFFFCF7);
  static const ink = Color(0xFF1C1915);
  static const muted = Color(0xFF70675C);
  static const line = Color(0xFFE5DBCC);
  static const soft = Color(0xFFEFE6D9);
  static const gold = Color(0xFFA8894F);
  static const goldInk = Color(0xFFFFFAF0);
  static const positive = Color(0xFF2F6B45);
  static const positiveBg = Color(0xFFDCE8DF);
  static const danger = Color(0xFF8C3B2A);
  static const dangerBg = Color(0xFFF6E4DC);

  static const swatches = <int>[
    0xFFB08A62,
    0xFFC5BEA8,
    0xFF5C4638,
    0xFFD9C7A6,
    0xFF8D7355,
    0xFFC4A574,
  ];
}

ThemeData buildStudioTheme() {
  final body = GoogleFonts.interTight(color: Brand.ink, fontSize: 15, height: 1.4);
  final display = GoogleFonts.fraunces(color: Brand.ink, fontWeight: FontWeight.w600, height: 1.05);
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: Brand.cream,
    colorScheme: const ColorScheme.light(
      primary: Brand.ink,
      onPrimary: Brand.cream,
      secondary: Brand.gold,
      onSecondary: Brand.goldInk,
      surface: Brand.card,
      onSurface: Brand.ink,
      error: Brand.danger,
    ),
    textTheme: TextTheme(
      displaySmall: display.copyWith(fontSize: 36, letterSpacing: -0.4),
      headlineMedium: display.copyWith(fontSize: 28, letterSpacing: -0.3),
      headlineSmall: display.copyWith(fontSize: 22),
      titleLarge: GoogleFonts.interTight(fontSize: 18, fontWeight: FontWeight.w600, color: Brand.ink),
      titleMedium: GoogleFonts.interTight(fontSize: 15, fontWeight: FontWeight.w600, color: Brand.ink),
      bodyLarge: body.copyWith(fontSize: 16),
      bodyMedium: body,
      bodySmall: body.copyWith(fontSize: 13, color: Brand.muted),
      labelLarge: GoogleFonts.interTight(fontSize: 14, fontWeight: FontWeight.w600, color: Brand.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: body.copyWith(color: Brand.muted),
      labelStyle: body.copyWith(color: Brand.muted, fontSize: 13, fontWeight: FontWeight.w600),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Brand.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Brand.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Brand.ink, width: 1.4)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Brand.gold,
        foregroundColor: Brand.goldInk,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.interTight(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Brand.ink,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: Brand.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.interTight(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    dividerColor: Brand.line,
    splashFactory: InkRipple.splashFactory,
  );
}

BoxDecoration studioCard({Color color = Brand.card, double radius = 18}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: color == Brand.ink ? color : Brand.line),
  );
}
