import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

enum AppPermissionType {
  camera,
  microphone,
  photos,
  notifications,
}

class PermissionMetadata {
  final AppPermissionType type;
  final String title;
  final String description;
  final String rationale;
  final String deniedMessage;
  final String permanentlyDeniedMessage;
  final IconData icon;
  final Color accentColor;

  const PermissionMetadata({
    required this.type,
    required this.title,
    required this.description,
    required this.rationale,
    required this.deniedMessage,
    required this.permanentlyDeniedMessage,
    required this.icon,
    required this.accentColor,
  });
}

class PermissionService {
  // Test mock overrides
  static Map<AppPermissionType, PermissionStatus>? mockStatus;

  static const Map<AppPermissionType, PermissionMetadata> metadata = {
    AppPermissionType.camera: PermissionMetadata(
      type: AppPermissionType.camera,
      title: 'Camera Permission',
      description: 'Capture photos for group icons, profile pictures, and video calls.',
      rationale:
          'Whisper requires camera access so you can capture photos directly using your device camera for group icon customization, profile avatars, and live video calls.',
      deniedMessage:
          'Camera access was denied. You can still customize icons by picking an existing image from your device gallery or selecting an available preset icon.',
      permanentlyDeniedMessage:
          'Camera permission is permanently denied in your device/browser settings. To capture photos, please enable camera permission in App Settings.',
      icon: Icons.camera_alt_rounded,
      accentColor: Color(0xFF06B6D4),
    ),
    AppPermissionType.microphone: PermissionMetadata(
      type: AppPermissionType.microphone,
      title: 'Microphone Permission',
      description: 'Record voice messages and participate in calls.',
      rationale:
          'Whisper requires microphone access so you can record high-fidelity voice notes and speak with participants during voice and video calls.',
      deniedMessage:
          'Microphone permission was denied. Microphone access is required to record voice messages and make calls.',
      permanentlyDeniedMessage:
          'Microphone permission is permanently denied. Please enable microphone access in your system settings to use audio features.',
      icon: Icons.mic_rounded,
      accentColor: Color(0xFF8B5CF6),
    ),
    AppPermissionType.photos: PermissionMetadata(
      type: AppPermissionType.photos,
      title: 'Photos, Gallery & Storage',
      description: 'Access photos and device storage to upload profile pictures, set group icons, and share media.',
      rationale:
          'Whisper requires access to your device photos and storage so you can upload profile pictures, customize group icons, and share images seamlessly.',
      deniedMessage:
          'Storage and photo access was denied. You can still set your profile picture by entering an image URL, or pick from available preset icons.',
      permanentlyDeniedMessage:
          'Photos and storage access is permanently denied in system settings. To upload profile pictures or pick images from your gallery, please grant permission in App Settings.',
      icon: Icons.photo_library_rounded,
      accentColor: Color(0xFF10B981),
    ),
    AppPermissionType.notifications: PermissionMetadata(
      type: AppPermissionType.notifications,
      title: 'Notification Permission',
      description: 'Receive real-time alerts for incoming messages and security events.',
      rationale:
          'Whisper requires notification permission so you never miss urgent messages, incoming calls, or Smart Safety Guardian security alerts.',
      deniedMessage:
          'Notifications are disabled. You will not receive background alerts for new messages or security events.',
      permanentlyDeniedMessage:
          'Notifications are permanently disabled. Please enable notifications in App Settings to stay alerted.',
      icon: Icons.notifications_active_rounded,
      accentColor: Color(0xFFF59E0B),
    ),
  };

  /// Map AppPermissionType to permission_handler Permission
  static Permission? _getPlatformPermission(AppPermissionType type) {
    switch (type) {
      case AppPermissionType.camera:
        return Permission.camera;
      case AppPermissionType.microphone:
        return Permission.microphone;
      case AppPermissionType.photos:
        return Permission.photos;
      case AppPermissionType.notifications:
        return Permission.notification;
    }
  }

  /// Checks current permission status without prompting
  static Future<PermissionStatus> checkPermission(AppPermissionType type) async {
    if (mockStatus != null && mockStatus!.containsKey(type)) {
      return mockStatus![type]!;
    }

    if (kIsWeb) {
      // On web, permissions are requested just-in-time by browser APIs
      return PermissionStatus.granted;
    }

    // On Desktop platforms (Windows, macOS, Linux), native file pickers do not use mobile runtime permissions
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      if (type == AppPermissionType.photos) {
        return PermissionStatus.granted;
      }
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && type == AppPermissionType.photos) {
      try {
        final photos = await Permission.photos.status;
        if (photos.isGranted || photos.isLimited) return photos;
        final storage = await Permission.storage.status;
        if (storage.isGranted) return storage;
        // Only permanently denied if both photos and storage are permanently denied
        if (photos.isPermanentlyDenied && storage.isPermanentlyDenied) {
          return PermissionStatus.permanentlyDenied;
        }
        return PermissionStatus.denied;
      } catch (_) {
        return PermissionStatus.granted;
      }
    }

    final perm = _getPlatformPermission(type);
    if (perm == null) return PermissionStatus.granted;

