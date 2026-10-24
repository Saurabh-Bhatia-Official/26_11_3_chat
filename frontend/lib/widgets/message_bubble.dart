import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/game_assets.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/file_downloader/file_downloader.dart';
import '../services/voice_recorder/voice_recorder.dart';
import 'safety_warning_dialog.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isSelected;
  final VoidCallback? onSelect;
  final Function(String gameType)? onLaunchGame;
  final Function(MessageModel message)? onEdit;
  final Function(MessageModel message)? onDeleteForMe;
  final Function(MessageModel message)? onDeleteForEveryone;
  final bool canDeleteEveryone;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isSelected = false,
    this.onSelect,
    this.onLaunchGame,
    this.onEdit,
    this.onDeleteForMe,
    this.onDeleteForEveryone,
    this.canDeleteEveryone = false,
  });

  void _showDeleteForMeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Color(0xFF06B6D4)),
            SizedBox(width: 8),
            Text('Delete for Me?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This message will be removed from your view only. Other participants will still be able to see it.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF06B6D4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onDeleteForMe?.call(message);
            },
            child: const Text('Delete for Me'),
          ),
        ],
      ),
    );
  }

  void _showDeleteForEveryoneDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Delete for Everyone?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This message will be deleted for all participants in this chat and replaced with a placeholder.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onDeleteForEveryone?.call(message);
            },
            child: const Text('Delete for Everyone'),
          ),
        ],
      ),
    );
  }

  void _showMessageActionsMenu(BuildContext context) {
    if (message.type == MessageType.system || message.isDeleted) return;

    final myId = ApiService.currentUser.id;
    final canEditMsg = isMe && message.canEdit(myId) && onEdit != null;
    final allowDeleteEveryone = (isMe || canDeleteEveryone) && onDeleteForEveryone != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF131D2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (canEditMsg)
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF06B6D4)),
                title: const Text('Edit Message', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Available for 5 minutes after sending', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onEdit?.call(message);
                },
              ),
            if (onDeleteForMe != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFF59E0B)),
                title: const Text('Delete for Me', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Hides message from your device only', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showDeleteForMeDialog(context);
                },
              ),
            if (allowDeleteEveryone)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
                title: const Text('Delete for Everyone', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                subtitle: const Text('Removes message for all participants', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showDeleteForEveryoneDialog(context);
                },
              ),
            if (message.type == MessageType.image && message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Color(0xFF10B981)),
                title: const Text('Download Image', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Save image file to your device', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _downloadImage(context);
                },
              ),
            if (message.type == MessageType.file && message.mediaUrl != null && message.mediaUrl!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.download_rounded, color: Color(0xFF10B981)),
                title: const Text('Download Document', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Save document to your device', style: TextStyle(color: Colors.white54, fontSize: 11)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _downloadDocument(context);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

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

  void _downloadImage(BuildContext context) {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) return;
    final filename = 'image_${message.id.substring(0, message.id.length > 8 ? 8 : message.id.length)}.png';
    FileDownloader.downloadUrl(message.mediaUrl!, filename);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading $filename...'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _downloadDocument(BuildContext context) {
    if (message.mediaUrl == null || message.mediaUrl!.isEmpty) return;
    final filename = message.content.isNotEmpty ? message.content : 'document_${message.id.substring(0, message.id.length > 8 ? 8 : message.id.length)}';
    FileDownloader.downloadUrl(message.mediaUrl!, filename);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading $filename...'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                color: Colors.black87,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildImageWidget(imageUrl),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              left: 16,
              child: Row(
                children: [
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF06B6D4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Download', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () => _downloadImage(context),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: Colors.white24,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageContainer(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: const BoxConstraints(maxHeight: 220),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => _showFullScreenImage(context, message.mediaUrl!),
              child: _buildImageWidget(message.mediaUrl!),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Tooltip(
                message: 'Download Image',
                child: Material(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _downloadImage(context),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.download_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, Color textColor) {
    final fileName = message.content.isNotEmpty ? message.content : 'Document';
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';

    Color iconColor;
    IconData iconData;

    switch (ext) {
      case 'pdf':
        iconColor = const Color(0xFFEF4444);
        iconData = Icons.picture_as_pdf;
        break;
      case 'doc':
      case 'docx':
        iconColor = const Color(0xFF3B82F6);
        iconData = Icons.description;
        break;
      case 'xls':
      case 'xlsx':
      case 'csv':
        iconColor = const Color(0xFF10B981);
        iconData = Icons.table_chart;
        break;
      case 'ppt':
      case 'pptx':
        iconColor = const Color(0xFFF97316);
        iconData = Icons.slideshow;
        break;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        iconColor = const Color(0xFFF59E0B);
        iconData = Icons.folder_zip;
        break;
      case 'txt':
      case 'json':
      case 'html':
      case 'dart':
      case 'java':
      case 'py':
      case 'js':
        iconColor = const Color(0xFF06B6D4);
        iconData = Icons.code;
        break;
      default:
        iconColor = const Color(0xFF8B5CF6);
        iconData = Icons.insert_drive_file;
    }

    String sizeStr = '';
    if (message.mediaBytes != null && message.mediaBytes! > 0) {
      final kb = message.mediaBytes! / 1024;
      sizeStr = kb > 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '${kb.toStringAsFixed(1)} KB';
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _downloadDocument(context),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: iconColor.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (ext.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            ext.toUpperCase(),
                            style: TextStyle(color: iconColor, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (sizeStr.isNotEmpty)
                        Text(
                          '$sizeStr • ',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      const Text(
                        'Tap to download',
                        style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.download_rounded, color: iconColor, size: 22),
              tooltip: 'Download file',
              onPressed: () => _downloadDocument(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(String mediaUrl) {
    if (mediaUrl.startsWith('data:image/')) {
      try {
        final commaIdx = mediaUrl.indexOf(',');
        final base64Str = commaIdx != -1 ? mediaUrl.substring(commaIdx + 1) : mediaUrl;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => const Padding(
            padding: EdgeInsets.all(16),
            child: Icon(Icons.broken_image, color: Colors.white54, size: 36),
          ),
        );
      } catch (_) {}
    }
    return Image.network(
      mediaUrl,
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
      errorBuilder: (context, error, stackTrace) => const Padding(
        padding: EdgeInsets.all(16),
        child: Icon(Icons.broken_image, color: Colors.white54, size: 36),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  message.content,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat.jm().format(message.createdAt),
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      );
    }

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
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75 > 500
                    ? 500
                    : MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4, bottom: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            isMe ? 'You (${message.senderName})' : message.senderName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMe ? Colors.white60 : primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
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
                      if (!message.isDeleted) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _showMessageActionsMenu(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Icon(
                              Icons.more_horiz,
                              size: 14,
                              color: isMe ? Colors.white54 : primaryColor.withOpacity(0.7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onSelect,
                  onLongPress: () => _showMessageActionsMenu(context),
                  onSecondaryTap: () => _showMessageActionsMenu(context),
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
                    if (message.isDeleted)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block, size: 14, color: textColor.withOpacity(0.6)),
                            const SizedBox(width: 6),
                            Text(
                              'This message was deleted',
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                color: textColor.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
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
                      _buildImageContainer(context),

                    // Document File Attachment Content
                    if (message.type == MessageType.file &&
                        message.mediaUrl != null)
                      _buildDocumentCard(context, textColor),

                    // Real Interactive Voice Note Player
                    if (message.type == MessageType.audio)
                      VoiceMessagePlayer(
                        audioUrl: message.mediaUrl,
                        isMe: isMe,
                        primaryColor: primaryColor,
                        textColor: textColor,
                      ),

                    // Live PlayTogether Game Move Card
                    if (message.content.contains('[PLAY_TOGETHER:'))
                      _buildLiveGameCard(context),

                    // Game Invitation Card
                    if (message.type == MessageType.gameInvite && !message.content.contains('[PLAY_TOGETHER:'))
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withOpacity(0.12),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.sports_esports, color: Color(0xFF8B5CF6), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'PlayTogether Challenge! ⚔️',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Choose a game to play together directly in this chat:',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _buildCloudGameLaunchTile(
                                  title: 'Chess',
                                  gameType: 'CHESS',
                                  imageUrl: GameCloudAssets.chessThumb,
                                  accentColor: const Color(0xFF8B5CF6),
                                  icon: Icons.grid_4x4,
                                ),
                                const SizedBox(width: 8),
                                _buildCloudGameLaunchTile(
                                  title: 'Ludo',
                                  gameType: 'LUDO',
                                  imageUrl: GameCloudAssets.ludoThumb,
                                  accentColor: const Color(0xFF10B981),
                                  icon: Icons.casino,
                                ),
                                const SizedBox(width: 8),
                                _buildCloudGameLaunchTile(
                                  title: 'Snakes',
                                  gameType: 'SNAKES_AND_LADDERS',
                                  imageUrl: GameCloudAssets.snakesLaddersThumb,
                                  accentColor: const Color(0xFFF59E0B),
                                  icon: Icons.stairs,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                    // Text Content with Link Interceptor
                    if (message.content.isNotEmpty && message.type != MessageType.file && !(message.type == MessageType.image && (message.content == 'Shared an image' || message.content.isEmpty)))
                      _buildContentText(context, textColor),
                  ],

                  const SizedBox(height: 4),
                  // Timestamp & Status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (message.isEdited && !message.isDeleted) ...[
                        Text(
                          'Edited • ',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      ],
                      Text(
                        DateFormat.jm().format(message.createdAt),
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                      if (isMe && !message.isDeleted) ...[
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
                  ],
                ),
              ),
            ),
          ],
        ),
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

  Map<String, dynamic>? _extractGameState(String raw) {
    const prefix = '[PLAY_TOGETHER:';
    final startIdx = raw.indexOf(prefix);
    if (startIdx == -1) return null;
    final endIdx = raw.lastIndexOf(']');
    if (endIdx == -1 || endIdx <= startIdx) return null;
    final jsonStr = raw.substring(startIdx + prefix.length, endIdx);
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Widget _buildLiveGameCard(BuildContext context) {
    final state = _extractGameState(message.content);
    final gameType = state?['game'] as String? ?? _extractGameType(message.content);
    final rawSummary = _formatMessageContent(message.content);

    final myUsername = ApiService.currentUser.username;
    final currentTurnUser = state?['currentTurnUsername'] as String? ?? '';
    final starterUser = state?['player1Username'] as String? ?? '';
    final winner = state?['winner'] as String?;

    // The player who starts the game is ALWAYS the first to start
    final activeTurnUser = currentTurnUser.isNotEmpty
        ? currentTurnUser
        : (starterUser.isNotEmpty ? starterUser : (message.senderId == ApiService.currentUser.id ? myUsername : ''));

    final bool isMyTurn = activeTurnUser.isNotEmpty && myUsername.isNotEmpty
        ? activeTurnUser.toLowerCase() == myUsername.toLowerCase()
        : (message.senderId == ApiService.currentUser.id);

    Color themeColor;
    IconData gameIcon;
    String gameTitle;
    if (gameType == 'LUDO') {
      themeColor = const Color(0xFF10B981);
      gameIcon = Icons.casino;
      gameTitle = 'Ludo 🎲';
    } else if (gameType == 'SNAKES_AND_LADDERS') {
      themeColor = const Color(0xFFF59E0B);
      gameIcon = Icons.stairs;
      gameTitle = 'Snakes & Ladders 🪜';
    } else {
      themeColor = const Color(0xFF8B5CF6);
      gameIcon = Icons.grid_4x4;
      gameTitle = 'Chess ♟️';
    }

    final bool isStopped = state?['status'] == 'STOPPED' || winner == 'STOPPED';
    final String stoppedBy = state?['stoppedBy'] as String? ?? '';

    String statusText = rawSummary;
    if (isStopped) {
      statusText = "⏹️ Game was stopped by @${stoppedBy.isNotEmpty ? stoppedBy : 'player'}.";
    } else if (winner != null && winner.isNotEmpty) {
      statusText = "🏆 Winner: @$winner!";
    } else if (activeTurnUser.isNotEmpty) {
      if (isMyTurn) {
        statusText = "👉 Your turn to play (@$myUsername)";
      } else {
        statusText = "⏳ Waiting for @$activeTurnUser's turn";
      }
    }

    return Container(
      width: 290,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStopped ? Colors.redAccent.withOpacity(0.5) : (isMyTurn ? const Color(0xFF10B981) : themeColor.withOpacity(0.5)),
          width: isMyTurn ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (isStopped ? Colors.redAccent : (isMyTurn ? const Color(0xFF10B981) : themeColor)).withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cloud Game Banner Image with Overlay
          Stack(
            children: [
              CloudGameImage(
                imageUrl: GameCloudAssets.getBanner(gameType),
                height: 75,
                width: double.infinity,
                borderRadius: BorderRadius.circular(10),
                fallbackIcon: gameIcon,
                fallbackColor: themeColor,
              ),
              Container(
                height: 75,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.65),
                      Colors.transparent,
                      Colors.black.withOpacity(0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: themeColor, width: 1.2),
                      ),
                      child: Icon(gameIcon, color: themeColor, size: 13),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        gameTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isStopped
                            ? const Color(0xFFEF4444).withOpacity(0.85)
                            : ((winner != null
                                    ? const Color(0xFFFBBF24)
                                    : (isMyTurn ? const Color(0xFF10B981) : Colors.amber))
                                .withOpacity(0.85)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isStopped
                            ? 'Stopped'
                            : (winner != null
                                ? 'Ended'
                                : (isMyTurn ? 'Your Turn' : 'Waiting')),
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Middle row: Game status description
          Text(
            statusText,
            style: TextStyle(
              color: isStopped ? Colors.redAccent : (isMyTurn ? Colors.white : Colors.white70),
              fontSize: 12,
              fontWeight: (isMyTurn || isStopped) ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          if (rawSummary.isNotEmpty && rawSummary != statusText) ...[
            const SizedBox(height: 3),
            Text(
              rawSummary,
              style: const TextStyle(color: Colors.white38, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),

          // Bottom Action Button
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isStopped
                    ? const Color(0xFF06B6D4)
                    : (isMyTurn
                        ? const Color(0xFF10B981)
                        : (winner != null ? const Color(0xFF334155) : themeColor)),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: Icon(
                isStopped
                    ? Icons.sports_esports
                    : (winner != null ? Icons.visibility : (isMyTurn ? Icons.play_arrow : Icons.sports_esports)),
                size: 15,
              ),
              label: Text(
                isStopped
                    ? 'Start New Match'
                    : (winner != null
                        ? 'View Game Results'
                        : (isMyTurn ? 'Play Your Turn (@$myUsername)' : 'View Game Board')),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () => onLaunchGame?.call(gameType),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudGameLaunchTile({
    required String title,
    required String gameType,
    required String imageUrl,
    required Color accentColor,
    required IconData icon,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => onLaunchGame?.call(gameType),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accentColor.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                child: CloudGameImage(
                  imageUrl: imageUrl,
                  height: 52,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  fallbackIcon: icon,
                  fallbackColor: accentColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMessageContent(String raw) {
    if (raw.contains('[PLAY_TOGETHER:')) {
      final endIdx = raw.indexOf(']');
      if (endIdx != -1 && endIdx + 1 < raw.length) {
        return raw.substring(endIdx + 1).trim();
      }
      return '🎮 Game move updated';
    }
    return raw;
  }

  String _extractGameType(String raw) {
    if (raw.contains('"game":"CHESS"')) return 'CHESS';
    if (raw.contains('"game":"LUDO"')) return 'LUDO';
    if (raw.contains('"game":"SNAKES_AND_LADDERS"')) return 'SNAKES_AND_LADDERS';
    return 'CHESS';
  }

  Widget _buildContentText(BuildContext context, Color textColor) {
    if (message.content.contains('[PLAY_TOGETHER:')) {
      return const SizedBox.shrink();
    }
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

class VoiceMessagePlayer extends StatefulWidget {
  final String? audioUrl;
  final bool isMe;
  final Color primaryColor;
  final Color textColor;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.isMe,
    required this.primaryColor,
    required this.textColor,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = const Duration(seconds: 4);

  @override
  void dispose() {
    if (_isPlaying) {
      VoiceRecorderService.stopAudio();
    }
    super.dispose();
  }

  void _togglePlay() {
    if (widget.audioUrl == null || widget.audioUrl!.isEmpty) return;

    if (_isPlaying) {
      VoiceRecorderService.pauseAudio();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isPlaying = true);
      VoiceRecorderService.playAudio(
        widget.audioUrl!,
        onEnded: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _position = Duration.zero;
            });
          }
        },
        onProgress: (pos, dur) {
          if (mounted) {
            setState(() {
              _position = pos;
              if (dur.inMilliseconds > 0) _duration = dur;
            });
          }
        },
      );
    }
  }

  String _format(Duration d) {
    final m = (d.inSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: widget.primaryColor,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _togglePlay,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: SizedBox(
                  width: 110,
                  height: 24,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(14, (i) {
                      final waveHeight = _isPlaying
                          ? ((i + (_position.inMilliseconds ~/ 150)) % 5 + 1) * 3.8 + 4
                          : (i % 3 + 1) * 5.0 + 4;
                      final isPlayed = (i / 14.0) <= progress;
                      return Container(
                        width: 3.5,
                        height: waveHeight,
                        decoration: BoxDecoration(
                          color: isPlayed
                              ? widget.primaryColor
                              : (widget.isMe ? Colors.white38 : Colors.white24),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _isPlaying ? _format(_position) : _format(_duration),
                style: TextStyle(
                  color: widget.textColor.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (_isPlaying) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
