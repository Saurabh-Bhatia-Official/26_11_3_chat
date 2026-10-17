import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/models.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  group('PRD Domain & Model Tests', () {
    test('UserModel serialization and dynamic fields', () {
      final user = UserModel(
        id: 'u1',
        username: 'alex',
        displayName: 'Alex Rivers',
      );

      expect(user.safetyScore, equals(100));
      expect(user.isVerified, isFalse);

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

    test('ConversationModel participants and preview', () {
      final conv = ConversationModel(
        id: 'c1',
        title: 'Chat with Bob',
        participant1Id: 'u1',
        participant2Id: 'u2',
        lastMessagePreview: 'Hello Bob!',
        lastMessageAt: DateTime.now(),
        unreadCount: 1,
      );

      expect(conv.participant1Id, equals('u1'));
      expect(conv.participant2Id, equals('u2'));
      expect(conv.unreadCount, equals(1));
    });

    test('ApiService deduplicates sender messages so they appear only once', () async {
      const convId = 'test_conv_dedup';
      final sent1 = await ApiService.sendMessage(convId, 'Test single message');
      expect(sent1.content, equals('Test single message'));

      final list = await ApiService.getMessages(convId);
      final count = list.where((m) => m.content == 'Test single message').length;
      expect(count, equals(1), reason: 'Message should appear exactly once in the list');
    });

    test('MessageModel retains senderAvatarUrl and emergency contacts manage accounts', () async {
      final msg = MessageModel(
        id: 'm1',
        conversationId: 'c1',
        senderId: 'u1',
        senderName: 'Alice',
        senderAvatarUrl: 'https://example.com/avatar.jpg',
        content: 'Hello!',
        createdAt: DateTime.now(),
      );

      expect(msg.senderAvatarUrl, equals('https://example.com/avatar.jpg'));

      final contact = await ApiService.addEmergencyContact(
        name: 'SecOps Guild',
        accountOrEmail: 'secops@chatguard.io',
        relationship: 'Security Team Account',
        phone: '+1 555-0100',
      );

      expect(contact.name, equals('SecOps Guild'));
      expect(contact.accountOrEmail, equals('secops@chatguard.io'));

      final allContacts = await ApiService.getEmergencyContacts();
      expect(allContacts.any((c) => c.accountOrEmail == 'secops@chatguard.io'), isTrue);
    });
  });
}
