import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData materialTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6E56F8)),
    useMaterial3: true,
  );

  static const CupertinoThemeData cupertinoTheme = CupertinoThemeData(
    primaryColor: Color(0xFF6E56F8),
    brightness: Brightness.light,
  );
}
