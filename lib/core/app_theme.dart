import 'package:flutter/material.dart';

abstract final class DocColors {
  static const primary = Color(0xFF50C2C0);
  static const greenSea = Color(0xFF16A085);
  static const clouds = Color(0xFFECF0F1);
  static const muted = Color(0xFF95A5A6);
}

ThemeData docDiaryTheme() => ThemeData(
  useMaterial3: false,
  fontFamily: 'Poppins',
  colorScheme: ColorScheme.fromSeed(
    seedColor: DocColors.primary,
    primary: DocColors.greenSea,
    secondary: DocColors.primary,
  ),
  scaffoldBackgroundColor: Colors.white,
  appBarTheme: const AppBarTheme(
    backgroundColor: DocColors.clouds,
    foregroundColor: Colors.black,
    elevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: DocColors.clouds,
    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(40),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(40),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(40),
      borderSide: const BorderSide(color: DocColors.greenSea),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: DocColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 52),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      textStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
    ),
  ),
);
