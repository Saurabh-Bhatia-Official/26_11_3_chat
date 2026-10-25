import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/file_picker_helper.dart';
import '../services/group_icon_helper.dart';
import '../services/permission_service.dart';
import 'avatar_badge.dart';
import 'camera_capture_dialog.dart';

class GroupIconPickerModal extends StatefulWidget {
  final String currentIcon;
  final ValueChanged<String> onIconSelected;
  final String title;

  const GroupIconPickerModal({
    super.key,
    required this.currentIcon,
    required this.onIconSelected,
    this.title = 'Customize Group Icon',
  });

  /// Static helper to display this modal dialog/sheet easily
  static Future<String?> show(
    BuildContext context, {
    required String currentIcon,
    ValueChanged<String>? onIconSelected,
    String title = 'Customize Group Icon',
  }) {
    return showDialog<String?>(
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
      widget.onIconSelected(result.dataUri);
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
        widget.onIconSelected(picked.dataUri);
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
    widget.onIconSelected(preset.preferenceKey);
  }

  void _handleResetDefault() {
    final def = GroupIconHelper.defaultIconPreference;
    setState(() => _selectedIcon = def);
    widget.onIconSelected(def);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        height: 600,
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 600),
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
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Choose camera, gallery image, or preset icon',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Tab bar for Quick Actions (Camera / Gallery vs Preset Icons)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                    Tab(icon: Icon(Icons.image, size: 18), text: 'Photo / Gallery'),
                    Tab(icon: Icon(Icons.palette, size: 18), text: 'Available Icons'),
                  ],
                ),
              ),
            ),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
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

            // Footer with Reset & Close
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white60),
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Reset to Default', style: TextStyle(fontSize: 12)),
                    onPressed: _handleResetDefault,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(_selectedIcon),
                    child: const Text('Done'),
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
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Option 1: Device Camera
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _handleCameraCapture,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera, color: Color(0xFF06B6D4), size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Capture with Camera',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Take a fresh photo directly using device camera with instant preview & retake',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Option 2: Device Gallery
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: _handleGalleryPick,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library, color: Color(0xFF10B981), size: 28),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose from Device Gallery',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Select an existing JPG, PNG, or WEBP image from your device photos',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Info Note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF8B5CF6), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Selected group icons are stored permanently and remain active after restarting the app.',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
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
      padding: const EdgeInsets.all(16),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: preset.primaryColor.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(preset.icon, color: preset.primaryColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: preset.primaryColor, size: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
