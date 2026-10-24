import 'dart:async';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

class ConnectivityPlatform {
  static void initialize(void Function(bool isOnline) onStatusChanged) {
    try {
      html.window.addEventListener('online', (_) => onStatusChanged(true));
      html.window.addEventListener('offline', (_) => onStatusChanged(false));
    } catch (_) {}
  }

  static Future<bool> isInternetConnected() async {
    try {
      // 1. Check browser navigator.onLine flag first
      final onLine = html.window.navigator.onLine ?? true;
      if (!onLine) {
        return false;
      }

      // 2. Perform a probe to a fast CORS-enabled public endpoint
      final res = await http.get(
        Uri.parse('https://dns.google/resolve?name=google.com&type=A'),
      ).timeout(const Duration(milliseconds: 2500));
      return res.statusCode == 200;
    } catch (_) {
      // Fallback to browser's built-in navigator state
      return html.window.navigator.onLine ?? false;
    }
  }
}
