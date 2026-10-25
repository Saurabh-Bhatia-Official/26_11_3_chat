import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupIconOption {
  final String id;
  final String name;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final String description;

  const GroupIconOption({
    required this.id,
    required this.name,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    required this.description,
  });

  String get preferenceKey => 'preset:$id';
}

class GroupIconHelper {
  static const String keyGroupIconPreference = 'saved_group_icon_preference';
  static const String keyGroupIconData = 'saved_group_icon_data';
  static const String defaultPresetId = 'community_guild';
  static const String defaultIconPreference = 'preset:$defaultPresetId';

  /// Curated preset group icons with vivid cyber & modern chat aesthetics
  static const List<GroupIconOption> presets = [
    GroupIconOption(
      id: 'community_guild',
      name: 'Community Guild',
      icon: Icons.groups_rounded,
      primaryColor: Color(0xFF10B981),
      secondaryColor: Color(0xFF059669),
      description: 'Connected community & collaboration',
    ),
    GroupIconOption(
      id: 'cyber_pulse',
      name: 'Cyber Pulse',
      icon: Icons.stream_rounded,
      primaryColor: Color(0xFF06B6D4),
      secondaryColor: Color(0xFF0284C7),
      description: 'Futuristic high-speed cyber channel',
    ),
    GroupIconOption(
      id: 'shield_guardian',
      name: 'Shield Guardian',
      icon: Icons.security_rounded,
      primaryColor: Color(0xFF8B5CF6),
      secondaryColor: Color(0xFF6D28D9),
      description: 'Maximum security & encrypted guild',
    ),
    GroupIconOption(
      id: 'nexus_hive',
      name: 'Nexus Hive',
      icon: Icons.hub_rounded,
      primaryColor: Color(0xFF14B8A6),
      secondaryColor: Color(0xFF0D9488),
      description: 'Decentralized interconnected network',
    ),
    GroupIconOption(
      id: 'phoenix_fire',
      name: 'Phoenix Fire',
      icon: Icons.local_fire_department_rounded,
      primaryColor: Color(0xFFF97316),
      secondaryColor: Color(0xFFEA580C),
      description: 'Dynamic power & blazing discussions',
    ),
    GroupIconOption(
      id: 'quantum_cube',
      name: 'Quantum Cube',
      icon: Icons.view_in_ar_rounded,
      primaryColor: Color(0xFF3B82F6),
      secondaryColor: Color(0xFF1D4ED8),
      description: 'Deep intelligence & modular space',
    ),
    GroupIconOption(
      id: 'pixel_gamepad',
      name: 'PlayTogether Guild',
      icon: Icons.sports_esports_rounded,
      primaryColor: Color(0xFFEC4899),
      secondaryColor: Color(0xFFDB2777),
      description: 'Multiplayer chess, ludo, and chat games',
    ),
    GroupIconOption(
      id: 'crypto_vault',
      name: 'Crypto Vault',
      icon: Icons.lock_rounded,
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFD97706),
      description: 'Private confidential discussions',
    ),
    GroupIconOption(
      id: 'team_rocket',
      name: 'Star Fleet',
      icon: Icons.rocket_launch_rounded,
      primaryColor: Color(0xFFEF4444),
      secondaryColor: Color(0xFFDC2626),
      description: 'Fast-moving projects & team missions',
    ),
    GroupIconOption(
      id: 'cosmic_orbit',
      name: 'Cosmic Orbit',
      icon: Icons.public_rounded,
      primaryColor: Color(0xFF6366F1),
      secondaryColor: Color(0xFF4338CA),
      description: 'Global reach & open community',
    ),
  ];

  /// Reactive notifier for the currently active default group icon
  static final ValueNotifier<String> persistentGroupIconNotifier =
      ValueNotifier<String>(defaultIconPreference);

  static String get currentGroupIcon => persistentGroupIconNotifier.value;

  /// Initialize and load persistent icon from storage on app launch
  static Future<String> initPersistentGroupIcon() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(keyGroupIconPreference);
      if (saved != null && saved.trim().isNotEmpty) {
        persistentGroupIconNotifier.value = saved.trim();
        return saved.trim();
      }
    } catch (_) {}
    persistentGroupIconNotifier.value = defaultIconPreference;
    return defaultIconPreference;
  }

  /// Permanently save chosen icon to persistent storage (presets or image data URI / URL)
  static Future<void> savePersistentGroupIcon(String iconValue) async {
    final clean = iconValue.trim();
    if (clean.isEmpty) return;

    persistentGroupIconNotifier.value = clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyGroupIconPreference, clean);
      if (isImageData(clean)) {
        await prefs.setString(keyGroupIconData, clean);
      } else {
        await prefs.remove(keyGroupIconData);
      }
    } catch (e) {
      debugPrint('Error saving persistent group icon: $e');
    }
  }

  /// Whether the string represents a preset icon (e.g. `preset:cyber_pulse` or `cyber_pulse`)
  static bool isPreset(String? iconOrUrl) {
    if (iconOrUrl == null || iconOrUrl.trim().isEmpty) return false;
    final clean = iconOrUrl.trim();
    if (clean.startsWith('data:image') || clean.startsWith('http://') || clean.startsWith('https://')) {
      return false;
    }
    if (clean.startsWith('preset:') || clean.startsWith('icon:')) return true;
    return presets.any((p) => p.id == clean);
  }

  /// Whether the string is an image data URI or URL
  static bool isImageData(String? iconOrUrl) {
    if (iconOrUrl == null || iconOrUrl.trim().isEmpty) return false;
    final clean = iconOrUrl.trim();
    return clean.startsWith('data:image') ||
        clean.startsWith('http://') ||
        clean.startsWith('https://');
  }

  /// Returns the corresponding GroupIconOption preset
  static GroupIconOption getPreset(String? iconOrPref) {
    if (iconOrPref == null || iconOrPref.trim().isEmpty) {
      return presets.firstWhere((p) => p.id == defaultPresetId);
    }
    var clean = iconOrPref.trim();
    if (clean.startsWith('preset:')) clean = clean.substring('preset:'.length);
    if (clean.startsWith('icon:')) clean = clean.substring('icon:'.length);

    return presets.firstWhere(
      (p) => p.id == clean,
      orElse: () => presets.firstWhere((p) => p.id == defaultPresetId),
    );
  }
}
