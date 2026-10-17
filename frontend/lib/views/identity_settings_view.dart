import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';

class IdentitySettingsView extends StatefulWidget {
  final AppThemeMode currentThemeMode;
  final Function(AppThemeMode) onThemeChanged;

  const IdentitySettingsView({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
  });

  @override
  State<IdentitySettingsView> createState() => _IdentitySettingsViewState();
}

class _IdentitySettingsViewState extends State<IdentitySettingsView> {
  final TextEditingController _nameController =
      TextEditingController(text: ApiService.currentUser.displayName);
  final TextEditingController _statusController =
      TextEditingController(text: ApiService.currentUser.statusMessage);
  String selectedIcon = 'neon_pulse';

  final List<Map<String, dynamic>> icons = [
    {
      'id': 'neon_pulse',
      'name': 'Neon Pulse',
      'icon': Icons.bolt,
      'color': const Color(0xFF06B6D4)
    },
    {
      'id': 'stealth_slate',
      'name': 'Stealth Slate',
      'icon': Icons.security,
      'color': const Color(0xFF94A3B8)
    },
    {
      'id': 'emerald_spark',
      'name': 'Emerald Spark',
      'icon': Icons.auto_awesome,
      'color': const Color(0xFF10B981)
    },
    {
      'id': 'royal_crest',
      'name': 'Royal Crest',
      'icon': Icons.shield,
      'color': const Color(0xFF3B82F6)
    },
  ];

  void _saveProfile() {
    setState(() {
      ApiService.currentUser = UserModel(
        id: ApiService.currentUser.id,
        username: ApiService.currentUser.username,
        displayName: _nameController.text.trim(),
        email: ApiService.currentUser.email,
        avatarUrl: ApiService.currentUser.avatarUrl,
        bio: ApiService.currentUser.bio,
        statusMessage: _statusController.text.trim(),
        safetyScore: ApiService.currentUser.safetyScore,
        isVerified: ApiService.currentUser.isVerified,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('App Identity & Profile updated successfully!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.palette, color: Color(0xFF8B5CF6), size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Dynamic App Identity',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Personalize theme, launcher icon, display identity, and chat style',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Theme Switcher Section
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Color Theme & Appearance',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select from curated, high-contrast, accessible palettes:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildThemeCard(
                      title: 'Obsidian Neon',
                      mode: AppThemeMode.obsidianNeon,
                      primary: const Color(0xFF06B6D4),
                      bg: const Color(0xFF090D16),
                    ),
                    _buildThemeCard(
                      title: 'Royal Sapphire',
                      mode: AppThemeMode.royalSapphire,
                      primary: const Color(0xFF3B82F6),
                      bg: const Color(0xFF0F172A),
                    ),
                    _buildThemeCard(
                      title: 'Emerald Mint',
                      mode: AppThemeMode.emeraldMint,
                      primary: const Color(0xFF10B981),
                      bg: const Color(0xFF062820),
                    ),
                    _buildThemeCard(
                      title: 'Minimalist Light',
                      mode: AppThemeMode.minimalLight,
                      primary: const Color(0xFF2563EB),
                      bg: const Color(0xFFF1F5F9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Launcher Icon Selector Section
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Approved Launcher Icon Choices',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Choose an icon for supported platforms without altering signed package IDs:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: icons.map((item) {
                    final isSelected = selectedIcon == item['id'];
                    return InkWell(
                      onTap: () => setState(() => selectedIcon = item['id']),
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF1E293B) : Colors.black26,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF06B6D4) : Colors.white10,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: (item['color'] as Color).withOpacity(0.2),
                              child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 28),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              item['name'],
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // In-App Display Identity Customizer
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'In-App Display Name & Status',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _statusController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Status Message',
                    prefixIcon: Icon(Icons.edit_note, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF06B6D4),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Personalization'),
                  onPressed: _saveProfile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeCard({
    required String title,
    required AppThemeMode mode,
    required Color primary,
    required Color bg,
  }) {
    final isSelected = widget.currentThemeMode == mode;

    return InkWell(
      onTap: () => widget.onThemeChanged(mode),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? primary : Colors.white10,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 8)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                ),
                const Spacer(),
                if (isSelected) Icon(Icons.check_circle, color: primary, size: 16),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: mode == AppThemeMode.minimalLight ? Colors.black87 : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
