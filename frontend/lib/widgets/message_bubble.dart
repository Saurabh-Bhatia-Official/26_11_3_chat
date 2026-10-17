import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'safety_warning_dialog.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isSelected;
  final VoidCallback? onSelect;
  final Function(String gameType)? onLaunchGame;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isSelected = false,
    this.onSelect,
    this.onLaunchGame,
  });

  void _handleLinkClick(BuildContext context, String url) async {
    final report = await ApiService.scanUrl(url);
    final riskScore = report['riskScore'] as int? ?? 0;
    final isSuspicious = report['isSuspicious'] as bool? ?? false;
    final warnings = List<String>.from(report['warnings'] ?? []);

    if (isSuspicious && context.mounted) {
      showDialog(
        context: context,
        builder: (_) => SafetyWarningDialog(
          url: url,
          riskScore: riskScore,
          warnings: warnings,
          onProceedAnyway: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Opening $url in protected sandbox...')),
            );
          },
        ),
      );
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verified safe URL: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.primaryColor;
    final bubbleColor = isMe
        ? primaryColor.withValues(alpha: 0.9)
        : (isDark ? const Color(0xFF1E293B) : Colors.white);
    final textColor = isMe
        ? Colors.white
        : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A));

    final effectiveAvatarUrl = message.senderAvatarUrl ??
        (isMe ? ApiService.currentUser.avatarUrl : null);

    final avatarWidget = Tooltip(
      message: message.senderName,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: primaryColor.withValues(alpha: 0.2),
        backgroundImage: (effectiveAvatarUrl != null && effectiveAvatarUrl.isNotEmpty)
            ? NetworkImage(effectiveAvatarUrl)
            : null,
        child: (effectiveAvatarUrl == null || effectiveAvatarUrl.isEmpty)
            ? Text(
                message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryColor),
              )
            : null,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            avatarWidget,
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75 > 500
                  ? 500
                  : MediaQuery.of(context).size.width * 0.75,
            ),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isMe ? 'You (${message.senderName})' : message.senderName,
                        style: TextStyle(
                          color: isMe ? Colors.white60 : primaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SELECTED',
                            style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onSelect,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border: isSelected
                          ? Border.all(color: const Color(0xFF06B6D4), width: 2.5)
                          : null,
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: const Color(0xFF06B6D4).withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                      ],
                    ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Safety Flag Banner
                    if (message.safetyFlagged)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFEF4444).withOpacity(0.5)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield_outlined,
                                color: Color(0xFFEF4444), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Smart Guardian Flagged Link',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Media Content
                    if (message.type == MessageType.image &&
                        message.mediaUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: Image.network(
                            message.mediaUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                height: 160,
                                color: Colors.black12,
                                child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2)),
                              );
                            },
                          ),
                        ),
                      ),

                    // Voice Note UI
                    if (message.type == MessageType.audio)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: primaryColor,
                              child: const Icon(Icons.play_arrow,
                                  color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 8),
                            // Simulated audio wave bars
                            Row(
                              children: List.generate(
                                14,
                                (i) => Container(
                                  width: 3,
                                  height: (i % 3 + 1) * 6.0 + 4,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1.5),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? Colors.white70
                                        : theme.colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '0:24',
                              style: TextStyle(
                                  color: textColor.withOpacity(0.7),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),

                    // Game Invitation Card
                    if (message.type == MessageType.gameInvite)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.sports_esports,
                                    color: Color(0xFF8B5CF6), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'PlayTogether Challenge! ⚔️',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Join Chess, Ludo, or Snakes & Ladders directly inside this conversation.',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8B5CF6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.grid_4x4, size: 14),
                                  label: const Text('Chess',
                                      style: TextStyle(fontSize: 12)),
                                  onPressed: () => onLaunchGame?.call('CHESS'),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.casino, size: 14),
                                  label: const Text('Ludo',
                                      style: TextStyle(fontSize: 12)),
                                  onPressed: () => onLaunchGame?.call('LUDO'),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                  ),
                                  icon: const Icon(Icons.stairs, size: 14),
                                  label: const Text('Snakes & Ladders',
                                      style: TextStyle(fontSize: 12)),
                                  onPressed: () => onLaunchGame
                                      ?.call('SNAKES_AND_LADDERS'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Text Content with Link Interceptor
                    if (message.content.isNotEmpty)
                      _buildContentText(context, textColor),

                    const SizedBox(height: 4),
                    // Timestamp & Status
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          DateFormat.jm().format(message.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.done_all,
                            size: 13,
                            color: message.deliveryStatus == 'READ'
                                ? const Color(0xFF38BDF8)
                                : textColor.withOpacity(0.6),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            avatarWidget,
          ],
        ],
      ),
    );
  }

  Widget _buildContentText(BuildContext context, Color textColor) {
    final text = message.content;
    final urlRegex = RegExp(r'https?://[^\s]+');
    final match = urlRegex.firstMatch(text);

    if (match == null) {
      return Text(
        text,
        style: TextStyle(color: textColor, fontSize: 14),
      );
    }

    final before = text.substring(0, match.start);
    final url = match.group(0)!;
    final after = text.substring(match.end);

    return RichText(
      text: TextSpan(
        style: TextStyle(color: textColor, fontSize: 14),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InkWell(
              onTap: () => _handleLinkClick(context, url),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: message.safetyFlagged
                      ? const Color(0xFFEF4444).withOpacity(0.2)
                      : Colors.blue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  url,
                  style: TextStyle(
                    color: message.safetyFlagged
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF60A5FA),
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
    );
  }
}
