import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AppBrandingPlatform {
  static const MethodChannel _launcherChannel = MethodChannel('com.chatgen.whisper/launcher');

  static void updateWebBranding({
    required String title,
    String? iconDataUrl,
  }) {
    // Non-web platforms do not have html document
  }

  /// Changes the Android launcher icon & display name at runtime using native activity-alias
  static Future<bool> updateAndroidLauncherBranding({
    required String iconKey,
    required String title,
  }) async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _launcherChannel.invokeMethod<bool>(
          'changeLauncherBranding',
          {
            'icon': iconKey,
            'title': title,
          },
        );
        return result ?? false;
      } catch (e) {
        debugPrint('Notice changing Android launcher branding: $e');
        return false;
      }
    }
    return false;
  }

  /// Changes the Android launcher icon at runtime using native activity-alias
  static Future<bool> updateAndroidLauncherIcon(String iconKey) async {
    return updateAndroidLauncherBranding(iconKey: iconKey, title: '');
  }

  /// Gets current active Android launcher icon
  static Future<String?> getAndroidLauncherIcon() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await _launcherChannel.invokeMethod<String>('getCurrentLauncherIcon');
      } catch (e) {
        debugPrint('Notice getting Android launcher icon: $e');
        return null;
      }
    }
    return null;
  }

  /// Gets current active Android launcher branding (icon & name)
  static Future<Map<String, String>?> getAndroidLauncherBranding() async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final res = await _launcherChannel.invokeMapMethod<String, String>('getCurrentLauncherBranding');
        return res;
      } catch (e) {
        debugPrint('Notice getting Android launcher branding: $e');
        return null;
      }
    }
    return null;
  }
}
