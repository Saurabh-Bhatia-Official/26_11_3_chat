import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/network_service.dart';
import 'package:frontend/widgets/network_status_banner.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NetworkService.mockHasInternet = true;
    NetworkService.mockRequestHandler = null;
    NetworkService.conditionNotifier.value = NetworkCondition.connected;
    NetworkService.bannerMessageNotifier.value = null;
  });

  tearDown(() {
    NetworkService.mockHasInternet = null;
    NetworkService.mockRequestHandler = null;
  });

  group('Network Connectivity & Backend Availability Conditions', () {
    test('Condition 1: Internet is disconnected displays exact message', () async {
      // Simulate disconnected internet
      NetworkService.mockHasInternet = false;

      // Executing any request must throw NoInternetException
      await expectLater(
        NetworkService.execute(
          request: () async => throw const SocketException('No route to host'),
          onSuccess: (res) => res.body,
        ),
        throwsA(
          isA<NoInternetException>().having(
            (e) => e.message,
            'message',
            equals('Internet is not on. Please turn on your internet.'),
          ),
        ),
      );

      // Verify reactive condition and banner notifier
      expect(NetworkService.currentCondition, equals(NetworkCondition.noInternet));
      expect(
        NetworkService.bannerMessageNotifier.value,
        equals('Internet is not on. Please turn on your internet.'),
      );

      // Verify diagnosis helper
      final msg = await NetworkService.getErrorMessage(NoInternetException());
      expect(msg, equals('Internet is not on. Please turn on your internet.'));
    });

    test('Condition 2: Internet connected but backend unavailable displays exact message (Transport error)', () async {
      // Simulate internet available, but backend unreachable
      NetworkService.mockHasInternet = true;

      await expectLater(
        NetworkService.execute(
          request: () async => throw const SocketException('Connection refused to backend'),
          onSuccess: (res) => res.body,
        ),
        throwsA(
          isA<ServerUnavailableException>().having(
            (e) => e.message,
            'message',
            equals('Server issue. The server is currently unavailable. Please try again later.'),
          ),
        ),
      );

      expect(NetworkService.currentCondition, equals(NetworkCondition.serverUnavailable));
      expect(
        NetworkService.bannerMessageNotifier.value,
        equals('Server issue. The server is currently unavailable. Please try again later.'),
      );
    });

    test('Condition 2: Internet connected but backend returns 502/503/504 gateway error', () async {
      NetworkService.mockHasInternet = true;

      for (final code in [502, 503, 504]) {
        await expectLater(
          NetworkService.execute(
            request: () async => http.Response('Bad Gateway / Gateway Timeout', code),
            onSuccess: (res) => res.body,
          ),
          throwsA(
            isA<ServerUnavailableException>().having(
              (e) => e.message,
              'message',
              equals('Server issue. The server is currently unavailable. Please try again later.'),
            ),
          ),
        );

        expect(NetworkService.currentCondition, equals(NetworkCondition.serverUnavailable));
        expect(
          NetworkService.bannerMessageNotifier.value,
          equals('Server issue. The server is currently unavailable. Please try again later.'),
        );
      }
    });

    test('Condition 3: Internet and backend are working loads data normally', () async {
      NetworkService.mockHasInternet = true;

      final result = await NetworkService.execute<Map<String, dynamic>>(
        request: () async => http.Response(jsonEncode({'status': 'OK', 'items': [1, 2, 3]}), 200),
        onSuccess: (res) => jsonDecode(res.body) as Map<String, dynamic>,
      );

      expect(result['status'], equals('OK'));
      expect(result['items'], equals([1, 2, 3]));
      expect(NetworkService.currentCondition, equals(NetworkCondition.connected));
      expect(NetworkService.bannerMessageNotifier.value, isNull);
    });

    test('Condition 4: Backend returns an application error displays appropriate error message', () async {
      NetworkService.mockHasInternet = true;

      // JSON error response with custom message
      expect(
        () => NetworkService.execute(
          request: () async => http.Response(
            jsonEncode({'error': 'Invalid username or password'}),
            401,
          ),
          onSuccess: (res) => res.body,
        ),
        throwsA(
          isA<BackendApplicationException>().having(
            (e) => e.message,
            'message',
            equals('Invalid username or password'),
          ),
        ),
      );

      // JSON error response with 'message' field
      expect(
        () => NetworkService.execute(
          request: () async => http.Response(
            jsonEncode({'message': 'Conversation does not exist or user lacks permission'}),
            404,
          ),
          onSuccess: (res) => res.body,
        ),
        throwsA(
          isA<BackendApplicationException>().having(
            (e) => e.message,
            'message',
            equals('Conversation does not exist or user lacks permission'),
          ),
        ),
      );
    });

    testWidgets('NetworkStatusBanner UI renders correct condition messages', (tester) async {
      // 1. When connected: Banner is completely hidden
      NetworkService.conditionNotifier.value = NetworkCondition.connected;
      NetworkService.bannerMessageNotifier.value = null;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NetworkStatusBanner(),
          ),
        ),
      );

      expect(find.text('Internet is not on. Please turn on your internet.'), findsNothing);
      expect(find.text('Server issue. The server is currently unavailable. Please try again later.'), findsNothing);

      // 2. When internet is disconnected: Red banner with exact message
      NetworkService.conditionNotifier.value = NetworkCondition.noInternet;
      NetworkService.bannerMessageNotifier.value = NetworkService.msgNoInternet;
      await tester.pumpAndSettle();

      expect(find.text('Internet is not on. Please turn on your internet.'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      // 3. When server is unavailable: Amber banner with exact message and Retry action
      bool retryPressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NetworkStatusBanner(
              onRetry: () => retryPressed = true,
            ),
          ),
        ),
      );

      NetworkService.conditionNotifier.value = NetworkCondition.serverUnavailable;
      NetworkService.bannerMessageNotifier.value = NetworkService.msgServerUnavailable;
      await tester.pumpAndSettle();

      expect(find.text('Server issue. The server is currently unavailable. Please try again later.'), findsOneWidget);
      expect(find.byIcon(Icons.dns_rounded), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retryPressed, isTrue);
    });
  });
}
