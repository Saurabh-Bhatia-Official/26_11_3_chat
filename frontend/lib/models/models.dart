import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String bio;
  final String statusMessage;
  final int safetyScore;
  final String role; // ADMIN, MODERATOR, MEMBER
  final bool isAdmin;
  final bool isVerified;
  final bool isOnline;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.bio = '',
    this.statusMessage = 'Available',
    this.safetyScore = 100,
    this.role = 'MEMBER',
    bool? isAdmin,
    this.isVerified = false,
    this.isOnline = true,
  }) : isAdmin = isAdmin ?? (role == 'ADMIN');

  bool get isAdministrator => role == 'ADMIN' || isAdmin;
  bool get isModerator => role == 'MODERATOR' || isAdministrator;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final parsedRole = (json['role'] ?? (json['isAdmin'] == true ? 'ADMIN' : 'MEMBER')).toString().toUpperCase();
    return UserModel(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      displayName: json['displayName'] ?? json['username'] ?? 'User',
      email: json['email'],
      avatarUrl: json['avatarUrl'],
      bio: json['bio'] ?? '',
      statusMessage: json['statusMessage'] ?? 'Available',
      safetyScore: json['safetyScore'] ?? 100,
      role: parsedRole,
      isAdmin: json['isAdmin'] ?? (parsedRole == 'ADMIN'),
      isVerified: json['isVerified'] ?? false,
      isOnline: json['isOnline'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'email': email,
    'role': role,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'statusMessage': statusMessage,
    'safetyScore': safetyScore,
    'isAdmin': isAdmin,
    'isVerified': isVerified,
    'isOnline': isOnline,
  };
}

class ConversationModel {
  final String id;
  final String title;
  final bool isGroup;
  final String? avatarUrl;
  final String? lastMessagePreview;
  final DateTime lastMessageAt;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.title,
    this.isGroup = false,
    this.avatarUrl,
    this.lastMessagePreview,
    required this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Chat',
      isGroup: json['isGroup'] ?? false,
      avatarUrl: json['avatarUrl'],
      lastMessagePreview: json['lastMessagePreview'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt']) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

enum MessageType { text, image, audio, video, file, gameInvite, system }

class MessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final MessageType type;
  final String? mediaUrl;
  final int? mediaBytes;
  final bool safetyFlagged;
  final String deliveryStatus;
  final DateTime createdAt;
  final Map<String, int> reactions; // emoji -> count

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.type = MessageType.text,
    this.mediaUrl,
    this.mediaBytes,
    this.safetyFlagged = false,
    this.deliveryStatus = 'DELIVERED',
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
        case 'GAME_INVITE': return MessageType.gameInvite;
        case 'SYSTEM': return MessageType.system;
        default: return MessageType.text;
      }
    }

    return MessageModel(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? 'Member',
      content: json['content'] ?? '',
      type: parseType(json['type']),
      mediaUrl: json['mediaUrl'],
      mediaBytes: json['mediaBytes'],
      safetyFlagged: json['safetyFlagged'] ?? false,
      deliveryStatus: json['deliveryStatus'] ?? 'DELIVERED',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      reactions: {},
    );
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
