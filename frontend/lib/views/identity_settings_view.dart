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
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;
  late final TextEditingController _statusController;
  late final TextEditingController _avatarUrlController;

  bool _isSaving = false;
  String selectedIcon = 'neon_pulse';

  final List<String> _avatarPresets = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=300',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=300',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=300',
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=300',
    'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=300',
  ];

  final List<String> _quickStatusList = [
    'Available',
    'Coding 💻',
    'In a match ♟️',
    'Busy ⛔',
    'On Mobile 📱',
    'Shields up! 🛡️',
  ];

  @override
  void initState() {
    super.initState();
    final user = ApiService.currentUser;
    _nameController = TextEditingController(text: user.displayName);
    _usernameController = TextEditingController(text: user.username);
    _emailController = TextEditingController(text: user.email ?? '');
    _phoneController = TextEditingController(text: user.phone ?? '');
    _bioController = TextEditingController(text: user.bio);
    _statusController = TextEditingController(text: user.statusMessage);
    _avatarUrlController = TextEditingController(text: user.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _statusController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    setState(() => _isSaving = true);

    await ApiService.updateProfile(
      displayName: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      bio: _bioController.text.trim(),
      avatarUrl: _avatarUrlController.text.trim(),
      statusMessage: _statusController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile & Identity updated and saved successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dynamic App Identity',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Personalize theme, launcher icon, display identity, and chat style',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                    ),
                  ],
                ),
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

          // Complete Profile & Identity Settings (Edit Everything)
          GlassContainer(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.manage_accounts, color: Color(0xFF06B6D4), size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Full Profile Settings & Personalization',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield, color: Color(0xFF10B981), size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Safety Score: ${ApiService.currentUser.safetyScore}%',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. Profile Photo / Avatar Editor
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                      backgroundImage: _avatarUrlController.text.isNotEmpty
                          ? NetworkImage(_avatarUrlController.text)
                          : null,
                      child: _avatarUrlController.text.isEmpty
                          ? Text(
                              _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                            )
                          : null,
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Profile Photo URL', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _avatarUrlController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Paste custom photo or Cloudinary URL',
                              prefixIcon: const Icon(Icons.photo_camera, color: Colors.white54, size: 18),
                              suffixIcon: _avatarUrlController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: Colors.white38),
                                      onPressed: () {
                                        _avatarUrlController.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Or select an instant avatar preset:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: _avatarPresets.map((preset) {
                    final isCurrent = _avatarUrlController.text == preset;
                    return GestureDetector(
                      onTap: () {
                        _avatarUrlController.text = preset;
                        setState(() {});
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCurrent ? const Color(0xFF06B6D4) : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundImage: NetworkImage(preset),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const Divider(height: 36, color: Colors.white12),

                // 2. Personal & Account Details
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 650;
                    final displayNameField = TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: Icon(Icons.badge, color: Colors.white70),
                      ),
                    );

                    final usernameField = TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Username (@handle)',
                        prefixIcon: Icon(Icons.alternate_email, color: Colors.white70),
                      ),
                    );

                    if (isCompact) {
                      return Column(
                        children: [
                          displayNameField,
                          const SizedBox(height: 14),
                          usernameField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: displayNameField),
                        const SizedBox(width: 16),
                        Expanded(child: usernameField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 3. Contact Info (Email & Phone)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 650;
                    final emailField = TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined, color: Colors.white70),
                      ),
                    );

                    final phoneField = TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined, color: Colors.white70),
                      ),
                    );

                    if (isCompact) {
                      return Column(
                        children: [
                          emailField,
                          const SizedBox(height: 14),
                          phoneField,
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: emailField),
                        const SizedBox(width: 16),
                        Expanded(child: phoneField),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),

                // 4. Status Message & Presets
                TextField(
                  controller: _statusController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Status Message',
                    prefixIcon: Icon(Icons.edit_note, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _quickStatusList.map((st) {
                    final isSelected = _statusController.text == st;
                    return ActionChip(
                      label: Text(st, style: TextStyle(fontSize: 11, color: isSelected ? const Color(0xFF06B6D4) : Colors.white70)),
                      backgroundColor: isSelected ? const Color(0xFF06B6D4).withValues(alpha: 0.2) : const Color(0xFF1E293B),
                      side: BorderSide(color: isSelected ? const Color(0xFF06B6D4) : Colors.white12),
                      onPressed: () {
                        _statusController.text = st;
                        setState(() {});
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 5. Bio / About Me
                TextField(
                  controller: _bioController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Bio & About You',
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.info_outline, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 24),

                // Save All Profile Settings Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'Saving Changes...' : 'Save All Profile Settings',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: _isSaving ? null : _saveProfile,
                  ),
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
