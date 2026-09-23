import 'package:flutter/material.dart';
import '../services/app_mode_service.dart';

class AppTheme {
  // TV (default) palette
  static const _primaryTV = Color(0xFF1565C0);
  static const _primaryDarkTV = Color(0xFF0D47A1);

  // Fiber palette — teal/green-blue
  static const _primaryFiber = Color(0xFF00695C);
  static const _primaryDarkFiber = Color(0xFF004D40);

  static const _surface = Color(0xFFF5F7FA);
  static const _card = Colors.white;

  static const paid = Color(0xFF2E7D32);
  static const unpaid = Color(0xFFC62828);
  static const overpaid = Color(0xFF1565C0);
  static const partial = Color(0xFFEF6C00);
  static const pending = Color(0xFFE65100); // amber — dashboard KPI
  static const neutral = Color(0xFF616161);

  static Color dueColor(double due) {
    if (due < 0) return overpaid;
    if (due == 0) return paid;
    return unpaid;
  }

  static ThemeData themeFor(ServiceMode mode) {
    final primary = mode == ServiceMode.tv ? _primaryTV : _primaryFiber;
    final primaryDark = mode == ServiceMode.tv
        ? _primaryDarkTV
        : _primaryDarkFiber;

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        surface: _surface,
      ),
      scaffoldBackgroundColor: _surface,
      cardTheme: const CardThemeData(
        color: _card,
        elevation: 1,
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A2E),
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF333333)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF555555)),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // backward compat alias
  static ThemeData get theme => themeFor(ServiceMode.tv);
}
