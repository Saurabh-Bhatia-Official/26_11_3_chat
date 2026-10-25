import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String bio;
  final String statusMessage;
  final int safetyScore;
  final bool isVerified;
  final bool isOnline;
  final bool isPrivate;
  final String appIconPreference;
  final String themePreference;
  final String? softwareName;
  final String? customLogoUrl;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.bio = '',
    this.statusMessage = 'Available',
    this.safetyScore = 100,
    this.isVerified = false,
    this.isOnline = true,
    this.isPrivate = false,
    this.appIconPreference = 'cyber_pulse',
    this.themePreference = 'obsidianCyber',
    this.softwareName,
    this.customLogoUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? json['username'] ?? 'User',
      email: json['email'],
      phone: json['phone'],
      avatarUrl: json['avatarUrl'],
      bio: json['bio'] ?? '',
      statusMessage: json['statusMessage'] ?? 'Available',
      safetyScore: json['safetyScore'] ?? 100,
      isVerified: json['isVerified'] ?? false,
      isOnline: json['isOnline'] ?? true,
      isPrivate: json['isPrivate'] == true ||
          json['private'] == true ||
          json['is_private'] == true ||
          json['isPrivate']?.toString() == 'true' ||
          json['private']?.toString() == 'true' ||
          json['is_private']?.toString() == '1' ||
          json['isPrivate'] == 1,
      appIconPreference: json['appIconPreference'] ?? 'cyber_pulse',
      themePreference: json['themePreference'] ?? 'obsidianCyber',
      softwareName: json['softwareName'],
      customLogoUrl: json['customLogoUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'email': email,
    'phone': phone,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'statusMessage': statusMessage,
    'safetyScore': safetyScore,
    'isVerified': isVerified,
    'isOnline': isOnline,
    'isPrivate': isPrivate,
    'private': isPrivate,
    'appIconPreference': appIconPreference,
    'themePreference': themePreference,
    'softwareName': softwareName,
    'customLogoUrl': customLogoUrl,
  };
}

