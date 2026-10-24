import 'dart:async';
import 'dart:io';

class ConnectivityPlatform {
  static void initialize(void Function(bool isOnline) onStatusChanged) {}

  static Future<bool> isInternetConnected() async {
    try {
      final lookup = await InternetAddress.lookup('dns.google')
          .timeout(const Duration(milliseconds: 2500));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    try {
      final lookup2 = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(milliseconds: 2000));
      if (lookup2.isNotEmpty && lookup2[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {}

    return false;
  }
}
