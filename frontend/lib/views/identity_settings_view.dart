import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/file_picker_helper.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/software_logo_widget.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/camera_capture_dialog.dart';
import '../services/permission_service.dart';
import '../services/app_branding/app_branding.dart';

class IdentitySettingsView extends StatefulWidget {
  final AppThemeMode currentThemeMode;
  final Function(AppThemeMode) onThemeChanged;
  final VoidCallback? onLogout;

  const IdentitySettingsView({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
    this.onLogout,
  });

  @override
  State<IdentitySettingsView> createState() => _IdentitySettingsViewState();
}

class _IdentitySettingsViewState extends State<IdentitySettingsView> {
  late final TextEditingController _softwareNameController;
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;
  late final TextEditingController _statusController;
  late final TextEditingController _avatarUrlController;

  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingSoftwareLogo = false;
  bool _isPrivate = false;
  Uint8List? _pickedAvatarBytes;
  String? _pickedAvatarFilename;
  String selectedIcon = 'whisper';

  // Section expansion state for organized navigation: Profile -> Settings
  String _activeSection = 'profile'; // 'profile', 'customization', 'privacy', 'notifications', 'chat', 'storage', 'about'

  // Additional settings state
  bool _notifySound = true;
  bool _notifyVibrate = true;
  bool _sendOnEnter = true;
  bool _autoDownloadMedia = true;
  String _chatFontSize = 'Normal';

