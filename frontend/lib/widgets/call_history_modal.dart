import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import 'avatar_badge.dart';
import 'glass_container.dart';

class CallHistoryModal extends StatefulWidget {
  final Function(String conversationId, String otherId, String otherName, bool isVideo)? onCallBack;

  const CallHistoryModal({super.key, this.onCallBack});

  @override
  State<CallHistoryModal> createState() => _CallHistoryModalState();
}

class _CallHistoryModalState extends State<CallHistoryModal> {
  bool _isLoading = true;
  List<CallSessionModel> _history = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await ApiService.getCallHistory();
      if (mounted) {
        setState(() {
          _history = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load call history: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) {
      return '${m}m ${s}s';
    }
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final me = ApiService.currentUser;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        height: 560,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06B6D4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.call_rounded, color: Color(0xFF06B6D4), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Call History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Recent self-hosted WebRTC voice & video calls',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF06B6D4)),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 36),
                                const SizedBox(height: 12),
                                Text(_error!, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _fetchHistory,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF06B6D4)),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _history.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.phone_missed_outlined, size: 48, color: Colors.white.withOpacity(0.2)),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'No call history yet',
                                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Start an encrypted audio or video call with anyone.',
                                    style: TextStyle(color: Colors.white54, fontSize: 12),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _history.length,
                              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                              itemBuilder: (context, index) {
                                final call = _history[index];
                                final isCaller = call.callerId == me.id;
                                final otherName = isCaller ? call.receiverName : call.callerName;
                                final isVideo = call.callType.toUpperCase() == 'VIDEO';
                                final isMissedOrRejected = call.status == 'REJECTED' ||
                                    call.status == 'MISSED' ||
                                    call.status == 'CANCELLED' ||
                                    call.status == 'BUSY';

                                IconData statusIcon;
                                Color statusColor;

                                if (isMissedOrRejected) {
                                  statusIcon = Icons.call_missed;
                                  statusColor = const Color(0xFFEF4444);
                                } else if (isCaller) {
                                  statusIcon = Icons.call_made;
                                  statusColor = const Color(0xFF10B981);
                                } else {
                                  statusIcon = Icons.call_received;
                                  statusColor = const Color(0xFF06B6D4);
                                }

                                final dateStr = DateFormat('MMM d, h:mm a').format(call.startedAt);

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  leading: AvatarBadge(
                                    avatarUrl: isCaller ? null : call.callerAvatarUrl,
                                    name: otherName,
                                    radius: 20,
                                  ),
                                  title: Text(
                                    otherName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Row(
                                    children: [
                                      Icon(statusIcon, color: statusColor, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        isVideo ? 'Video' : 'Voice',
                                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '• $dateStr',
                                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                                      ),
                                      if (call.durationSeconds > 0) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '• ${_formatDuration(call.durationSeconds)}',
                                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      isVideo ? Icons.videocam_outlined : Icons.phone_outlined,
                                      color: const Color(0xFF06B6D4),
                                      size: 20,
                                    ),
                                    tooltip: isVideo ? 'Start Video Call' : 'Start Audio Call',
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                      if (widget.onCallBack != null) {
                                        final otherId = isCaller ? call.receiverId : call.callerId;
                                        widget.onCallBack!(call.conversationId, otherId, otherName, isVideo);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
