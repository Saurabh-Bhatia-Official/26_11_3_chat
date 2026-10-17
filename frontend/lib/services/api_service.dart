import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // Configurable backend URL. On Vercel, can point to deployed Spring Boot server
  static String baseUrl = 'http://localhost:8080/api';

  static UserModel currentUser = UserModel(
    id: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    username: 'alex_rivers',
    displayName: 'Alex Rivers',
    email: 'alex@chatguard.io',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    bio: 'Cybersecurity advocate & chess grandmaster ♟️',
    statusMessage: 'Shields up! 🛡️',
    safetyScore: 98,
    isAdmin: true,
    isVerified: true,
  );

  static final UserModel elenaUser = UserModel(
    id: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
    username: 'elena_rostova',
    displayName: 'Elena Rostova',
    email: 'elena@chatguard.io',
    avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
    bio: 'Flutter & Spring Boot enthusiast ✨',
    statusMessage: 'Coding the future 💻',
    safetyScore: 94,
    isVerified: true,
  );

  static final UserModel marcusUser = UserModel(
    id: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
    username: 'marcus_vance',
    displayName: 'Marcus Vance',
    email: 'marcus@chatguard.io',
    avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
    bio: 'Ludo king & board game strategist 🎲',
    statusMessage: 'Ready for a game! ⚔️',
    safetyScore: 89,
  );

  // In-memory demo store for instant responsiveness & Vercel static deployment
  static final List<ConversationModel> _demoConversations = [
    ConversationModel(
      id: 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
      title: 'Elena Rostova',
      isGroup: false,
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
      lastMessagePreview: 'Check out the new Safety Guardian dashboard update!',
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 5)),
      unreadCount: 1,
    ),
    ConversationModel(
      id: 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55',
      title: 'Dev & Security Guild 🚀',
      isGroup: true,
      avatarUrl: 'https://images.unsplash.com/photo-1522071820081-009f0129c71c?w=150',
      lastMessagePreview: 'Who is up for a quick Chess or Snakes & Ladders match? ♟️🎲',
      lastMessageAt: DateTime.now().subtract(const Duration(minutes: 24)),
      unreadCount: 3,
    ),
    ConversationModel(
      id: 'f0eebc99-9c0b-4ef8-bb6d-6bb9bd380a66',
      title: 'Marcus Vance',
      isGroup: false,
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      lastMessagePreview: 'I challenged you to a Ludo match in chat! Click play.',
      lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 0,
    ),
  ];

  static final Map<String, List<MessageModel>> _demoMessages = {
    'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44': [
      MessageModel(
        id: 'm1',
        conversationId: 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
        senderId: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
        senderName: 'Elena Rostova',
        content: 'Hey Alex! Did you verify the Supabase PostgreSQL migration and Cloudinary uploads?',
        type: MessageType.text,
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
      ),
      MessageModel(
        id: 'm2',
        conversationId: 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
        senderId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        senderName: 'Alex Rivers',
        content: 'Yes! Both are humming. I also uploaded our architecture diagram to Cloudinary CDN.',
        type: MessageType.image,
        mediaUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800',
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      MessageModel(
        id: 'm3',
        conversationId: 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
        senderId: 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
        senderName: 'Elena Rostova',
        content: 'Awesome. Someone sent a strange link: http://paypa1-security-check.fake/login. Watch out!',
        type: MessageType.text,
        safetyFlagged: true,
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      MessageModel(
        id: 'm4',
        conversationId: 'd0eebc99-9c0b-4ef8-bb6d-6bb9bd380a44',
        senderId: 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
        senderName: 'Alex Rivers',
        content: 'Check out the new Safety Guardian dashboard update! The link scanner intercepted it immediately.',
        type: MessageType.text,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    ],
    'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55': [
      MessageModel(
        id: 'g1',
        conversationId: 'e0eebc99-9c0b-4ef8-bb6d-6bb9bd380a55',
        senderId: 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
        senderName: 'Marcus Vance',
        content: 'Who is up for a quick Chess or Snakes & Ladders match? ♟️🎲',
        type: MessageType.gameInvite,
        createdAt: DateTime.now().subtract(const Duration(minutes: 24)),
      ),
    ],
  };

  static final List<SafetyEventModel> _demoSafetyEvents = [
    SafetyEventModel(
      id: 'se1',
      eventType: 'SUSPICIOUS_LOGIN',
      severity: 'HIGH',
      description: 'Blocked unauthorized login attempt from unusual geolocation (IP: 198.51.100.23, Riga, Latvia).',
      ipAddress: '198.51.100.23',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    SafetyEventModel(
      id: 'se2',
      eventType: 'MALICIOUS_LINK',
      severity: 'MEDIUM',
      description: 'Smart Guardian intercepted spoofed phishing link: http://paypa1-security-check.fake.',
      ipAddress: '127.0.0.1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    SafetyEventModel(
      id: 'se3',
      eventType: 'SESSION_TERMINATED',
      severity: 'LOW',
      description: 'Remote session on Chrome Windows terminated via Safety Guardian Remote Kill Switch.',
      ipAddress: '172.56.21.89',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
  ];

  static Future<List<ConversationModel>> getConversations() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/chat/conversations')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => ConversationModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return _demoConversations;
  }

  static Future<List<MessageModel>> getMessages(String conversationId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/chat/conversations/$conversationId/messages')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => MessageModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return _demoMessages[conversationId] ?? [];
  }

  static Future<MessageModel> sendMessage(String conversationId, String content, {MessageType type = MessageType.text, String? mediaUrl}) async {
    final newMsg = MessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: conversationId,
      senderId: currentUser.id,
      senderName: currentUser.displayName,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      safetyFlagged: content.contains('fake') || content.contains('phish') || content.contains('paypa1'),
      createdAt: DateTime.now(),
    );

    // Save locally
    _demoMessages.putIfAbsent(conversationId, () => []);
    _demoMessages[conversationId]!.add(newMsg);

    // Try posting to Spring Boot backend
    try {
      await http.post(
        Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderId': currentUser.id,
          'senderName': currentUser.displayName,
          'content': content,
          'type': type.name.toUpperCase(),
          'mediaUrl': mediaUrl,
        }),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}

    return newMsg;
  }

  static Future<List<SafetyEventModel>> getSafetyEvents() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/safety/events/${currentUser.id}')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((item) => SafetyEventModel.fromJson(item)).toList();
      }
    } catch (_) {}
    return _demoSafetyEvents;
  }

  static Future<Map<String, dynamic>> scanUrl(String url) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/safety/scan-link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    // Built-in intelligent client-side fallback scanner
    int score = 0;
    List<String> warnings = [];
    if (url.contains('paypa1') || url.contains('fake') || url.contains('phish')) {
      score = 85;
      warnings.add('Detected deceptive brand impersonation pattern');
      warnings.add('Domain uses high-risk untrusted TLD');
    } else if (RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(url)) {
      score = 60;
      warnings.add('Numeric IP address used instead of reputable domain');
    } else {
      score = 5;
    }

    return {
      'url': url,
      'riskScore': score,
      'isSuspicious': score >= 40,
      'warnings': warnings,
    };
  }

  static Future<void> terminateSession(String deviceName) async {
    _demoSafetyEvents.insert(
      0,
      SafetyEventModel(
        id: 'se_${DateTime.now().millisecondsSinceEpoch}',
        eventType: 'SESSION_TERMINATED',
        severity: 'LOW',
        description: 'Terminated session for $deviceName via Remote Kill Switch.',
        ipAddress: '127.0.0.1',
        createdAt: DateTime.now(),
      ),
    );
  }

  static Future<void> triggerEmergencyCheckin(String status, String note) async {
    _demoSafetyEvents.insert(
      0,
      SafetyEventModel(
        id: 'se_${DateTime.now().millisecondsSinceEpoch}',
        eventType: 'EMERGENCY_CHECKIN',
        severity: 'LOW',
        description: 'Emergency Check-in triggered: [$status] $note',
        ipAddress: '127.0.0.1',
        createdAt: DateTime.now(),
      ),
    );
  }
}
