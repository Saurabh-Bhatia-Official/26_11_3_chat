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

  /// Changes the Android launcher icon at runtime using native activity-alias
  static Future<bool> updateAndroidLauncherIcon(String iconKey) async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        final result = await _launcherChannel.invokeMethod<bool>('changeLauncherIcon', {'icon': iconKey});
        return result ?? false;
      } catch (e) {
        debugPrint('Notice changing Android launcher icon: $e');
        return false;
      }
    }
    return false;
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
}
