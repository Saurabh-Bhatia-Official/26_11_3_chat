// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class AppBrandingPlatform {
  static void updateWebBranding({
    required String title,
    String? iconDataUrl,
  }) {
    try {
      html.document.title = title;

      final existingLinks = html.document.querySelectorAll("link[rel*='icon']");
      for (final el in existingLinks) {
        el.remove();
      }

      final href = (iconDataUrl != null && iconDataUrl.isNotEmpty) ? iconDataUrl : 'favicon.png';
      final newLink = html.LinkElement()
        ..id = 'app-dynamic-favicon'
        ..rel = 'shortcut icon'
        ..type = href.startsWith('data:image/svg') ? 'image/svg+xml' : 'image/png'
        ..href = href;

      html.document.head?.append(newLink);
    } catch (_) {}
  }

  static Future<bool> updateAndroidLauncherBranding({
    required String iconKey,
    required String title,
  }) async {
    return false;
  }

  static Future<bool> updateAndroidLauncherIcon(String iconKey) async {
    return false;
  }

  static Future<String?> getAndroidLauncherIcon() async {
    return null;
  }

  static Future<Map<String, String>?> getAndroidLauncherBranding() async {
    return null;
  }
}
