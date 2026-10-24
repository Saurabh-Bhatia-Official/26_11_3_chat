import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'connectivity/connectivity_platform.dart';

/// The two primary network failure conditions plus normal connected state
enum NetworkCondition {
  connected,          // Internet and backend are working
  noInternet,         // Internet is disconnected
  serverUnavailable,  // Internet is connected, but the backend server is unavailable
}

abstract class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

/// Condition 1: Internet is disconnected
class NoInternetException extends AppException {
  static const String defaultMessage = 'Internet is not on. Please turn on your internet.';
  NoInternetException([String? message]) : super(message ?? defaultMessage);
}

/// Condition 2: Internet is connected, but the backend server is unavailable
class ServerUnavailableException extends AppException {
  static const String defaultMessage = 'Server issue. The server is currently unavailable. Please try again later.';
  ServerUnavailableException([String? message]) : super(message ?? defaultMessage);
}

/// Condition 4: Backend returns an application error
class BackendApplicationException extends AppException {
  final int statusCode;
  final dynamic details;
  BackendApplicationException(String message, {this.statusCode = 400, this.details})
      : super(message);
}

class NetworkService {
  static const String msgNoInternet = 'Internet is not on. Please turn on your internet.';
  static const String msgServerUnavailable = 'Server issue. The server is currently unavailable. Please try again later.';

  /// Reactive state for current network condition
  static final ValueNotifier<NetworkCondition> conditionNotifier =
      ValueNotifier<NetworkCondition>(NetworkCondition.connected);

  static NetworkCondition get currentCondition => conditionNotifier.value;

  /// Reactive message to display in UI banners or alerts
  static final ValueNotifier<String?> bannerMessageNotifier = ValueNotifier<String?>(null);

  @visibleForTesting
  static bool? mockHasInternet;

  @visibleForTesting
  static Future<http.Response> Function()? mockRequestHandler;

  static Timer? _heartbeatTimer;
  static String? _monitoredBaseUrl;

  /// Initializes background connectivity monitoring and event listeners
  static void initialize({required String baseUrl}) {
    _monitoredBaseUrl = baseUrl;
    ConnectivityPlatform.initialize((isOnline) {
      if (!isOnline) {
        conditionNotifier.value = NetworkCondition.noInternet;
        bannerMessageNotifier.value = msgNoInternet;
      } else {
        // When internet comes back online, check if backend server is available
        checkBackendHealth();
      }
    });

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      checkBackendHealth();
    });
  }

  /// Proactively tests internet connectivity and backend availability
  static Future<NetworkCondition> checkBackendHealth([String? overrideBaseUrl]) async {
    final baseUrl = overrideBaseUrl ?? _monitoredBaseUrl;

    // 1. Check if internet is connected
    final hasInternet = mockHasInternet ?? await ConnectivityPlatform.isInternetConnected();
    if (!hasInternet) {
      conditionNotifier.value = NetworkCondition.noInternet;
      bannerMessageNotifier.value = msgNoInternet;
      return NetworkCondition.noInternet;
    }

    // 2. Internet is connected; verify backend availability
    if (baseUrl != null && baseUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse('$baseUrl/system/branding'))
            .timeout(const Duration(seconds: 4));
        if (res.statusCode >= 502 && res.statusCode <= 504) {
          conditionNotifier.value = NetworkCondition.serverUnavailable;
          bannerMessageNotifier.value = msgServerUnavailable;
          return NetworkCondition.serverUnavailable;
        }
      } catch (_) {
        conditionNotifier.value = NetworkCondition.serverUnavailable;
        bannerMessageNotifier.value = msgServerUnavailable;
        return NetworkCondition.serverUnavailable;
      }
    }

    // 3. Both internet and backend are working
    conditionNotifier.value = NetworkCondition.connected;
    bannerMessageNotifier.value = null;
    return NetworkCondition.connected;
  }

  /// Executes an HTTP request and accurately maps errors to the four conditions:
  /// - Internet is disconnected -> NoInternetException
  /// - Internet connected, backend unavailable -> ServerUnavailableException
  /// - Internet and backend working -> Returns onSuccess(response)
  /// - Backend application error -> BackendApplicationException
  static Future<T> execute<T>({
    required Future<http.Response> Function() request,
    required FutureOr<T> Function(http.Response response) onSuccess,
    String? defaultErrorMessage,
  }) async {
    http.Response? response;
    try {
      final req = mockRequestHandler ?? request;
      response = await req();
    } catch (networkError) {
      // Request failed at the transport/network layer
      final hasInternet = mockHasInternet ?? await ConnectivityPlatform.isInternetConnected();
      if (!hasInternet) {
        conditionNotifier.value = NetworkCondition.noInternet;
        bannerMessageNotifier.value = msgNoInternet;
        throw NoInternetException();
      } else {
        conditionNotifier.value = NetworkCondition.serverUnavailable;
        bannerMessageNotifier.value = msgServerUnavailable;
        throw ServerUnavailableException();
      }
    }

    // Condition 3: Success (HTTP 2xx) -> Load data normally
    if (response.statusCode >= 200 && response.statusCode < 300) {
      conditionNotifier.value = NetworkCondition.connected;
      bannerMessageNotifier.value = null;
      return await onSuccess(response);
    }

    // Gateway / Server outage status codes (502, 503, 504)
    if (response.statusCode >= 502 && response.statusCode <= 504) {
      final hasInternet = mockHasInternet ?? await ConnectivityPlatform.isInternetConnected();
      if (!hasInternet) {
        conditionNotifier.value = NetworkCondition.noInternet;
        bannerMessageNotifier.value = msgNoInternet;
        throw NoInternetException();
      } else {
        conditionNotifier.value = NetworkCondition.serverUnavailable;
        bannerMessageNotifier.value = msgServerUnavailable;
        throw ServerUnavailableException();
      }
    }

    // Condition 4: Backend returns an application error
    String errorMsg = defaultErrorMessage ?? 'Request failed (${response.statusCode})';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        errorMsg = decoded['error']?.toString() ??
                   decoded['message']?.toString() ??
                   decoded['msg']?.toString() ??
                   errorMsg;
      }
    } catch (_) {
      if (response.body.isNotEmpty && response.body.length < 150) {
        errorMsg = response.body;
      }
    }

    throw BackendApplicationException(errorMsg, statusCode: response.statusCode);
  }

  /// Diagnoses any error/response and returns the exact human-readable message
  static Future<String> getErrorMessage(dynamic error, {http.Response? response}) async {
    if (error is AppException) {
      return error.message;
    }
    if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
      return '';
    }
    if (response != null && (response.statusCode >= 502 && response.statusCode <= 504)) {
      final hasInternet = mockHasInternet ?? await ConnectivityPlatform.isInternetConnected();
      return hasInternet ? msgServerUnavailable : msgNoInternet;
    }
    if (response != null && response.statusCode >= 400) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return decoded['error']?.toString() ??
                 decoded['message']?.toString() ??
                 'Request failed (${response.statusCode})';
        }
      } catch (_) {}
      return 'Request failed (${response.statusCode})';
    }

    final hasInternet = mockHasInternet ?? await ConnectivityPlatform.isInternetConnected();
    return hasInternet ? msgServerUnavailable : msgNoInternet;
  }
}
