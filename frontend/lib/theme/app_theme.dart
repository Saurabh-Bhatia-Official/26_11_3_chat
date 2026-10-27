import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode {
  obsidianCyber,
  royalSapphire,
  emeraldMint,
  minimalLight;
}

class AppTheme {
  static final ValueNotifier<AppThemeMode> currentThemeNotifier =
      ValueNotifier<AppThemeMode>(AppThemeMode.obsidianCyber);

  static AppThemeMode get currentTheme => currentThemeNotifier.value;

  static AppThemeMode fromString(String? name) {
    if (name == null || name.trim().isEmpty) return AppThemeMode.obsidianCyber;
    final clean = name.trim().toLowerCase();
    for (var m in AppThemeMode.values) {
      if (m.name.toLowerCase() == clean) return m;
    }
    if (clean == 'dark_cyber' || clean == 'dark' || clean == 'obsidian') {
      return AppThemeMode.obsidianCyber;
    }
    if (clean == 'light' || clean == 'minimal') {
      return AppThemeMode.minimalLight;
    }
    if (clean == 'sapphire' || clean == 'blue') {
      return AppThemeMode.royalSapphire;
    }
    if (clean == 'emerald' || clean == 'green' || clean == 'mint') {
      return AppThemeMode.emeraldMint;
    }
    return AppThemeMode.obsidianCyber;
  }

  static void Function(AppThemeMode)? onThemeChanged;

  static Future<void> setTheme(AppThemeMode mode) async {
    currentThemeNotifier.value = mode;
    onThemeChanged?.call(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_preference', mode.name);
    } catch (_) {}
  }

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
      case AppThemeMode.obsidianCyber:
        return _buildTheme(
          brightness: Brightness.dark,
          primary: const Color(0xFF06B6D4), // Electric Cyan
          accent: const Color(0xFF8B5CF6),  // Electric Purple
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

class AppIconHelper {
  static const List<Map<String, dynamic>> options = [
    {
      'id': 'whisper',
      'name': 'Whisper Blue Ribbon',
      'icon': Icons.graphic_eq,
      'color': Color(0xFF1E88E5),
      'description': 'Official Whisper blue sonic wave ribbon',
    },
    {
      'id': 'cyber_pulse',
      'name': 'Cyber Pulse',
      'icon': Icons.bolt,
      'color': Color(0xFF06B6D4),
      'description': 'Electric cyan high-energy pulse',
    },
    {
      'id': 'cyber_shield',
      'name': 'Cyber Shield',
      'icon': Icons.security,
      'color': Color(0xFF10B981),
      'description': 'Emerald defensive guardian',
    },
    {
      'id': 'cosmic_night',
      'name': 'Cosmic Night',
      'icon': Icons.dark_mode,
      'color': Color(0xFF8B5CF6),
      'description': 'Mystic violet astronomical nebula',
    },
    {
      'id': 'solar_flare',
      'name': 'Solar Flare',
      'icon': Icons.local_fire_department,
      'color': Color(0xFFF59E0B),
      'description': 'Radiant amber solar intensity',
    },
  ];

  static Map<String, dynamic> getIcon(String? id) {
    if (id == null || id.isEmpty) return options.first;
    return options.firstWhere(
      (opt) => opt['id'] == id,
      orElse: () => options.first,
    );
  }

  static bool isPredefinedName(String? name) {
    if (name == null || name.trim().isEmpty) return false;
    final clean = name.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    return clean == 'whisper' ||
        clean == 'whisperblueribbon' ||
        clean == 'cyberpulse' ||
        clean == 'cybershield' ||
        clean == 'cosmicnight' ||
        clean == 'solarflare';
  }

  static String normalizePresetName(String? name) {
    if (name == null || name.trim().isEmpty) return 'Whisper';
    final clean = name.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]+'), '');
    switch (clean) {
      case 'whisper':
      case 'whisperblueribbon':
        return 'Whisper';
      case 'cyberpulse':
        return 'Cyber Pulse';
      case 'cybershield':
        return 'Cyber Shield';
      case 'cosmicnight':
        return 'Cosmic Night';
      case 'solarflare':
        return 'Solar Flare';
      default:
        return name.trim();
    }
  }

  static String getPresetSvgFaviconDataUri(String? id) {
    switch (id) {
      case 'whisper':
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><rect width="100" height="100" rx="24" fill="#FFFFFF"/><path d="M22 35 C24 58 35 68 45 42 C48 34 52 34 55 42 C65 68 76 58 78 35" fill="none" stroke="url(#wg)" stroke-width="12" stroke-linecap="round" stroke-linejoin="round"/><path d="M82 28 C86 32 86 40 82 44" fill="none" stroke="#00B4D8" stroke-width="4" stroke-linecap="round"/><path d="M88 22 C94 28 94 44 88 50" fill="none" stroke="#00B4D8" stroke-width="4" stroke-linecap="round"/><defs><linearGradient id="wg" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="#00D2FF"/><stop offset="100%" stop-color="#1E88E5"/></linearGradient></defs></svg>';
        return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
      case 'cyber_shield':
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="#10B981"/><stop offset="100%" stop-color="#059669"/></linearGradient></defs><rect width="100" height="100" rx="24" fill="url(#g)"/><path d="M50 20 L75 32 V55 C75 70 50 82 50 82 C50 82 25 70 25 55 V32 Z" fill="#FFFFFF"/></svg>';
        return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
      case 'cosmic_night':
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="#8B5CF6"/><stop offset="100%" stop-color="#6366F1"/></linearGradient></defs><rect width="100" height="100" rx="24" fill="url(#g)"/><path d="M60 25 A 30 30 0 1 0 75 70 A 25 25 0 0 1 60 25 Z" fill="#FFFFFF"/></svg>';
        return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
      case 'solar_flare':
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="#F59E0B"/><stop offset="100%" stop-color="#EF4444"/></linearGradient></defs><rect width="100" height="100" rx="24" fill="url(#g)"/><path d="M50 20 C50 20 65 40 65 55 C65 68 55 78 50 80 C45 78 35 68 35 55 C35 40 50 20 50 20 Z" fill="#FFFFFF"/></svg>';
        return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
      case 'cyber_pulse':
      default:
        const svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100"><defs><linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" stop-color="#06B6D4"/><stop offset="100%" stop-color="#3B82F6"/></linearGradient></defs><rect width="100" height="100" rx="24" fill="url(#g)"/><polygon points="56,18 32,52 48,52 44,82 68,48 52,48" fill="#FFFFFF"/></svg>';
        return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svg))}';
    }
  }
}

