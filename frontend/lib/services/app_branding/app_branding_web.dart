// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class AppBrandingPlatform {
  static void updateWebBranding({
    required String title,
    String? iconDataUrl,
  }) {
    try {
      html.document.title = title;

      if (iconDataUrl != null && iconDataUrl.isNotEmpty) {
        final existingLinks = html.document.querySelectorAll("link[rel*='icon']");
        for (final el in existingLinks) {
          el.remove();
        }

        final newLink = html.LinkElement()
          ..id = 'app-dynamic-favicon'
          ..rel = 'shortcut icon'
          ..type = iconDataUrl.startsWith('data:image/svg') ? 'image/svg+xml' : 'image/png'
          ..href = iconDataUrl;

        html.document.head?.append(newLink);
      }
    } catch (_) {}
  }
}