class ConversationModel {
  final String id;
  final String title;
  final String? description;
  final bool isGroup;
  final String? avatarUrl;
  final String? participant1Id;
  final String? participant1Name;
  final String? participant1Avatar;
  final String? participant2Id;
  final String? participant2Name;
  final String? participant2Avatar;
  final List<String> groupAdminIds;
  final List<String> participantIds;
  final String? lastMessagePreview;
  final DateTime lastMessageAt;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.title,
    this.description,
    this.isGroup = false,
    this.avatarUrl,
    this.participant1Id,
    this.participant1Name,
    this.participant1Avatar,
    this.participant2Id,
    this.participant2Name,
    this.participant2Avatar,
    this.groupAdminIds = const [],
    this.participantIds = const [],
    this.lastMessagePreview,
    required this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.isNotEmpty) {
        return val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return ConversationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Chat',
      description: json['description'],
      isGroup: json['isGroup'] ?? false,
      avatarUrl: json['avatarUrl'],
      participant1Id: json['participant1Id'],
      participant1Name: json['participant1Name'],
      participant1Avatar: json['participant1Avatar'],
      participant2Id: json['participant2Id'],
      participant2Name: json['participant2Name'],
      participant2Avatar: json['participant2Avatar'],
      groupAdminIds: parseStringList(json['groupAdminIds']),
      participantIds: parseStringList(json['participantIds']),
      lastMessagePreview: json['lastMessagePreview'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt']) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }

  bool isAdmin(String userId) {
    return groupAdminIds.contains(userId);
  }

  String getTitleForUser(UserModel me) {
    if (isGroup) return title;
    if (participant1Id != null && participant2Id != null) {
      if (me.id == participant1Id && participant2Name != null && participant2Name!.isNotEmpty) {
        return participant2Name!;
      }
      if (me.id == participant2Id && participant1Name != null && participant1Name!.isNotEmpty) {
        return participant1Name!;
      }
    }
    final myName = me.displayName.toLowerCase().trim();
    final myUser = me.username.toLowerCase().trim();
    final t = title.toLowerCase().trim();
    if (t == myName || t == myUser) {
      if (participant1Name != null && participant1Name!.isNotEmpty && participant1Name!.toLowerCase().trim() != myName) {
        return participant1Name!;
      }
      if (participant2Name != null && participant2Name!.isNotEmpty && participant2Name!.toLowerCase().trim() != myName) {
        return participant2Name!;
      }
    }
    return title;
  }

  String? getAvatarForUser(UserModel me) {
    if (isGroup) return avatarUrl;
    if (participant1Id != null && participant2Id != null) {
      if (me.id == participant1Id && participant2Avatar != null && participant2Avatar!.isNotEmpty) {
        return participant2Avatar;
      }
      if (me.id == participant2Id && participant1Avatar != null && participant1Avatar!.isNotEmpty) {
        return participant1Avatar;
      }
    }
    return avatarUrl;
  }

  String getOtherUsername(UserModel me, [Map<String, UserModel>? userCache]) {
    if (isGroup) return '';
    final otherId = (me.id == participant1Id) ? participant2Id : (me.id == participant2Id ? participant1Id : null);
    if (otherId != null && userCache != null && userCache.containsKey(otherId)) {
      return userCache[otherId]!.username;
    }
    final otherName = getTitleForUser(me);
    if (userCache != null) {
      for (final u in userCache.values) {
        if (u.id == otherId ||
            u.displayName.toLowerCase() == otherName.toLowerCase() ||
            u.username.toLowerCase() == otherName.toLowerCase()) {
          return u.username;
        }
      }
    }
    return otherName.toLowerCase().replaceAll(' ', '_').replaceAll('@', '');
  }
}

enum MessageType { text, image, audio, video, file, gameInvite, system }

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
  final String content;
  final MessageType type;
  final String? mediaUrl;
  final int? mediaBytes;
  final bool safetyFlagged;
  final String deliveryStatus;
  final bool isDeleted;
  final bool isEdited;
  final DateTime? editedAt;
  final List<String> deletedForUserIds;
  final DateTime createdAt;
  final Map<String, int> reactions; // emoji -> count

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
    required this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    this.mediaBytes,
    this.safetyFlagged = false,
    this.deliveryStatus = 'DELIVERED',
    this.isDeleted = false,
    this.isEdited = false,
    this.editedAt,
    this.deletedForUserIds = const [],
    required this.createdAt,
    this.reactions = const {},
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    MessageType parseType(String? t) {
      switch (t?.toUpperCase()) {
        case 'IMAGE': return MessageType.image;
        case 'AUDIO': return MessageType.audio;
        case 'VIDEO': return MessageType.video;
        case 'FILE': return MessageType.file;
        case 'GAME_INVITE':
        case 'GAMEINVITE': return MessageType.gameInvite;
        case 'SYSTEM': return MessageType.system;
        default: return MessageType.text;
      }
    }

    List<String> parseStringList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      if (val is String && val.isNotEmpty) {
        return val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    return MessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Member',
      senderAvatarUrl: json['senderAvatarUrl'],
      content: json['content'] ?? '',
      type: parseType(json['type']),
      mediaUrl: json['mediaUrl'],
      mediaBytes: json['mediaBytes'],
      safetyFlagged: json['safetyFlagged'] ?? false,
      deliveryStatus: json['deliveryStatus'] ?? 'DELIVERED',
      isDeleted: json['isDeleted'] ?? false,
      isEdited: json['isEdited'] ?? false,
      editedAt: json['editedAt'] != null ? DateTime.tryParse(json['editedAt']) : null,
      deletedForUserIds: parseStringList(json['deletedForUserIds']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      reactions: {},
    );
  }

  bool canEdit(String currentUserId) {
    if (senderId != currentUserId) return false;
    if (isDeleted) return false;
    // Exactly 5 minutes limit (300 seconds)
    final diff = DateTime.now().difference(createdAt);
    return diff.inSeconds <= 300;
  }

  bool isDeletedForMe(String currentUserId) {
    return deletedForUserIds.contains(currentUserId);
  }
}

class SafetyEventModel {
  final String id;
  final String eventType;
  final String severity; // LOW, MEDIUM, HIGH, CRITICAL
  final String description;
  final String? ipAddress;
  final DateTime createdAt;

