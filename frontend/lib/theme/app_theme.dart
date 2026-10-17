import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum AppThemeMode {
  obsidianNeon,
  royalSapphire,
  emeraldMint,
  minimalLight,
}

class AppTheme {
  static ThemeData getTheme(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.royalSapphire:
        return _buildTheme(
          brightness: Brightness.dark,
          primary: const Color(0xFF3B82F6),
          accent: const Color(0xFF60A5FA),
          background: const Color(0xFF0F172A),
          surface: const Color(0xFF1E293B),
          card: const Color(0xFF1E293B).withOpacity(0.85),
          textPrimary: const Color(0xFFF8FAFC),
          textSecondary: const Color(0xFF94A3B8),
        );
      case AppThemeMode.emeraldMint:
        return _buildTheme(
          brightness: Brightness.dark,
          primary: const Color(0xFF10B981),
          accent: const Color(0xFF34D399),
          background: const Color(0xFF062820),
          surface: const Color(0xFF0D3B31),
          card: const Color(0xFF0D3B31).withOpacity(0.85),
          textPrimary: const Color(0xFFECFDF5),
          textSecondary: const Color(0xFF6EE7B7),
        );
      case AppThemeMode.minimalLight:
        return _buildTheme(
          brightness: Brightness.light,
          primary: const Color(0xFF2563EB),
          accent: const Color(0xFF06B6D4),
          background: const Color(0xFFF1F5F9),
          surface: Colors.white,
          card: Colors.white.withOpacity(0.95),
          textPrimary: const Color(0xFF0F172A),
          textSecondary: const Color(0xFF64748B),
        );
      case AppThemeMode.obsidianNeon:
      default:
        return _buildTheme(
          brightness: Brightness.dark,
          primary: const Color(0xFF06B6D4), // Cyan neon
          accent: const Color(0xFF8B5CF6),  // Purple neon
          background: const Color(0xFF090D16),
          surface: const Color(0xFF121826),
          card: const Color(0xFF182234).withOpacity(0.8),
          textPrimary: const Color(0xFFF1F5F9),
          textSecondary: const Color(0xFF94A3B8),
        );
    }
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color accent,
    required Color background,
    required Color surface,
    required Color card,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    final baseTextTheme = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        error: const Color(0xFFEF4444),
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: brightness == Brightness.dark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      textTheme: GoogleFonts.outfitTextTheme(baseTextTheme).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withOpacity(0.8),
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: brightness == Brightness.dark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        hintStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
