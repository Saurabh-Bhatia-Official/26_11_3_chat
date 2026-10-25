import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/software_logo_widget.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/camera_capture_dialog.dart';
import '../widgets/group_icon_picker_modal.dart';
import '../services/group_icon_helper.dart';
import '../services/permission_service.dart';
import 'package:image_picker/image_picker.dart';

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
  String selectedIcon = 'cyber_pulse';

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

  void _pickAvatarFromDevice() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );

      if (file == null) return;

      final extension = file.extension?.toLowerCase() ?? '';
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select an image in JPG, PNG, or WEBP format.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the selected image data.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      setState(() {
        _pickedAvatarBytes = bytes;
        _pickedAvatarFilename = file.name;
        _isUploadingAvatar = true;
      });

      // Upload and update user profile immediately
      final uploadedUrl = await ApiService.uploadMedia(bytes, file.name);
      if (uploadedUrl != null) {
        _avatarUrlController.text = uploadedUrl;
        await ApiService.updateProfile(avatarUrl: uploadedUrl);
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text('Avatar uploaded and updated successfully (${file.name})!'),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick or upload avatar: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
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
              Text('Active software & home icon updated to ${item['name']}!'),
            ],
          ),
        ),
      );
    }
  }

  void _pickCustomSoftwareLogo() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'svg', 'webp', 'ico'],
      );

      if (file == null) return;

      setState(() => _isUploadingSoftwareLogo = true);

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (mounted) {
          setState(() => _isUploadingSoftwareLogo = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not read the selected image file.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      final ext = file.extension?.toLowerCase() ?? 'png';
      final mime = ext == 'svg'
          ? 'image/svg+xml'
          : (ext == 'ico' ? 'image/x-icon' : 'image/$ext');
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

      // Immediate local UI response
      await ApiService.setCustomLogo(dataUrl);

      // Upload to cloud media storage and persist cloud URL to cloud database
      final uploadedUrl = await ApiService.uploadMedia(bytes, file.name);
      if (uploadedUrl != null && !uploadedUrl.startsWith('data:')) {
        await ApiService.setCustomLogo(uploadedUrl);
      }

      if (mounted) {
        setState(() => _isUploadingSoftwareLogo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cloud_done, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Software logo & system favicon updated & saved to cloud (${file.name})!'),
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
          content: Text('Custom logo removed. Preset system icon restored.'),
          backgroundColor: Color(0xFF06B6D4),
        ),
      );
    }
  }

  void _captureGroupIconCamera() async {
    final result = await CameraCaptureHelper.captureWithCamera(
      context,
      onFallbackGallery: _pickGroupIconGallery,
    );
    if (result != null && mounted) {
      await ApiService.setPersistentGroupIcon(result.dataUri);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera photo saved permanently as default group icon!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  void _pickGroupIconGallery() async {
    final hasPerm = await PermissionService.requestPermission(
      context,
      AppPermissionType.photos,
      showRationale: true,
    );
    if (!hasPerm) return;

    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (bytes.isNotEmpty) {
          final mime = picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
          final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';
          await ApiService.setPersistentGroupIcon(dataUri);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gallery image saved permanently as default group icon!'),
                backgroundColor: Color(0xFF10B981),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking group icon from gallery: $e');
    }
  }

  void _openGroupIconModal() async {
    await GroupIconPickerModal.show(
      context,
      currentIcon: ApiService.currentGroupIcon,
      title: 'Group Icon Customization',
      onIconSelected: (newIcon) async {
        await ApiService.setPersistentGroupIcon(newIcon);
      },
    );
  }


  void _saveSoftwareName() async {
    final newName = _softwareNameController.text.trim();
    await ApiService.setSoftwareName(newName);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cloud_done, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Software name updated to "$newName" & saved to cloud!'),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
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
              Icon(Icons.cloud_done, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(child: Text('Profile, branding, and theme saved to cloud successfully!')),
            ],
          ),
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
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Color Theme & Appearance',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_done, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text('Cloud Stored', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select from curated, high-contrast, accessible palettes (persisted in cloud database):',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
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
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Software Branding, Name & System Icon Customization
          GlassContainer(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.branding_watermark, color: Color(0xFF06B6D4), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Software Branding & System Logo',
                                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06B6D4).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.cloud_done, size: 12, color: Color(0xFF06B6D4)),
                                    SizedBox(width: 4),
                                    Text('Cloud Synced', style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Customize software name, app logo, and favicon (saved to cloud database)',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Live Browser Tab Preview Mockup
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
                          Icon(Icons.tab, size: 14, color: Colors.white38),
                          SizedBox(width: 6),
                          Text(
                            'BROWSER TAB & SYSTEM BAR PREVIEW',
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
                          border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SoftwareLogoWidget(size: 20, iconSize: 12, borderRadius: 5, showShadow: false),
                            const SizedBox(width: 8),
                            ValueListenableBuilder<String>(
                              valueListenable: ApiService.softwareNameNotifier,
                              builder: (context, name, _) {
                                return ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 240),
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.close, size: 14, color: Colors.white38),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 1. Software Name Input
                const Text(
                  'Software / Application Name',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _softwareNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter custom software name...',
                          prefixIcon: const Icon(Icons.edit_attributes, color: Color(0xFF06B6D4)),
                          filled: true,
                          fillColor: const Color(0xFF131D2E),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF06B6D4)),
                          ),
                        ),
                        onSubmitted: (_) => _saveSoftwareName(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Apply Name'),
                      onPressed: _saveSoftwareName,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Software Logo & System Icon
                const Text(
                  'Software Logo & System Favicon',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pick an image file from your computer (PNG, JPG, SVG, WEBP, ICO) or choose a preset:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),

                // File Picker Action Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D2E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const SoftwareLogoWidget(size: 52, iconSize: 28, borderRadius: 14),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ValueListenableBuilder<String?>(
                              valueListenable: ApiService.customLogoDataNotifier,
                              builder: (context, customLogo, _) {
                                final isCustom = customLogo != null && customLogo.isNotEmpty;
                                return Text(
                                  isCustom ? 'Custom System Logo Active' : 'Preset System Icon Active',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                );
                              },
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Updates browser favicon and entire app logo live',
                              style: TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: _isUploadingSoftwareLogo
                                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Icon(Icons.file_upload_outlined, size: 18),
                                  label: Text(_isUploadingSoftwareLogo ? 'Processing...' : 'Pick from Device (File Picker)'),
                                  onPressed: _isUploadingSoftwareLogo ? null : _pickCustomSoftwareLogo,
                                ),
                                ValueListenableBuilder<String?>(
                                  valueListenable: ApiService.customLogoDataNotifier,
                                  builder: (context, customLogo, _) {
                                    if (customLogo == null || customLogo.isEmpty) return const SizedBox.shrink();
                                    return OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(color: Colors.white24),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.restore, size: 16),
                                      label: const Text('Reset to Preset Icon'),
                                      onPressed: _removeCustomSoftwareLogo,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Preset Icons Section
                const Text(
                  'Or Select a Preset System Icon:',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: icons.map((item) {
                    final isSelected = selectedIcon == item['id'] && ApiService.customLogoData == null;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await ApiService.resetCustomLogo();
                        _selectAppIcon(item);
                      },
                      child: Container(
                        width: 125,
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
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.asset(
                                      'assets/branding/whisper_logo.png',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 22,
                                    backgroundColor: (item['color'] as Color).withOpacity(0.2),
                                    child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 24),
                                  ),
                            const SizedBox(height: 6),
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

          // Group Icon Customization (Settings)
          GlassContainer(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_outlined, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Group Icon Customization',
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
                      child: const Text(
                        'Persistent Setting',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Customize the default group icon across the software. Choose between capturing a photo with your camera, selecting an existing image from your device gallery, or picking an available preset icon. Changes are saved permanently and restored automatically on startup.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 18),

                // Active Group Icon Display Card
                ValueListenableBuilder<String>(
                  valueListenable: ApiService.currentGroupIconNotifier,
                  builder: (context, activeGroupIcon, _) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          AvatarBadge(
                            avatarUrl: activeGroupIcon,
                            name: 'Group',
                            radius: 32,
                            isGroup: true,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      GroupIconHelper.isPreset(activeGroupIcon)
                                          ? GroupIconHelper.getPreset(activeGroupIcon).name
                                          : 'Custom Image Icon',
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  GroupIconHelper.isPreset(activeGroupIcon)
                                      ? GroupIconHelper.getPreset(activeGroupIcon).description
                                      : 'Custom gallery or camera photo saved permanently in device storage.',
                                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF06B6D4),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.photo_camera, size: 16),
                                      label: const Text('Capture with Camera', style: TextStyle(fontSize: 12)),
                                      onPressed: _captureGroupIconCamera,
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.photo_library, size: 16),
                                      label: const Text('Choose from Gallery', style: TextStyle(fontSize: 12)),
                                      onPressed: _pickGroupIconGallery,
                                    ),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white70,
                                        side: const BorderSide(color: Colors.white24),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      icon: const Icon(Icons.palette_outlined, size: 16),
                                      label: const Text('All Options / Presets', style: TextStyle(fontSize: 12)),
                                      onPressed: _openGroupIconModal,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Quick Select Available Preset Icons
                const Text(
                  'Select an Available Preset Group Icon:',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<String>(
                  valueListenable: ApiService.currentGroupIconNotifier,
                  builder: (context, activeGroupIcon, _) {
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: GroupIconHelper.presets.map((preset) {
                        final isSelected = activeGroupIcon == preset.preferenceKey ||
                            activeGroupIcon == preset.id ||
                            activeGroupIcon.endsWith(preset.id);

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            await ApiService.setPersistentGroupIcon(preset.preferenceKey);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(milliseconds: 1500),
                                  backgroundColor: preset.primaryColor,
                                  content: Row(
                                    children: [
                                      Icon(preset.icon, color: Colors.white, size: 18),
                                      const SizedBox(width: 8),
                                      Text('Group icon updated to ${preset.name}!'),
                                    ],
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? preset.primaryColor.withValues(alpha: 0.2) : Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? preset.primaryColor : Colors.white10,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: preset.primaryColor.withValues(alpha: 0.25),
                                  child: Icon(preset.icon, color: preset.primaryColor, size: 20),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  preset.name,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
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

                // 1. Profile Photo / Avatar Editor with Device File Picker
                Container(
                  padding: const EdgeInsets.all(18),
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
                              radius: 46,
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
                                  child: SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(color: Color(0xFF06B6D4), strokeWidth: 2.5),
                                  ),
                                ),
                              ),
                            )
                          else
                            InkWell(
                              onTap: _pickAvatarFromDevice,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF06B6D4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 15),
                              ),
                            ),
                        ],
                      );

                      final detailsWidget = Column(
                        crossAxisAlignment: isNarrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Profile Avatar',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'JPG • PNG • WEBP',
                                  style: TextStyle(color: Color(0xFF06B6D4), fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
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
                            'Upload a photo from your computer or phone to personalize your chat presence',
                            style: TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: isNarrow ? WrapAlignment.center : WrapAlignment.start,
                            children: [
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF06B6D4),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.file_upload_outlined, size: 17),
                                label: Text(
                                  _avatarUrlController.text.isNotEmpty || _pickedAvatarBytes != null
                                      ? 'Change Avatar'
                                      : 'Upload from Device',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                onPressed: _isUploadingAvatar ? null : _pickAvatarFromDevice,
                              ),
                              if (_avatarUrlController.text.isNotEmpty || _pickedAvatarBytes != null)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                    side: const BorderSide(color: Color(0xFFEF4444)),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                                  label: const Text('Remove', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
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
                            const SizedBox(height: 16),
                            detailsWidget,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          avatarWidget,
                          const SizedBox(width: 22),
                          Expanded(child: detailsWidget),
                        ],
                      );
                    },
                  ),
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
                const SizedBox(height: 20),

                // 6. Account Privacy Setting (Public vs Private Mode)
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
                              onTap: () => setState(() => _isPrivate = false),
                              child: Container(
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
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() => _isPrivate = true),
                              child: Container(
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
                            ),
                          ),
                        ],
                      ),
                    ],
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
      onTap: () async {
        widget.onThemeChanged(mode);
        await ApiService.setThemeMode(mode);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(milliseconds: 1500),
              backgroundColor: primary,
              content: Row(
                children: [
                  const Icon(Icons.cloud_done, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('$title theme active & stored in cloud!'),
                ],
              ),
            ),
          );
        }
      },
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
