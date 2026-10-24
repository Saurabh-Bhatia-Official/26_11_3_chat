import 'dart:async';
import 'package:flutter/material.dart';
import 'glass_container.dart';

class CallModal extends StatefulWidget {
  final String title;
  final String avatarUrl;
  final bool isVideo;
  final VoidCallback? onEndCall;
  final void Function(int durationSeconds)? onEndCallWithDuration;

  const CallModal({
    super.key,
    required this.title,
    required this.avatarUrl,
    this.isVideo = true,
    this.onEndCall,
    this.onEndCallWithDuration,
  });

  @override
  State<CallModal> createState() => _CallModalState();
}

class _CallModalState extends State<CallModal> {
  bool isConnecting = true;
  bool isMuted = false;
  bool isCameraOff = false;
  bool isSpeakerOn = true;
  bool isScreenSharing = false;
  int callDurationSeconds = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    // Simulate initial signaling / ringing state then connect
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => isConnecting = false);
        timer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (mounted) {
            setState(() => callDurationSeconds++);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _finishCall() {
    if (widget.onEndCallWithDuration != null) {
      widget.onEndCallWithDuration!(callDurationSeconds);
    } else if (widget.onEndCall != null) {
      widget.onEndCall!();
    }
  }

  String formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Stack(
          children: [
            // Video / Ambient background
            Positioned.fill(
              child: widget.isVideo && !isCameraOff
                  ? Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 64,
                              backgroundImage: NetworkImage(widget.avatarUrl),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isConnecting ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fiber_manual_record,
                                    color: isConnecting ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isConnecting ? 'Ringing / Connecting...' : formatDuration(callDurationSeconds),
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  if (!isConnecting) ...[
                                    const SizedBox(width: 8),
                                    const Text('• 24ms • HD 1080p', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isConnecting ? const Color(0xFF06B6D4) : const Color(0xFF10B981)).withOpacity(0.3),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 56,
                              backgroundImage: NetworkImage(widget.avatarUrl),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.isVideo ? Icons.videocam : Icons.phone,
                                size: 16,
                                color: isConnecting ? const Color(0xFF06B6D4) : const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isConnecting ? 'Calling • Ringing...' : formatDuration(callDurationSeconds),
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),

            // Top Status Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          widget.isVideo ? 'WebRTC Encrypted Video' : 'Secure Encrypted Call',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  GlassContainer(
                    padding: const EdgeInsets.all(8),
                    child: const Row(
                      children: [
                        Icon(Icons.network_cell, color: Color(0xFF10B981), size: 18),
                        SizedBox(width: 4),
                        Text('Stable HD', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Controls Bar
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: GlassContainer(
                borderRadius: 28,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(isMuted ? Icons.mic_off : Icons.mic,
                          color: isMuted ? const Color(0xFFEF4444) : Colors.white),
                      onPressed: () => setState(() => isMuted = !isMuted),
                      tooltip: isMuted ? 'Unmute Mic' : 'Mute Audio',
                    ),
                    if (widget.isVideo)
                      IconButton(
                        icon: Icon(isCameraOff ? Icons.videocam_off : Icons.videocam,
                            color: isCameraOff ? const Color(0xFFEF4444) : Colors.white),
                        onPressed: () => setState(() => isCameraOff = !isCameraOff),
                        tooltip: isCameraOff ? 'Turn Camera On' : 'Turn Camera Off',
                      ),
                    IconButton(
                      icon: Icon(isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                          color: isSpeakerOn ? Colors.white : Colors.white54),
                      onPressed: () => setState(() => isSpeakerOn = !isSpeakerOn),
                      tooltip: isSpeakerOn ? 'Speaker On' : 'Speaker Off',
                    ),
                    if (widget.isVideo)
                      IconButton(
                        icon: Icon(isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                            color: isScreenSharing ? const Color(0xFF3B82F6) : Colors.white),
                        onPressed: () => setState(() => isScreenSharing = !isScreenSharing),
                        tooltip: 'Share Screen',
                      ),
                    FloatingActionButton(
                      backgroundColor: const Color(0xFFEF4444),
                      onPressed: _finishCall,
                      mini: true,
                      child: const Icon(Icons.call_end, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
