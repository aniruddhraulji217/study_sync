import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFF1A73E8); // Google Blue
  static const fallback = seed;

  // Light theme colors
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorSchemeSeed: seed,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 80,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      elevation: 8,
      selectedIconTheme: IconThemeData(size: 28),
      unselectedIconTheme: IconThemeData(size: 24),
    ),
    drawerTheme: const DrawerThemeData(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    chipTheme: ChipThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: const DividerThemeData(space: 24),
    typography: Typography.material2021(),
  );

  // Dark theme colors
  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorSchemeSeed: seed,
    elevatedButtonTheme: light.elevatedButtonTheme,
    appBarTheme: light.appBarTheme,
    cardTheme: light.cardTheme,
    navigationBarTheme: light.navigationBarTheme,
    bottomNavigationBarTheme: light.bottomNavigationBarTheme,
    drawerTheme: light.drawerTheme,
    inputDecorationTheme: light.inputDecorationTheme,
    chipTheme: light.chipTheme,
    dividerTheme: light.dividerTheme,
    typography: Typography.material2021(),
  );

  static ThemeMode defaultMode = ThemeMode.system;
}