  SafetyEventModel({
    required this.id,
    required this.eventType,
    required this.severity,
    required this.description,
    this.ipAddress,
    required this.createdAt,
  });

  factory SafetyEventModel.fromJson(Map<String, dynamic> json) {
    return SafetyEventModel(
      id: json['id'] ?? '',
      eventType: json['eventType'] ?? 'SECURITY_ALERT',
      severity: json['severity'] ?? 'LOW',
      description: json['description'] ?? '',
      ipAddress: json['ipAddress'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Color getSeverityColor() {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return const Color(0xFFEF4444);
      case 'HIGH': return const Color(0xFFF97316);
      case 'MEDIUM': return const Color(0xFFFBBF24);
      case 'LOW':
      default: return const Color(0xFF10B981);
    }
  }
}

class GameRoomModel {
  final String id;
  final String conversationId;
  final String gameType; // CHESS, LUDO, SNAKES_AND_LADDERS
  final String status;   // WAITING, ACTIVE, FINISHED
  final String playerWhiteId;
  final String? playerBlackId;
  final String turnUserId;
  final String? winnerUserId;
  final Map<String, dynamic> state;
  final List<dynamic> moveHistory;

  GameRoomModel({
    required this.id,
    required this.conversationId,
    required this.gameType,
    required this.status,
    required this.playerWhiteId,
    this.playerBlackId,
    required this.turnUserId,
    this.winnerUserId,
    required this.state,
    this.moveHistory = const [],
  });
}

class EmergencyContactModel {
  final String id;
  final String name;
  final String accountOrEmail;
  final String relationship;
  final String? phone;
  final bool notifyOnAlert;
  final DateTime createdAt;

  EmergencyContactModel({
    required this.id,
    required this.name,
    required this.accountOrEmail,
    required this.relationship,
    this.phone,
    this.notifyOnAlert = true,
    required this.createdAt,
  });

  factory EmergencyContactModel.fromJson(Map<String, dynamic> json) {
    return EmergencyContactModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      accountOrEmail: json['accountOrEmail'] ?? '',
      relationship: json['relationship'] ?? 'Trusted Contact',
      phone: json['phone'],
      notifyOnAlert: json['notifyOnAlert'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'accountOrEmail': accountOrEmail,
    'relationship': relationship,
    'phone': phone,
    'notifyOnAlert': notifyOnAlert,
    'createdAt': createdAt.toIso8601String(),
  };
}

class GroupMemberModel {
  final String userId;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isAdmin;
  final DateTime joinedAt;

  GroupMemberModel({
    required this.userId,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isAdmin = false,
    required this.joinedAt,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      userId: json['userId'] ?? json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? json['username'] ?? 'Member',
      avatarUrl: json['avatarUrl'],
      isAdmin: json['isAdmin'] ?? json['admin'] ?? false,
      joinedAt: json['joinedAt'] != null
          ? DateTime.tryParse(json['joinedAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CallSessionModel {
  final String id;
  final String conversationId;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final String receiverId;
  final String receiverName;
  final String callType; // AUDIO, VIDEO
  final String status;   // RINGING, ACCEPTED, REJECTED, ENDED, MISSED
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  CallSessionModel({
    required this.id,
    required this.conversationId,
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    required this.receiverId,
    required this.receiverName,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
  });

  factory CallSessionModel.fromJson(Map<String, dynamic> json) {
    return CallSessionModel(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      callerId: json['callerId'] ?? '',
      callerName: json['callerName'] ?? 'Caller',
      callerAvatarUrl: json['callerAvatarUrl'],
      receiverId: json['receiverId'] ?? '',
      receiverName: json['receiverName'] ?? 'Receiver',
      callType: json['callType'] ?? 'VIDEO',
      status: json['status'] ?? 'RINGING',
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt']) ?? DateTime.now()
          : DateTime.now(),
      endedAt: json['endedAt'] != null ? DateTime.tryParse(json['endedAt']) : null,
      durationSeconds: json['durationSeconds'] ?? 0,
    );
  }
}

