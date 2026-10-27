import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/file_picker_helper.dart';
import '../services/group_icon_helper.dart';
import '../services/permission_service.dart';
import 'avatar_badge.dart';
import 'camera_capture_dialog.dart';

class GroupIconPickerModal extends StatefulWidget {
  final String currentIcon;
  final ValueChanged<String>? onIconSelected;
  final String title;

  const GroupIconPickerModal({
    super.key,
    required this.currentIcon,
    this.onIconSelected,
    this.title = 'Customize Group Icon',
  });

  /// Static helper to display this modal dialog/sheet easily
  static Future<String?> show(
    BuildContext context, {
    required String currentIcon,
    ValueChanged<String>? onIconSelected,
    String title = 'Customize Group Icon',
  }) async {
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => GroupIconPickerModal(
        currentIcon: currentIcon,
        title: title,
        onIconSelected: (val) {
          if (onIconSelected != null) onIconSelected(val);
          Navigator.of(ctx).pop(val);
        },
      ),
    );
    return result;
  }

  @override
  State<GroupIconPickerModal> createState() => _GroupIconPickerModalState();
}

class _GroupIconPickerModalState extends State<GroupIconPickerModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedIcon;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.currentIcon;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleCameraCapture() async {
    setState(() => _isLoading = true);
    final result = await CameraCaptureHelper.captureWithCamera(
      context,
      onFallbackGallery: _handleGalleryPick,
      onFallbackPreset: () => _tabController.animateTo(1),
    );
    if (mounted) setState(() => _isLoading = false);

    if (result != null && mounted) {
      setState(() => _selectedIcon = result.dataUri);
    }
  }

  void _handleGalleryPick() async {
    setState(() => _isLoading = true);

    // Permission check for gallery/photos
    final hasPermission = await PermissionService.requestPermission(
      context,
      AppPermissionType.photos,
      showRationale: true,
    );

    if (!hasPermission) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final picked = await FilePickerHelper.pickImage();
      if (picked != null && picked.bytes.isNotEmpty && mounted) {
        if (picked.bytes.lengthInBytes > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image is too large. Maximum supported size is 5MB.'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
          return;
        }
        setState(() => _selectedIcon = picked.dataUri);
      }
    } catch (e) {
      debugPrint('Error picking from gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handlePresetSelect(GroupIconOption preset) {
    setState(() => _selectedIcon = preset.preferenceKey);
    if (widget.onIconSelected != null) {
      widget.onIconSelected!(preset.preferenceKey);
    }
  }

  void _handleResetDefault() {
    final def = GroupIconHelper.defaultIconPreference;
    setState(() => _selectedIcon = def);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = math.min(480.0, screenSize.width - 32);
    final dialogHeight = math.min(620.0, screenSize.height - 48);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        constraints: BoxConstraints(maxWidth: 480, maxHeight: dialogHeight),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header with Active Icon Preview
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  AvatarBadge(
                    avatarUrl: _selectedIcon,
                    name: 'Group',
                    radius: 26,
                    isGroup: true,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Select preset or upload photo for this group',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Tab bar for Quick Actions (Camera / Gallery vs Preset Icons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: const Color(0xFF06B6D4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: const [
                    Tab(icon: Icon(Icons.image, size: 16), text: 'Photo / Gallery'),
                    Tab(icon: Icon(Icons.palette, size: 16), text: 'Available Icons'),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                  ),
                ),
              )
            else
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Camera & Gallery Choice
                    _buildCameraAndGalleryTab(),
                    // Tab 2: Available Preset Icons Grid
                    _buildPresetIconsTab(),
                  ],
                ),
              ),

            const Divider(color: Colors.white12, height: 1),

            // Footer with Reset, Cancel & Done
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    ),
                    icon: const Icon(Icons.restore, size: 14),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    onPressed: _handleResetDefault,
                  ),
                  const Spacer(),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white60,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    ),
                    onPressed: () {
                      if (widget.onIconSelected != null) {
                        widget.onIconSelected!(_selectedIcon);
                      }
                      Navigator.of(context).pop(_selectedIcon);
                    },
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraAndGalleryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Option 1: Device Camera
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _handleCameraCapture,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera, color: Color(0xFF06B6D4), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Capture with Camera',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Take a photo directly with instant preview',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Option 2: Device Gallery
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _handleGalleryPick,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose from Device Gallery',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Select JPG, PNG, or WEBP image (max 5MB)',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Active Selection Preview Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                AvatarBadge(
                  avatarUrl: _selectedIcon,
                  name: 'Group',
                  radius: 18,
                  isGroup: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Icon Preview',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        GroupIconHelper.isPreset(_selectedIcon)
                            ? GroupIconHelper.getPreset(_selectedIcon).name
                            : 'Custom photo / image selected',
                        style: const TextStyle(color: Colors.white54, fontSize: 10.5),
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

  Widget _buildPresetIconsTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: GroupIconHelper.presets.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (ctx, i) {
        final preset = GroupIconHelper.presets[i];
        final isSelected = _selectedIcon == preset.preferenceKey ||
            _selectedIcon == preset.id ||
            _selectedIcon.endsWith(preset.id);

        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _handlePresetSelect(preset),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? preset.primaryColor.withValues(alpha: 0.2) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? preset.primaryColor : Colors.white.withValues(alpha: 0.08),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: preset.primaryColor.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(preset.icon, color: preset.primaryColor, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        preset.description,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: preset.primaryColor, size: 15),
              ],
            ),
          ),
        );
      },
    );
  }
}