    try {
      return await perm.status;
    } catch (_) {
      return PermissionStatus.granted;
    }
  }

  /// Comprehensive permission request flow:
  /// 1. Explain purpose to user via rationale dialog if not already granted
  /// 2. Request permission from platform
  /// 3. Handle granted, denied, and permanently denied gracefully
  static Future<bool> requestPermission(
    BuildContext context,
    AppPermissionType type, {
    bool showRationale = true,
  }) async {
    if (mockStatus != null && mockStatus!.containsKey(type)) {
      final status = mockStatus![type]!;
      if (status.isGranted) return true;
      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          await showPermanentlyDeniedDialog(context, type);
        }
        return false;
      }
      if (context.mounted) {
        await showDeniedDialog(context, type);
      }
      return false;
    }

    if (kIsWeb) {
      if (type == AppPermissionType.photos) {
        return true;
      }
      // On web, show explanation if requested for camera/mic, then proceed to browser prompt
      if (showRationale) {
        final proceed = await showRationaleDialog(context, type);
        if (!proceed) return false;
      }
      return true;
    }

    // On Desktop platforms, native OS file dialogs do not require mobile runtime permissions
    if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      if (type == AppPermissionType.photos) {
        return true;
      }
    }

    final currentStatus = await checkPermission(type);
    if (currentStatus.isGranted || currentStatus.isLimited) {
      return true;
    }

    if (currentStatus.isPermanentlyDenied) {
      if (context.mounted) {
        await showPermanentlyDeniedDialog(context, type);
      }
      return false;
    }

    // Step 1: Explain purpose to user
    if (showRationale) {
      if (!context.mounted) return false;
      final proceed = await showRationaleDialog(context, type);
      if (!proceed) return false;
    }

    // Step 2: Request permission from platform
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android && type == AppPermissionType.photos) {
        // On Android 13+ (API 33+), request Permission.photos (READ_MEDIA_IMAGES)
        final photoStatus = await Permission.photos.request();
        if (photoStatus.isGranted || photoStatus.isLimited) {
          return true;
        }
        // Fallback to storage permission for Android <= 12 (READ_EXTERNAL_STORAGE)
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          return true;
        }

        // Only mark permanently denied if both are permanently denied
        if (photoStatus.isPermanentlyDenied && storageStatus.isPermanentlyDenied) {
          if (context.mounted) {
            await showPermanentlyDeniedDialog(context, type);
          }
          return false;
        }

        if (context.mounted) {
          await showDeniedDialog(context, type);
        }
        return false;
      } else {
        final perm = _getPlatformPermission(type);
        if (perm == null) return true;
        final newStatus = await perm.request();

        if (newStatus.isGranted || newStatus.isLimited) {
          return true;
        }

        if (newStatus.isPermanentlyDenied) {
          if (context.mounted) {
            await showPermanentlyDeniedDialog(context, type);
          }
          return false;
        }

        if (context.mounted) {
          await showDeniedDialog(context, type);
        }
        return false;
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
      return false;
    }
    return false;
  }

  /// Displays clear rationale explanation dialog to the user before requesting
  static Future<bool> showRationaleDialog(
    BuildContext context,
    AppPermissionType type,
  ) async {
    final meta = metadata[type]!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: meta.accentColor.withValues(alpha: 0.4), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: meta.accentColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(meta.icon, color: meta.accentColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                meta.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta.rationale,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.privacy_tip_outlined, color: Color(0xFF10B981), size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Your privacy is protected. Used only when you trigger this action.',
                      style: TextStyle(color: Colors.white60, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: meta.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Continue'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  /// Displays user-friendly dialog when permission is denied
  static Future<void> showDeniedDialog(
    BuildContext context,
    AppPermissionType type, {
    VoidCallback? onRetry,
  }) async {
    final meta = metadata[type]!;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 22),
            const SizedBox(width: 10),
            Text('${meta.title} Denied', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          meta.deniedMessage,
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss', style: TextStyle(color: Colors.white60)),
          ),
          if (onRetry != null)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: meta.accentColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                onRetry();
              },
              child: const Text('Try Again'),
            ),
        ],
      ),
    );
  }

  /// Explains permanently denied permissions and guides user to open Settings
  static Future<void> showPermanentlyDeniedDialog(
    BuildContext context,
    AppPermissionType type,
  ) async {
    final meta = metadata[type]!;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text('Permission Required', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta.permanentlyDeniedMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Settings > Privacy > Permissions > Allow Whisper',
              style: TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Open Settings'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await openAppSettings();
              } catch (_) {}
            },
          ),
        ],
      ),
    );
  }

  /// Graceful handling for camera or hardware unavailability
  static Future<void> showUnavailableDialog(
    BuildContext context, {
    String? message,
    VoidCallback? onChooseGallery,
    VoidCallback? onChoosePreset,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.no_photography_outlined, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 10),
            Text('Camera Unavailable', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          message ??
              'No working camera was detected on this device, or access is blocked by another application. You can choose an image from your gallery or pick an available preset icon instead.',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
          if (onChooseGallery != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.photo_library, size: 16),
              label: const Text('Gallery'),
              onPressed: () {
                Navigator.of(ctx).pop();
                onChooseGallery();
              },
            ),
          if (onChoosePreset != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.palette, size: 16),
              label: const Text('Preset Icons'),
              onPressed: () {
                Navigator.of(ctx).pop();
                onChoosePreset();
              },
            ),
        ],
      ),
    );
  }
}
