import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/group_icon_helper.dart';

class AvatarBadge extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final bool isOnline;
  final bool showBadge;
  final int? safetyScore;
  final bool isGroup;

  const AvatarBadge({
    super.key,
    this.avatarUrl,
    required this.name,
    this.radius = 24,
    this.isOnline = true,
    this.showBadge = true,
    this.safetyScore,
    this.isGroup = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isGroup) {
      final effectiveUrl = (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
          ? avatarUrl!.trim()
          : GroupIconHelper.defaultIconPreference;

      return _buildBadge(context, effectiveUrl, isGroupMode: true);
    }

    return _buildBadge(context, avatarUrl, isGroupMode: false);
  }

  Widget _buildBadge(BuildContext context, String? url, {required bool isGroupMode}) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : (isGroupMode ? 'G' : '?');

    // Case 1: Preset Icon (e.g. preset:community_guild or preset:cyber_pulse)
    if (url != null && GroupIconHelper.isPreset(url)) {
      final preset = GroupIconHelper.getPreset(url);
      return Stack(
        children: [
          Container(
            width: radius * 2,
            height: radius * 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  preset.primaryColor.withValues(alpha: 0.35),
                  preset.secondaryColor.withValues(alpha: 0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: preset.primaryColor.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Center(
              child: Icon(
                preset.icon,
                color: preset.primaryColor,
                size: radius * 0.95,
              ),
            ),
          ),
          if (showBadge && isOnline && !isGroupMode) _buildOnlineIndicator(context),
        ],
      );
    }

    // Case 2: Image URL or Base64 Data URI
    ImageProvider? imageProvider;
    if (url != null && url.trim().isNotEmpty) {
      final cleanUrl = url.trim();
      if (cleanUrl.startsWith('data:image')) {
        try {
          final commaIdx = cleanUrl.indexOf(',');
          final base64Str = commaIdx != -1 ? cleanUrl.substring(commaIdx + 1) : cleanUrl;
          final bytes = base64Decode(base64Str);
          imageProvider = MemoryImage(bytes);
        } catch (_) {}
      } else if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
        imageProvider = NetworkImage(cleanUrl);
      }
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          backgroundImage: imageProvider,
          child: imageProvider == null
              ? (isGroupMode
                  ? Icon(
                      Icons.groups_rounded,
                      color: Theme.of(context).primaryColor,
                      size: radius * 0.95,
                    )
                  : Text(
                      initials,
                      style: TextStyle(
                        fontSize: radius * 0.75,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ))
              : null,
        ),
        if (showBadge && isOnline && !isGroupMode) _buildOnlineIndicator(context),
      ],
    );
  }

  Widget _buildOnlineIndicator(BuildContext context) {
    return Positioned(
      right: 0,
      bottom: 0,
      child: Container(
        width: radius * 0.65,
        height: radius * 0.65,
        decoration: BoxDecoration(
          color: const Color(0xFF10B981), // Emerald green online
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).scaffoldBackgroundColor,
            width: 2,
          ),
        ),
      ),
    );
  }
}
