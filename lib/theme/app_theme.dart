// app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // -------------------------------
  // CORE ACCENT (Notion Mixed Accent Style)
  // -------------------------------
  static const Color accent = Color(0xFF4F46E5); // indigo-violet
  static const Color neutralBg = Color(0xFFF8F7F4); // Notion off-white background
  static const Color neutralSurface = Color(0xFFFFFFFF);
  static const Color neutralStroke = Color(0xFFE2E2E0);

  // Light theme (Notion-inspired)
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: neutralBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.light,
      background: neutralBg,
      surface: neutralSurface,
      surfaceTint: Colors.transparent,
    ),

    // -------------------------------
    // AppBar (flat, minimal)
    // -------------------------------
    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: neutralBg,
      foregroundColor: Colors.black87,
      surfaceTintColor: Colors.transparent,
    ),

    // -------------------------------
    // Cards (Notion blocks)
    // -------------------------------
    cardTheme: CardThemeData(
      color: neutralSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: neutralStroke, width: 0.6),
      ),
      clipBehavior: Clip.antiAlias,
    ),

    // -------------------------------
    // FAB (accent colored)
    // -------------------------------
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    // -------------------------------
    // Buttons
    // -------------------------------
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    // -------------------------------
    // Input Fields
    // -------------------------------
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F2EF), // soft Notion fill
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: accent, width: 1.6),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: neutralStroke),
        borderRadius: BorderRadius.circular(12),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    // -------------------------------
    // Chips (soft neutral + accent outline)
    // -------------------------------
    chipTheme: ChipThemeData(
      elevation: 0,
      labelStyle: const TextStyle(fontSize: 13),
      side: const BorderSide(color: neutralStroke),
      backgroundColor: neutralSurface,
      selectedColor: accent.withOpacity(0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // -------------------------------
    // Navigation bars
    // -------------------------------
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: neutralBg,
      elevation: 0,
      height: 72,
      surfaceTintColor: Colors.transparent,
      indicatorColor: accent.withOpacity(0.12),
      iconTheme: MaterialStateProperty.all(
        const IconThemeData(size: 26),
      ),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      elevation: 8,
      backgroundColor: neutralBg,
      selectedIconTheme: IconThemeData(size: 28),
      unselectedIconTheme: IconThemeData(size: 22),
    ),

    // -------------------------------
    // Divider (thin + neutral)
    // -------------------------------
    dividerTheme: const DividerThemeData(
      thickness: 0.7,
      color: neutralStroke,
      space: 24,
    ),

    // Typography (clean Notion style)
    textTheme: Typography.material2021().black.apply(
          bodyColor: const Color(0xFF2D2D2D),
          displayColor: const Color(0xFF2D2D2D),
        ),
  );

  // -------------------------------
  // DARK THEME (Notion Neutral Dark)
  // -------------------------------
  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1B1B1B),
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
      surface: const Color(0xFF232323),
      background: const Color(0xFF1B1B1B),
      surfaceTint: Colors.transparent,
    ),

    appBarTheme: const AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Color(0xFF1B1B1B),
      foregroundColor: Colors.white,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),

    cardTheme: CardThemeData(
      color: const Color(0xFF232323),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF383838), width: 0.8),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2A2A2A),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: accent, width: 1.6),
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF383838)),
        borderRadius: BorderRadius.circular(12),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    chipTheme: ChipThemeData(
      elevation: 0,
      side: const BorderSide(color: Color(0xFF383838)),
      backgroundColor: const Color(0xFF232323),
      selectedColor: accent.withOpacity(0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1B1B1B),
      elevation: 0,
      height: 72,
      indicatorColor: accent.withOpacity(0.20),
      iconTheme: MaterialStateProperty.all(
        const IconThemeData(size: 26),
      ),
      labelTextStyle: MaterialStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF1B1B1B),
      elevation: 8,
      selectedIconTheme: IconThemeData(size: 28),
      unselectedIconTheme: IconThemeData(size: 22),
    ),

    dividerTheme: const DividerThemeData(
      thickness: 0.6,
      color: Color(0xFF383838),
      space: 24,
    ),

    textTheme: Typography.material2021().white.apply(
          bodyColor: Colors.white70,
          displayColor: Colors.white70,
        ),
  );

  static ThemeMode defaultMode = ThemeMode.system;
}
