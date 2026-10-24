import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/models.dart';
import 'package:frontend/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

      expect(criticalEvent.getSeverityColor(), equals(const Color(0xFFEF4444)));
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
        title: 'saurabh',
        participant1Id: 'u_shailesh',
        participant1Name: 'shailesh',
        participant1Avatar: 'https://example.com/shailesh.png',
        participant2Id: 'u_saurabh',
        participant2Name: 'saurabh',
        participant2Avatar: 'https://example.com/saurabh.png',
        lastMessagePreview: 'Hello Bob!',
        lastMessageAt: DateTime.now(),
        unreadCount: 1,
      );

      final userShailesh = UserModel(
        id: 'u_shailesh',
        username: 'shailesh',
        displayName: 'shailesh',
      );
      final userSaurabh = UserModel(
        id: 'u_saurabh',
        username: 'saurabh',
        displayName: 'saurabh',
      );

      expect(conv.getTitleForUser(userShailesh), equals('saurabh'));
      expect(conv.getTitleForUser(userSaurabh), equals('shailesh'));
      expect(conv.getAvatarForUser(userShailesh), equals('https://example.com/saurabh.png'));
      expect(conv.getAvatarForUser(userSaurabh), equals('https://example.com/shailesh.png'));
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

    test('ConversationModel getOtherUsername resolves strictly by username', () {
      final me = UserModel(id: 'u_alice', username: 'alice_w', displayName: 'Alice Wonder');
      final conv = ConversationModel(
        id: 'c_test_user',
        title: 'Bob Builder',
        participant1Id: 'u_alice',
        participant1Name: 'Alice Wonder',
        participant2Id: 'u_bob',
        participant2Name: 'Bob Builder',
        lastMessageAt: DateTime.now(),
      );

      final cache = <String, UserModel>{
        'u_bob': UserModel(id: 'u_bob', username: 'bob_the_builder', displayName: 'Bob Builder'),
      };

      final otherUsername = conv.getOtherUsername(me, cache);
      expect(otherUsername, equals('bob_the_builder'));
    });

    test('Credential persistence and session lifecycle', () async {
      // Test login with remember me
      final user = await ApiService.login(
        username: 'test_persist_user',
        password: 'password123',
        rememberMe: true,
      );

      expect(user.username, equals('test_persist_user'));
      expect(ApiService.currentUser.username, equals('test_persist_user'));

      // Check saved credentials
      final creds = await ApiService.getSavedCredentials();
      expect(creds['username'], equals('test_persist_user'));
      expect(creds['password'], equals('password123'));
      expect(creds['rememberMe'], equals('true'));

      // Test initSession restore
      final restored = await ApiService.initSession();
      expect(restored, isTrue);

      // Test logout
      await ApiService.logout();
      expect(ApiService.currentUserNotifier.value, isNull);
    });

    test('System message logging for call completion', () async {
      const convId = 'conv_call_test';
      final sent = await ApiService.sendMessage(
        convId,
        '📞 Voice call ended • 01:45',
        type: MessageType.system,
      );

      expect(sent.type, equals(MessageType.system));
      expect(sent.content, contains('Voice call ended'));
    });

    test('PlayTogether real-time game payload serialization and parsing', () {
      final chessPayload = {
        'game': 'CHESS',
        'currentTurn': 'BLACK',
        'lastMove': 'P e2-e4',
        'statusMessage': "Opponent's turn to move",
        'timestamp': 1700000000000,
      };

      final jsonStr = jsonEncode(chessPayload);
      final messageContent = '🎮 [PLAY_TOGETHER:$jsonStr] Chess: Opponent\'s turn to move';

      expect(messageContent, contains('[PLAY_TOGETHER:'));
      final startIdx = messageContent.indexOf('[PLAY_TOGETHER:');
      final endIdx = messageContent.indexOf(']', startIdx);
      final extractedJson = messageContent.substring(startIdx + '[PLAY_TOGETHER:'.length, endIdx);
      final parsed = jsonDecode(extractedJson) as Map<String, dynamic>;

      expect(parsed['game'], equals('CHESS'));
      expect(parsed['currentTurn'], equals('BLACK'));
      expect(parsed['lastMove'], equals('P e2-e4'));
      expect(parsed['timestamp'], equals(1700000000000));
    });

    test('PlayTogether Ludo and Snakes & Ladders state synchronization', () {
      final ludoPayload = {
        'game': 'LUDO',
        'redScore': 12,
        'greenScore': 6,
        'currentDice': 5,
        'currentTurn': 'GREEN',
        'timestamp': 1700000001000,
      };
      final ludoJson = jsonEncode(ludoPayload);
      expect(ludoJson, contains('"currentDice":5'));
      expect(ludoJson, contains('"currentTurn":"GREEN"'));

      final snakesPayload = {
        'game': 'SNAKES_AND_LADDERS',
        'player1Pos': 25,
        'player2Pos': 14,
        'activePlayer': 2,
        'lastDice': 6,
        'timestamp': 1700000002000,
      };
      final snakesJson = jsonEncode(snakesPayload);
      expect(snakesJson, contains('"activePlayer":2'));
      expect(snakesJson, contains('"player1Pos":25'));
    });
  });
}
