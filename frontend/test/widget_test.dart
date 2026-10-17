import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/models.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  group('PRD Domain & Model Tests', () {
    test('UserModel serialization and default safety score', () {
      final user = UserModel(
        id: 'u1',
        username: 'alex',
        displayName: 'Alex Rivers',
      );

      expect(user.safetyScore, equals(100));
      expect(user.isAdmin, isFalse);

      final json = user.toJson();
      expect(json['username'], equals('alex'));

      final fromJson = UserModel.fromJson(json);
      expect(fromJson.displayName, equals('Alex Rivers'));
    });

    test('SafetyEventModel parses severity and colors correctly', () {
      final criticalEvent = SafetyEventModel(
        id: 'e1',
        eventType: 'SUSPICIOUS_LOGIN',
        severity: 'CRITICAL',
        description: 'Unauthorized login from unknown IP',
        createdAt: DateTime.now(),
      );

      expect(criticalEvent.getSeverityColor().value, equals(0xFFEF4444));
    });

    test('ApiService correctly intercepts malicious phishing URLs', () async {
      final result = await ApiService.scanUrl('http://paypa1-security-check.fake/login');
      expect(result['isSuspicious'], isTrue);
      expect(result['riskScore'], greaterThanOrEqualTo(40));
      expect((result['warnings'] as List).isNotEmpty, isTrue);

      final cleanResult = await ApiService.scanUrl('https://flutter.dev');
      expect(cleanResult['isSuspicious'], isFalse);
    });

    test('ConversationModel unread count and grouping', () {
      final conv = ConversationModel(
        id: 'c1',
        title: 'Dev Guild',
        isGroup: true,
        lastMessageAt: DateTime.now(),
        unreadCount: 3,
      );

      expect(conv.isGroup, isTrue);
      expect(conv.unreadCount, equals(3));
    });
  });
}
