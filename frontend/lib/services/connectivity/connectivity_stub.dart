class ConnectivityPlatform {
  static void initialize(void Function(bool isOnline) onStatusChanged) {}

  static Future<bool> isInternetConnected() async {
    return true;
  }
}