  final List<Map<String, dynamic>> icons = AppIconHelper.options;

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
    _isPrivate = user.isPrivate;
    selectedIcon = user.appIconPreference.isNotEmpty ? user.appIconPreference : ApiService.currentAppIcon;
    _softwareNameController = TextEditingController(text: ApiService.softwareName);
    _nameController = TextEditingController(text: user.displayName);
    _usernameController = TextEditingController(text: user.username);
    _emailController = TextEditingController(text: user.email ?? '');
    _phoneController = TextEditingController(text: user.phone ?? '');
    _bioController = TextEditingController(text: user.bio);
    _statusController = TextEditingController(text: user.statusMessage);
    _avatarUrlController = TextEditingController(text: user.avatarUrl ?? '');
    ApiService.currentUserNotifier.addListener(_onUserChanged);
  }

  void _onUserChanged() {
    final user = ApiService.currentUserNotifier.value;
    if (user != null && mounted) {
      setState(() {
        _isPrivate = user.isPrivate;
        selectedIcon = user.appIconPreference.isNotEmpty ? user.appIconPreference : ApiService.currentAppIcon;
        _nameController.text = user.displayName;
        _usernameController.text = user.username;
        _emailController.text = user.email ?? '';
        _phoneController.text = user.phone ?? '';
        _bioController.text = user.bio;
        _statusController.text = user.statusMessage;
        _avatarUrlController.text = user.avatarUrl ?? '';
      });
    }
  }

  @override
  void dispose() {
    ApiService.currentUserNotifier.removeListener(_onUserChanged);
    _softwareNameController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _statusController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  ImageProvider? _getAvatarImageProvider() {
    if (_pickedAvatarBytes != null) {
      return MemoryImage(_pickedAvatarBytes!);
    }
    final url = _avatarUrlController.text.trim();
    if (url.isNotEmpty) {
      if (url.startsWith('data:image')) {
        try {
          final commaIdx = url.indexOf(',');
          final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
          return MemoryImage(base64Decode(base64Str));
        } catch (_) {}
      } else {
        return NetworkImage(url);
      }
    }
    return null;
  }

  void _pickAvatarFromDevice() {
    _showAvatarSourcePicker();
  }

  void _showAvatarSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              const Row(
                children: [
                  Icon(Icons.add_a_photo, color: Color(0xFF06B6D4), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Update Profile Picture',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose how you would like to select or capture your profile photo:',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
              const SizedBox(height: 18),

              // Source 1: Device Camera
              _buildAvatarOptionTile(
                icon: Icons.photo_camera,
                color: const Color(0xFF06B6D4),
                title: 'Take Photo with Camera',
                subtitle: 'Capture a picture using your camera with preview & retake',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _captureAvatarCamera();
                },
              ),
              const SizedBox(height: 10),

              // Source 2: Photo Gallery
              _buildAvatarOptionTile(
                icon: Icons.photo_library,
                color: const Color(0xFF10B981),
                title: 'Choose from Gallery',
                subtitle: 'Select an image from device gallery or photos',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAvatarFromGallery();
                },
              ),
              const SizedBox(height: 10),

              // Source 3: File Storage
              _buildAvatarOptionTile(
                icon: Icons.folder_open,
                color: const Color(0xFF8B5CF6),
                title: 'Choose from File Storage',
                subtitle: 'Browse your device file system for an image',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickAvatarFromFileStorage();
                },
              ),
              const SizedBox(height: 10),

              // Source 4: Image URL
              _buildAvatarOptionTile(
                icon: Icons.link,
                color: const Color(0xFFF59E0B),
                title: 'Enter Image URL',
                subtitle: 'Provide a direct HTTPS link to an image',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _editAvatarUrlDirectly();
                },
              ),

              if (_avatarUrlController.text.isNotEmpty || _pickedAvatarBytes != null) ...[
                const SizedBox(height: 10),
                _buildAvatarOptionTile(
                  icon: Icons.delete_outline,
                  color: const Color(0xFFEF4444),
                  title: 'Remove Photo',
                  subtitle: 'Clear custom picture and restore default initials',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _removeAvatar();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarOptionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
          ],
        ),
      ),
    );
  }

  void _captureAvatarCamera() async {
    final result = await CameraCaptureHelper.captureWithCamera(
      context,
      onFallbackGallery: _pickAvatarFromGallery,
    );
    if (result != null && mounted) {
      await _uploadAndApplyAvatar(result.bytes, result.filename);
    }
  }

  void _pickAvatarFromGallery() async {
    final hasPerm = await PermissionService.requestPermission(
      context,
      AppPermissionType.photos,
      showRationale: true,
    );
    if (!hasPerm) return;

    try {
      final picked = await FilePickerHelper.pickImage();
      if (picked != null && picked.bytes.isNotEmpty && mounted) {
        await _uploadAndApplyAvatar(picked.bytes, picked.name);
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick photo from gallery: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _pickAvatarFromFileStorage() async {
    final hasPerm = await PermissionService.requestPermission(
      context,
      AppPermissionType.photos,
      showRationale: true,
    );
    if (!hasPerm) return;

    try {
      final picked = await FilePickerHelper.pickDocument(
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
      );
      if (picked != null && picked.bytes.isNotEmpty && mounted) {
        await _uploadAndApplyAvatar(picked.bytes, picked.name);
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image file: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _editAvatarUrlDirectly() {
    final controller = TextEditingController(text: _avatarUrlController.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Enter Image URL', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://images.unsplash.com/...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4), foregroundColor: Colors.white),
            onPressed: () async {
              final newUrl = controller.text.trim();
              Navigator.of(ctx).pop();
              if (newUrl.isNotEmpty) {
                setState(() {
                  _avatarUrlController.text = newUrl;
                  _pickedAvatarBytes = null;
                });
                await ApiService.updateProfile(avatarUrl: newUrl);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAndApplyAvatar(Uint8List bytes, String filename) async {
    setState(() {
      _pickedAvatarBytes = bytes;
      _pickedAvatarFilename = filename;
      _isUploadingAvatar = true;
    });

    String? uploadedUrl;
    try {
      uploadedUrl = await ApiService.uploadMedia(bytes, filename);
    } catch (e) {
      debugPrint('Cloud media upload error, using local fallback data URI: $e');
    }

    final ext = filename.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    final effectiveUrl = (uploadedUrl != null && uploadedUrl.isNotEmpty)
        ? uploadedUrl
        : 'data:image/$ext;base64,${base64Encode(bytes)}';

    _avatarUrlController.text = effectiveUrl;
    await ApiService.updateProfile(avatarUrl: effectiveUrl);

    if (mounted) {
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Profile picture updated successfully ($filename)!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _removeAvatar() async {
    setState(() {
      _pickedAvatarBytes = null;
      _pickedAvatarFilename = null;
      _avatarUrlController.clear();
      _isUploadingAvatar = true;
    });

    await ApiService.updateProfile(avatarUrl: '');
    if (mounted) {
      setState(() => _isUploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Avatar removed. Initials will be used.'),
          backgroundColor: Color(0xFF06B6D4),
        ),
      );
    }
  }

  void _selectAppIcon(Map<String, dynamic> item) async {
    final iconId = item['id'] as String;
    setState(() => selectedIcon = iconId);
    await ApiService.setAppIcon(iconId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1500),
          backgroundColor: item['color'] as Color,
          content: Row(
            children: [
              Icon(item['icon'] as IconData, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('Application icon updated to ${item['name']}!'),
            ],
          ),
        ),
      );
    }
  }

  void _pickCustomSoftwareLogo() async {
    final hasPerm = await PermissionService.requestPermission(
      context,
      AppPermissionType.photos,
      showRationale: true,
    );
    if (!hasPerm) return;

    try {
      final picked = await FilePickerHelper.pickDocument(
        allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'webp', 'ico'],
      );

      if (picked == null || picked.bytes.isEmpty) return;

      if (picked.bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logo file is too large. Maximum supported size is 5MB.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      setState(() => _isUploadingSoftwareLogo = true);

      final bytes = picked.bytes;
      final ext = picked.extension ?? 'png';
      final mime = ext == 'svg'
          ? 'image/svg+xml'
          : (ext == 'ico' ? 'image/x-icon' : 'image/$ext');
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

      // Apply locally
      await ApiService.setCustomLogo(dataUrl);

      // Upload to media storage
      try {
        final uploadedUrl = await ApiService.uploadMedia(bytes, picked.name);
        if (uploadedUrl != null && !uploadedUrl.startsWith('data:')) {
          await ApiService.setCustomLogo(uploadedUrl);
        }
      } catch (e) {
        debugPrint('Cloud media upload notice: $e');
      }

      if (mounted) {
        setState(() => _isUploadingSoftwareLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Custom application logo updated (${picked.name})!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingSoftwareLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting logo file: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _removeCustomSoftwareLogo() async {
    await ApiService.resetCustomLogo();
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Custom logo removed. Default application icon restored.'),
          backgroundColor: Color(0xFF06B6D4),
        ),
      );
    }
  }

  void _saveSoftwareName() async {
    final newName = _softwareNameController.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application title cannot be empty.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    await ApiService.setSoftwareName(newName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Application title updated to "$newName"!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  void _resetSoftwareNameToDefault() async {
    _softwareNameController.text = ApiService.defaultSoftwareName;
    await ApiService.setSoftwareName(ApiService.defaultSoftwareName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Application title reset to default (Whisper).'),
          backgroundColor: Color(0xFF06B6D4),
        ),
      );
    }
  }

  void _resetAllCustomizationToDefault() async {
    _softwareNameController.text = ApiService.defaultSoftwareName;
    await ApiService.setSoftwareName(ApiService.defaultSoftwareName);
    await ApiService.resetCustomLogo();
    await ApiService.setAppIcon(ApiService.defaultAppIcon);
    await AppTheme.setTheme(AppThemeMode.obsidianCyber);
    widget.onThemeChanged(AppThemeMode.obsidianCyber);
    setState(() {
      selectedIcon = ApiService.defaultAppIcon;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.refresh, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('All app customizations reset to defaults!'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _setPrivacyMode(bool isPrivate) async {
    setState(() => _isPrivate = isPrivate);
    await ApiService.setPrivacyMode(isPrivate);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 2000),
          backgroundColor: isPrivate ? const Color(0xFFFBBF24) : const Color(0xFF10B981),
          content: Row(
            children: [
              Icon(isPrivate ? Icons.lock : Icons.public, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPrivate
                      ? 'Account converted to Private Account! Confirmation required before other users can chat with you.'
                      : 'Account converted to Public Account! Open direct messaging enabled.',
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _saveProfile() async {
    setState(() => _isSaving = true);

    await ApiService.setSoftwareName(_softwareNameController.text.trim());

    await ApiService.updateProfile(
      displayName: _nameController.text.trim(),
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      bio: _bioController.text.trim(),
      avatarUrl: _avatarUrlController.text.trim(),
      statusMessage: _statusController.text.trim(),
      appIconPreference: selectedIcon,
      themePreference: widget.currentThemeMode.name,
      softwareName: _softwareNameController.text.trim(),
      customLogoUrl: ApiService.customLogoData,
      isPrivate: _isPrivate,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Profile and settings saved successfully!')),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('Confirm Sign Out', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out? Your saved credentials and active session will be securely cleared.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sign Out'),
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.onLogout != null) {
                widget.onLogout!();
              } else {
                ApiService.logout();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 720;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 24,
        vertical: 18,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Navigation Breadcrumb Header: Profile -> Settings
          _buildProfileBreadcrumbHeader(user),
          const SizedBox(height: 16),

          // User Profile Overview Card
          _buildUserProfileHeaderCard(user),
          const SizedBox(height: 20),

          // Settings Section Navigation Tabs / Pills
          _buildSettingsNavigationPills(),
          const SizedBox(height: 20),

          // Dynamic Active Settings Section Content
          if (_activeSection == 'profile') _buildAccountAndProfileSection(),
          if (_activeSection == 'customization') _buildAppCustomizationSection(),
          if (_activeSection == 'privacy') _buildPrivacyAndSecuritySection(),
          if (_activeSection == 'notifications') _buildNotificationsSection(),
          if (_activeSection == 'chat') _buildChatSettingsSection(),
          if (_activeSection == 'storage') _buildStorageAndDataSection(),
          if (_activeSection == 'about') _buildAboutAndAppInfoSection(),

          const SizedBox(height: 24),
          // Logout Option Tile
          _buildLogoutCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileBreadcrumbHeader(UserModel user) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person, color: Color(0xFF06B6D4), size: 20),
        ),
        const SizedBox(width: 10),
        const Text(
          'Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white70),
        ),
        const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
        const Text(
          'Settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildUserProfileHeaderCard(UserModel user) {
    return GlassContainer(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                backgroundImage: _getAvatarImageProvider(),
                child: _getAvatarImageProvider() == null
                    ? Text(
                        user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _pickAvatarFromDevice,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield, color: Color(0xFF10B981), size: 11),
                          const SizedBox(width: 3),
                          Text(
                            '${user.safetyScore}%',
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  user.statusMessage.isNotEmpty ? user.statusMessage : 'Available',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsNavigationPills() {
    final sections = [
      {'id': 'profile', 'label': 'Account & Profile', 'icon': Icons.person_outline},
      {'id': 'customization', 'label': 'App Customization', 'icon': Icons.palette_outlined},
      {'id': 'privacy', 'label': 'Privacy & Security', 'icon': Icons.lock_outline},
      {'id': 'notifications', 'label': 'Notifications', 'icon': Icons.notifications_outlined},
      {'id': 'chat', 'label': 'Chat Settings', 'icon': Icons.chat_outlined},
      {'id': 'storage', 'label': 'Storage & Data', 'icon': Icons.storage_outlined},
      {'id': 'about', 'label': 'About & App Info', 'icon': Icons.info_outline},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sections.map((sec) {
          final isSelected = _activeSection == sec['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _activeSection = sec['id'] as String),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF06B6D4).withValues(alpha: 0.2) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF06B6D4) : Colors.white10,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      sec['icon'] as IconData,
                      color: isSelected ? const Color(0xFF06B6D4) : Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      sec['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ==========================================
  // SECTION 1: ACCOUNT AND PROFILE
  // ==========================================
  Widget _buildAccountAndProfileSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.manage_accounts, color: Color(0xFF06B6D4), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Account and Profile',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
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
          const SizedBox(height: 18),

          // Profile Picture Editor with Device File Picker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 450;
                final avatarWidget = Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF06B6D4), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 44,
                        backgroundColor: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                        backgroundImage: _getAvatarImageProvider(),
                        child: _getAvatarImageProvider() == null
                            ? Text(
                                _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : '?',
                                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4)),
                              )
                            : null,
                      ),
                    ),
                    if (_isUploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                          ),
                        ),
                      ),
                  ],
                );

                final detailsWidget = Column(
                  crossAxisAlignment: isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile Picture & Avatar',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _pickedAvatarFilename != null
                          ? 'Selected: $_pickedAvatarFilename'
                          : (_avatarUrlController.text.isNotEmpty
                              ? 'Custom avatar active'
                              : 'No custom avatar. Displaying initials.'),
                      style: TextStyle(
                        color: _avatarUrlController.text.isNotEmpty || _pickedAvatarBytes != null
                            ? const Color(0xFF10B981)
                            : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Upload a photo from your computer or phone',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: isNarrow ? WrapAlignment.center : WrapAlignment.start,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.file_upload_outlined, size: 17),
                          label: Text(
                            _avatarUrlController.text.isNotEmpty || _pickedAvatarBytes != null
                                ? 'Change Avatar'
                                : 'Upload from Device',
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isUploadingAvatar ? null : _pickAvatarFromDevice,
                        ),
                        if (_avatarUrlController.text.isNotEmpty || _pickedAvatarBytes != null)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFEF4444),
                              side: const BorderSide(color: Color(0xFFEF4444)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                            label: const Text('Remove', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                            onPressed: _isUploadingAvatar ? null : _removeAvatar,
                          ),
                      ],
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      avatarWidget,
                      const SizedBox(height: 14),
                      detailsWidget,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    avatarWidget,
                    const SizedBox(width: 20),
                    Expanded(child: detailsWidget),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 18),

          // Fields: Display Name & Username
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.badge, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _usernameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Username (@handle)',
              prefixIcon: Icon(Icons.alternate_email, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 14),

          // Email & Phone
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixIcon: Icon(Icons.phone_outlined, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 14),

          // Status message & Presets
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

          // Bio
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
          const SizedBox(height: 20),

          // Save Profile Button
          SizedBox(
            width: double.infinity,
            height: 48,
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: _isSaving ? null : _saveProfile,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 2: APP CUSTOMIZATION
  // ==========================================
  Widget _buildAppCustomizationSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.palette, color: Color(0xFF8B5CF6), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Customization',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'App Icon, Title, Color Theme & Appearance Preferences',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Live In-App & Launcher Branding Preview Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0F1D),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.preview_outlined, size: 14, color: Colors.white38),
                    SizedBox(width: 6),
                    Text(
                      'LIVE IN-APP BRANDING PREVIEW',
                      style: TextStyle(fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SoftwareLogoWidget(size: 24, iconSize: 14, borderRadius: 6, showShadow: false),
                      const SizedBox(width: 10),
                      ValueListenableBuilder<String>(
                        valueListenable: ApiService.softwareNameNotifier,
                        builder: (context, name, _) {
                          return Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Active', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- 1. APPLICATION TITLE CUSTOMIZATION ---
          const Row(
            children: [
              Icon(Icons.title, color: Color(0xFF06B6D4), size: 18),
              SizedBox(width: 8),
              Text(
                'Application Title',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure the title displayed in headers, navigation, dialogs, and platform branding:',
            style: TextStyle(color: Colors.white60, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _softwareNameController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Enter application title...',
                    prefixIcon: const Icon(Icons.edit_note, color: Color(0xFF06B6D4)),
                    filled: true,
                    fillColor: const Color(0xFF131D2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white12)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF06B6D4))),
                  ),
                  onSubmitted: (_) => _saveSoftwareName(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Apply Name'),
                onPressed: _saveSoftwareName,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Reset to Default'),
                onPressed: _resetSoftwareNameToDefault,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- 2. APPLICATION ICON CUSTOMIZATION ---
          const Row(
            children: [
              Icon(Icons.image_outlined, color: Color(0xFF06B6D4), size: 18),
              SizedBox(width: 8),
              Text(
                'Application Icon',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select a preset icon (updates in-app logo, web favicon, and Android native launcher icon via activity-alias):',
            style: TextStyle(color: Colors.white60, fontSize: 11.5),
          ),
          const SizedBox(height: 12),

          // Preset Icons Grid
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: icons.map((item) {
              final isSelected = selectedIcon == item['id'] && ApiService.customLogoData == null;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  await ApiService.resetCustomLogo();
                  _selectAppIcon(item);
                },
                child: Container(
                  width: 135,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF1E293B) : Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF06B6D4) : Colors.white10,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      item['id'] == 'whisper'
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/branding/whisper_logo.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            )
                          : CircleAvatar(
                              radius: 20,
                              backgroundColor: (item['color'] as Color).withValues(alpha: 0.2),
                              child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 22),
                            ),
                      const SizedBox(height: 6),
                      Text(
                        item['name'],
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 3),
                        const Icon(Icons.check_circle, color: Color(0xFF06B6D4), size: 14),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Upload custom logo button
          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isUploadingSoftwareLogo
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_upload_outlined, size: 16),
                label: Text(_isUploadingSoftwareLogo ? 'Uploading...' : 'Pick from Device (File Picker)'),
                onPressed: _isUploadingSoftwareLogo ? null : _pickCustomSoftwareLogo,
              ),
              if (ApiService.customLogoData != null) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('Reset to Preset Icon'),
                  onPressed: _removeCustomSoftwareLogo,
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // --- 3. COLOR THEME & APPEARANCE ---
          const Row(
            children: [
              Icon(Icons.color_lens_outlined, color: Color(0xFF06B6D4), size: 18),
              SizedBox(width: 8),
              Text(
                'Color Theme & Appearance',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Select from curated palettes with consistent light & dark modes:',
            style: TextStyle(color: Colors.white60, fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildThemeCard(
                title: 'Obsidian Cyber',
                mode: AppThemeMode.obsidianCyber,
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
          const SizedBox(height: 24),

          // --- 4. CHAT APPEARANCE PREFERENCES ---
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: Color(0xFF06B6D4), size: 18),
              SizedBox(width: 8),
              Text(
                'Chat Appearance',
                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Font Size:', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 12),
              ...['Compact', 'Normal', 'Large'].map((size) {
                final isSelected = _chatFontSize == size;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(size, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.white70)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF06B6D4),
                    backgroundColor: const Color(0xFF1E293B),
                    onSelected: (val) {
                      if (val) setState(() => _chatFontSize = size);
                    },
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),

          // --- 5. RESET CUSTOMIZATION TO DEFAULTS ---
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.settings_backup_restore, color: Color(0xFFF59E0B), size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reset Customization to Defaults',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Restores title to "Whisper", default icon, and Obsidian Cyber theme',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: const Color(0xFFF59E0B),
                    side: const BorderSide(color: Color(0xFFF59E0B)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _resetAllCustomizationToDefault,
                  child: const Text('Reset All', style: TextStyle(fontSize: 12)),
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
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        widget.onThemeChanged(mode);
        ApiService.setThemeMode(mode);
      },
      child: Container(
        width: 135,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: primary.withValues(alpha: 0.5)),
              ),
              child: Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
            ),
            if (isSelected) ...[
              const SizedBox(height: 2),
              Icon(Icons.check, color: primary, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // SECTION 3: PRIVACY AND SECURITY
  // ==========================================
  Widget _buildPrivacyAndSecuritySection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 22),
              SizedBox(width: 10),
              Text(
                'Privacy and Security',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Account Privacy Setting (Public vs Private Mode)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isPrivate ? Icons.lock : Icons.public,
                      color: _isPrivate ? const Color(0xFFFBBF24) : const Color(0xFF10B981),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Account Privacy Mode',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (_isPrivate ? const Color(0xFFFBBF24) : const Color(0xFF10B981)).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: (_isPrivate ? const Color(0xFFFBBF24) : const Color(0xFF10B981)).withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            _isPrivate ? 'PRIVATE' : 'PUBLIC',
                            style: TextStyle(
                              color: _isPrivate ? const Color(0xFFFBBF24) : const Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _isPrivate,
                          activeColor: const Color(0xFFFBBF24),
                          activeTrackColor: const Color(0xFFFBBF24).withOpacity(0.35),
                          inactiveThumbColor: const Color(0xFF10B981),
                          inactiveTrackColor: const Color(0xFF10B981).withOpacity(0.35),
                          onChanged: (val) => _setPrivacyMode(val),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isPrivate
                      ? 'Private Account: Other users must complete a confirmation prompt ("Do you know this person?") before messaging you.'
                      : 'Public Account: Any user can search for your username and start chatting directly without requiring prior confirmation.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _setPrivacyMode(false),
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: !_isPrivate ? const Color(0xFF10B981).withOpacity(0.15) : Colors.black12,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: !_isPrivate ? const Color(0xFF10B981) : Colors.white10,
                                  width: !_isPrivate ? 2 : 1,
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.public, color: Color(0xFF10B981), size: 22),
                                  SizedBox(height: 6),
                                  Text('Public Account', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 2),
                                  Text('Open Messaging', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                ],
                              ),
                            ),
                            if (!_isPrivate)
                              const Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _setPrivacyMode(true),
                        child: Stack(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isPrivate ? const Color(0xFFFBBF24).withOpacity(0.15) : Colors.black12,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _isPrivate ? const Color(0xFFFBBF24) : Colors.white10,
                                  width: _isPrivate ? 2 : 1,
                                ),
                              ),
                              child: const Column(
                                children: [
                                  Icon(Icons.lock, color: Color(0xFFFBBF24), size: 22),
                                  SizedBox(height: 6),
                                  Text('Private Account', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 2),
                                  Text('Confirm First', style: TextStyle(color: Colors.white54, fontSize: 10)),
                                ],
                              ),
                            ),
                            if (_isPrivate)
                              const Positioned(
                                top: 6,
                                right: 6,
                                child: Icon(Icons.check_circle, color: Color(0xFFFBBF24), size: 16),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security Audit Badge
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Smart Safety Guardian Active',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Your safety score is ${ApiService.currentUser.safetyScore}%. Link protection and phishing interception are active.',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 4: NOTIFICATIONS
  // ==========================================
  Widget _buildNotificationsSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_outlined, color: Color(0xFF06B6D4), size: 22),
              SizedBox(width: 10),
              Text(
                'Notifications',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Sound Alerts', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Play sound for new incoming messages', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _notifySound,
            activeColor: const Color(0xFF06B6D4),
            onChanged: (val) => setState(() => _notifySound = val),
          ),
          const Divider(color: Colors.white12),
          SwitchListTile(
            title: const Text('Vibration', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Vibrate on incoming messages and calls', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _notifyVibrate,
            activeColor: const Color(0xFF06B6D4),
            onChanged: (val) => setState(() => _notifyVibrate = val),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 5: CHAT SETTINGS
  // ==========================================
  Widget _buildChatSettingsSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.chat_bubble_outline, color: Color(0xFF06B6D4), size: 22),
              SizedBox(width: 10),
              Text(
                'Chat Settings',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Send on Enter', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Press Enter key to quickly send messages', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _sendOnEnter,
            activeColor: const Color(0xFF06B6D4),
            onChanged: (val) => setState(() => _sendOnEnter = val),
          ),
          const Divider(color: Colors.white12),
          SwitchListTile(
            title: const Text('Auto-Download Media', style: TextStyle(color: Colors.white, fontSize: 14)),
            subtitle: const Text('Automatically load photos and voice messages', style: TextStyle(color: Colors.white54, fontSize: 11)),
            value: _autoDownloadMedia,
            activeColor: const Color(0xFF06B6D4),
            onChanged: (val) => setState(() => _autoDownloadMedia = val),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 6: STORAGE AND DATA
  // ==========================================
  Widget _buildStorageAndDataSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storage_outlined, color: Color(0xFF06B6D4), size: 22),
              SizedBox(width: 10),
              Text(
                'Storage and Data',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cached, color: Color(0xFF10B981), size: 22),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Temporary Cache', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      Text('Clear locally cached images and media files', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: const Color(0xFF06B6D4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache cleared successfully!'), backgroundColor: Color(0xFF10B981)),
                    );
                  },
                  child: const Text('Clear Cache', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 7: ABOUT AND APP INFORMATION
  // ==========================================
  Widget _buildAboutAndAppInfoSection() {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SoftwareLogoWidget(size: 32, iconSize: 18, borderRadius: 8, showShadow: false),
              const SizedBox(width: 12),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: ApiService.softwareNameNotifier,
                  builder: (context, name, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Next-Gen Cross-Platform Secure Chat Application',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: Colors.white12),
          _buildInfoRow('Version', '1.0.0+1 (Production Release)'),
          _buildInfoRow('Architecture', 'Spring Boot 3 + Flutter Multiplatform'),
          _buildInfoRow('Protocol', 'WebSocket / WebRTC End-to-End Signaling'),
          _buildInfoRow('Database', 'PostgreSQL / Cloudinary Media Storage'),
          _buildInfoRow('License', 'Confidential & Proprietary'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ==========================================
  // SECTION 8: LOGOUT
  // ==========================================
  Widget _buildLogoutCard() {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: _confirmLogout,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 10),
            Text(
              'Sign Out / Logout',
              style: TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
