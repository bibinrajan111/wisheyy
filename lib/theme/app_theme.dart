import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData materialTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6E56F8), brightness: Brightness.dark),
    useMaterial3: true,
    textTheme: GoogleFonts.poppinsTextTheme(),
    scaffoldBackgroundColor: const Color(0xFF0F1024),
    cardTheme: CardThemeData(
      color: const Color(0xFF1D2040),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.06),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );

  static CupertinoThemeData cupertinoTheme = CupertinoThemeData(
    primaryColor: const Color(0xFF6E56F8),
    brightness: Brightness.dark,
    textTheme: CupertinoTextThemeData(
      textStyle: GoogleFonts.poppins(),
    ),
  );
}
