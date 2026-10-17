import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class ApiService {
  // Configurable backend URL (defaults to local Spring Boot port 8085)
  static String baseUrl = 'http://localhost:8085/api';

  // Dynamic Auth State (null = not logged in)
  static final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier<UserModel?>(null);

  static UserModel get currentUser => currentUserNotifier.value ?? UserModel(id: 'u_default', username: 'guest', displayName: 'Guest User');
  static set currentUser(UserModel user) => currentUserNotifier.value = user;

  // Local caching to support offline UI resilience
  static final List<ConversationModel> _localConversations = [];
  static final Map<String, List<MessageModel>> _localMessages = {};

  // ==========================================
  // AUTHENTICATION
  // ==========================================

  static Future<UserModel> login({required String username, required String password}) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username.trim(), 'password': password}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = UserModel.fromJson(data['user'] ?? data);
        currentUserNotifier.value = user;
        return user;
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Login failed (${res.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('User not found') || e.toString().contains('Incorrect password')) {
        rethrow;
      }
      // If backend is unreachable, create session for user
      final fallbackUser = UserModel(
        id: 'usr_${username.trim()}',
        username: username.trim(),
        displayName: username.trim(),
      );
      currentUserNotifier.value = fallbackUser;
      return fallbackUser;
    }
  }

  static Future<UserModel> signup({
    required String username,
    required String displayName,
    required String email,
    required String password,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'displayName': displayName.trim().isNotEmpty ? displayName.trim() : username.trim(),
          'email': email.trim().isNotEmpty ? email.trim() : '${username.trim()}@chat.io',
          'password': password,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = UserModel.fromJson(data['user'] ?? data);
        currentUserNotifier.value = user;
        return user;
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Sign up failed (${res.statusCode})');
      }
    } catch (e) {
      if (e.toString().contains('already registered') || e.toString().contains('is required')) {
        rethrow;
      }
      final fallbackUser = UserModel(
        id: 'usr_${username.trim()}',
        username: username.trim(),
        displayName: displayName.trim().isNotEmpty ? displayName.trim() : username.trim(),
        email: email.trim(),
      );
      currentUserNotifier.value = fallbackUser;
      return fallbackUser;
    }
  }

  static void logout() {
    currentUserNotifier.value = null;
    _localConversations.clear();
    _localMessages.clear();
  }

  // ==========================================
  // USERS & CONVERSATIONS
  // ==========================================

  static final Map<String, UserModel> userCache = {};

  static Future<List<UserModel>> getUsers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/auth/users')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        final users = list.map((item) => UserModel.fromJson(item)).toList();
        for (final u in users) {
          userCache[u.id] = u;
        }
        return users;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<ConversationModel>> getConversations() async {
    try {
      final userId = currentUserNotifier.value?.id;
      final uri = userId != null
          ? Uri.parse('$baseUrl/chat/conversations?userId=$userId')
          : Uri.parse('$baseUrl/chat/conversations');

      final res = await http.get(uri).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        final convs = list.map((item) => ConversationModel.fromJson(item)).toList();
        _localConversations.clear();
        _localConversations.addAll(convs);
        return convs;
      }
    } catch (_) {}
    return _localConversations;
  }

  static Future<ConversationModel> createConversation({
    required UserModel targetUser,
  }) async {
    final me = currentUser;
    final payload = {
      'title': targetUser.displayName,
      'isGroup': false,
      'avatarUrl': targetUser.avatarUrl,
      'createdBy': me.id,
      'participant1Id': me.id,
      'participant1Name': me.displayName,
      'participant1Avatar': me.avatarUrl,
      'participant2Id': targetUser.id,
      'participant2Name': targetUser.displayName,
      'participant2Avatar': targetUser.avatarUrl,
    };

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chat/conversations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200) {
        final conv = ConversationModel.fromJson(jsonDecode(res.body));
        _localConversations.removeWhere((c) => c.id == conv.id);
        _localConversations.insert(0, conv);
        return conv;
      }
    } catch (_) {}

    // Fallback local conversation
    final fallbackConv = ConversationModel(
      id: 'conv_${targetUser.id}',
      title: targetUser.displayName,
      isGroup: false,
      avatarUrl: targetUser.avatarUrl,
      participant1Id: me.id,
      participant1Name: me.displayName,
      participant1Avatar: me.avatarUrl,
      participant2Id: targetUser.id,
      participant2Name: targetUser.displayName,
      participant2Avatar: targetUser.avatarUrl,
      lastMessagePreview: 'Started a new conversation',
      lastMessageAt: DateTime.now(),
    );
    _localConversations.removeWhere((c) => c.id == fallbackConv.id);
    _localConversations.insert(0, fallbackConv);
    return fallbackConv;
  }

  // ==========================================
  // MESSAGES
  // ==========================================

  static List<MessageModel> _deduplicate(List<MessageModel> list) {
    final seenIds = <String>{};
    final result = <MessageModel>[];
    for (final m in list) {
      if (seenIds.add(m.id)) {
        final duplicate = result.any((existing) =>
            existing.senderId == m.senderId &&
            existing.content == m.content &&
            existing.createdAt.difference(m.createdAt).abs().inSeconds <= 2);
        if (!duplicate) {
          result.add(m);
        }
      }
    }
    return result;
  }

  static Future<List<MessageModel>> getMessages(String conversationId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/chat/conversations/$conversationId/messages')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        final msgs = list.map((item) => MessageModel.fromJson(item)).toList();
        _localMessages[conversationId] = _deduplicate(msgs);
        return List<MessageModel>.from(_localMessages[conversationId]!);
      }
    } catch (_) {}
    return List<MessageModel>.from(_localMessages[conversationId] ?? []);
  }

  static Future<MessageModel> sendMessage(
    String conversationId,
    String content, {
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    final me = currentUser;
    final tempId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    MessageModel finalMsg = MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: me.id,
      senderName: me.displayName,
      senderAvatarUrl: me.avatarUrl,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      safetyFlagged: content.contains('fake') || content.contains('phish') || content.contains('paypa1'),
      createdAt: DateTime.now(),
    );

    // Post to Spring Boot backend
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderId': me.id,
          'senderName': me.displayName,
          'senderAvatarUrl': me.avatarUrl,
          'content': content,
          'type': type.name.toUpperCase(),
          'mediaUrl': mediaUrl,
        }),
      ).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        finalMsg = MessageModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}

    // Save locally without duplicate entries
    _localMessages.putIfAbsent(conversationId, () => []);
    _localMessages[conversationId]!.removeWhere((m) =>
        m.id == finalMsg.id ||
        m.id == tempId ||
        (m.senderId == finalMsg.senderId &&
            m.content == finalMsg.content &&
            m.createdAt.difference(finalMsg.createdAt).abs().inSeconds <= 2));
    _localMessages[conversationId]!.add(finalMsg);

    // Update conversation preview
    final convIndex = _localConversations.indexWhere((c) => c.id == conversationId);
    if (convIndex != -1) {
      final c = _localConversations[convIndex];
      _localConversations[convIndex] = ConversationModel(
        id: c.id,
        title: c.title,
        isGroup: c.isGroup,
        avatarUrl: c.avatarUrl,
        participant1Id: c.participant1Id,
        participant2Id: c.participant2Id,
        lastMessagePreview: content,
        lastMessageAt: DateTime.now(),
      );
    }

    return finalMsg;
  }

  // ==========================================
  // SAFETY & MEDIA
  // ==========================================

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

  static final List<SafetyEventModel> _localSafetyEvents = [];

  static Future<List<SafetyEventModel>> getSafetyEvents() async {
    final me = currentUser;
    try {
      final res = await http.get(Uri.parse('$baseUrl/safety/events/${me.id}')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _localSafetyEvents.clear();
        _localSafetyEvents.addAll(list.map((e) => SafetyEventModel.fromJson(e)));
        return _localSafetyEvents;
      }
    } catch (_) {}
    return _localSafetyEvents;
  }

  static Future<void> terminateSession(String device) async {
    final me = currentUser;
    final newEvt = SafetyEventModel(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      eventType: 'SESSION_TERMINATED',
      severity: 'LOW',
      description: 'Remote kill switch activated. Session revoked for $device',
      ipAddress: '127.0.0.1',
      createdAt: DateTime.now(),
    );
    _localSafetyEvents.insert(0, newEvt);
    try {
      await http.post(
        Uri.parse('$baseUrl/safety/terminate-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': me.id, 'deviceName': device}),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  static Future<void> triggerEmergencyCheckin(String status, String note) async {
    final me = currentUser;
    final newEvt = SafetyEventModel(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      eventType: 'EMERGENCY_CHECKIN',
      severity: 'LOW',
      description: 'Emergency Check-in: [$status] $note',
      ipAddress: '127.0.0.1',
      createdAt: DateTime.now(),
    );
    _localSafetyEvents.insert(0, newEvt);
    try {
      await http.post(
        Uri.parse('$baseUrl/safety/emergency-checkin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': me.id, 'status': status, 'note': note}),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  // ==========================================
  // PROFILE MANAGEMENT (EDIT EVERYTHING)
  // ==========================================

  static Future<UserModel> updateProfile({
    String? displayName,
    String? username,
    String? email,
    String? phone,
    String? bio,
    String? avatarUrl,
    String? statusMessage,
    String? themePreference,
    String? appIconPreference,
  }) async {
    final me = currentUser;
    final updated = UserModel(
      id: me.id,
      username: (username != null && username.isNotEmpty) ? username : me.username,
      displayName: (displayName != null && displayName.isNotEmpty) ? displayName : me.displayName,
      email: email ?? me.email,
      phone: phone ?? me.phone,
      bio: bio ?? me.bio,
      avatarUrl: avatarUrl ?? me.avatarUrl,
      statusMessage: statusMessage ?? me.statusMessage,
      safetyScore: me.safetyScore,
      isVerified: me.isVerified,
      isOnline: me.isOnline,
    );

    currentUser = updated;

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/auth/profile/${me.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (displayName != null) 'displayName': displayName,
          if (username != null) 'username': username,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (bio != null) 'bio': bio,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
          if (statusMessage != null) 'statusMessage': statusMessage,
          if (themePreference != null) 'themePreference': themePreference,
          if (appIconPreference != null) 'appIconPreference': appIconPreference,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final serverUser = UserModel.fromJson(jsonDecode(res.body));
        currentUser = serverUser;
        return serverUser;
      }
    } catch (_) {}

    return updated;
  }

  // ==========================================
  // EMERGENCY CONTACT ACCOUNTS
  // ==========================================

  static final List<EmergencyContactModel> _localEmergencyContacts = [
    EmergencyContactModel(
      id: 'em_default_1',
      name: 'Security Ops Guild',
      accountOrEmail: 'secops@chatguard.io',
      relationship: 'Security Team Account',
      phone: '+1 (555) 019-2834',
      notifyOnAlert: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static Future<List<EmergencyContactModel>> getEmergencyContacts() async {
    return List<EmergencyContactModel>.from(_localEmergencyContacts);
  }

  static Future<EmergencyContactModel> addEmergencyContact({
    required String name,
    required String accountOrEmail,
    required String relationship,
    String? phone,
    bool notifyOnAlert = true,
  }) async {
    final contact = EmergencyContactModel(
      id: 'em_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      accountOrEmail: accountOrEmail,
      relationship: relationship,
      phone: phone,
      notifyOnAlert: notifyOnAlert,
      createdAt: DateTime.now(),
    );
    _localEmergencyContacts.add(contact);
    return contact;
  }

  static Future<void> removeEmergencyContact(String id) async {
    _localEmergencyContacts.removeWhere((c) => c.id == id);
  }
}

