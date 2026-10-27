import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/models.dart';
import '../services/webrtc_call_service.dart';
import 'glass_container.dart';

class CallModal extends StatefulWidget {
  final String title;
  final String avatarUrl;
  final bool isVideo;
  final VoidCallback? onEndCall;
  final void Function(int durationSeconds)? onEndCallWithDuration;
  final WebRtcCallService? callService;
  final CallSessionModel? session;
  final bool isIncoming;

  const CallModal({
    super.key,
    required this.title,
    required this.avatarUrl,
    this.isVideo = true,
    this.onEndCall,
    this.onEndCallWithDuration,
    this.callService,
    this.session,
    this.isIncoming = false,
  });

  @override
  State<CallModal> createState() => _CallModalState();
}

class _CallModalState extends State<CallModal> with SingleTickerProviderStateMixin {
  late final WebRtcCallService _callService;
  bool _ownsService = false;
  StreamSubscription? _stateSub;
  StreamSubscription? _errorSub;

  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isSpeakerOn = true;
  CallState _callState = CallState.calling;
  int _callDurationSeconds = 0;
  String? _errorMessage;
  Timer? _closeDelayTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.callService != null) {
      _callService = widget.callService!;
      _ownsService = false;
    } else {
      _callService = WebRtcCallService();
      _ownsService = true;
      _initDefaultCall();
    }

    _callState = _callService.state;
    _isMuted = _callService.isMuted;
    _isCameraOff = _callService.isCameraOff;
    _isSpeakerOn = _callService.isSpeakerOn;
    _callDurationSeconds = _callService.durationSeconds;

    _stateSub = _callService.onStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _callState = state;
          _isMuted = _callService.isMuted;
          _isCameraOff = _callService.isCameraOff;
          _isSpeakerOn = _callService.isSpeakerOn;
          _callDurationSeconds = _callService.durationSeconds;
        });

        if (state == CallState.ended || state == CallState.busy || state == CallState.failed) {
          _closeDelayTimer?.cancel();
          _closeDelayTimer = Timer(const Duration(milliseconds: 1800), () {
            if (mounted) _finishCall();
          });
        }
      }
    });

    _errorSub = _callService.onError.listen((err) {
      if (mounted) {
        setState(() => _errorMessage = err);
      }
    });
  }

  Future<void> _initDefaultCall() async {
    await _callService.initializeRenderers();
    if (widget.session != null) {
      if (widget.isIncoming) {
        await _callService.answerCall(widget.session!);
      } else {
        await _callService.startCall(
          conversationId: widget.session!.conversationId,
          receiverId: widget.session!.receiverId,
          receiverName: widget.title,
          isVideo: widget.isVideo,
          existingSession: widget.session,
        );
      }
    }
  }

  @override
  void dispose() {
    _closeDelayTimer?.cancel();
    _pulseController.dispose();
    _stateSub?.cancel();
    _errorSub?.cancel();
    if (_ownsService) {
      _callService.dispose();
    }
    super.dispose();
  }

  void _finishCall() {
    if (widget.onEndCallWithDuration != null) {
      widget.onEndCallWithDuration!(_callDurationSeconds);
    } else if (widget.onEndCall != null) {
      widget.onEndCall!();
    }
  }

  void _handleEndCallPressed() {
    _callService.endCall();
    _finishCall();
  }

  void _toggleMic() {
    _callService.toggleMicrophone();
    setState(() => _isMuted = _callService.isMuted);
  }

  void _toggleCamera() {
    _callService.toggleCamera();
    setState(() => _isCameraOff = _callService.isCameraOff);
  }

  void _switchCamera() {
    _callService.switchCamera();
  }

  void _toggleSpeaker() {
    _callService.toggleSpeakerphone();
    setState(() => _isSpeakerOn = _callService.isSpeakerOn);
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _statusLabel {
    if (_errorMessage != null) return _errorMessage!;
    switch (_callState) {
      case CallState.calling:
        return 'Calling...';
      case CallState.ringing:
        return 'Ringing...';
      case CallState.connecting:
        return 'Connecting WebRTC...';
      case CallState.connected:
        return _formatDuration(_callDurationSeconds);
      case CallState.reconnecting:
        return 'Reconnecting...';
      case CallState.busy:
        return 'User is Busy';
      case CallState.failed:
        return 'Call Failed';
      case CallState.ended:
        return 'Call Ended';
      case CallState.idle:
        return 'Initializing...';
    }
  }

  Color get _statusColor {
    switch (_callState) {
      case CallState.connected:
        return const Color(0xFF10B981);
      case CallState.calling:
      case CallState.ringing:
      case CallState.connecting:
        return const Color(0xFF06B6D4);
      case CallState.reconnecting:
        return const Color(0xFFF59E0B);
      case CallState.busy:
      case CallState.failed:
      case CallState.ended:
        return const Color(0xFFEF4444);
      case CallState.idle:
        return Colors.white70;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasRemoteVideo = widget.isVideo &&
        _callState == CallState.connected &&
        _callService.hasRemoteStream;

    final bool hasLocalVideo = widget.isVideo &&
        !_isCameraOff &&
        _callService.hasLocalStream;

    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Background / Remote Media View
            Positioned.fill(
              child: hasRemoteVideo
                  ? RTCVideoView(
                      _callService.remoteRenderer,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : _buildAvatarAndAmbientWave(),
            ),

            // 2. Local PIP Camera Preview (for video calls)
            if (widget.isVideo)
              Positioned(
                top: 70,
                right: 16,
                child: GestureDetector(
                  onTap: _switchCamera,
                  child: Container(
                    width: 110,
                    height: 155,
                    decoration: BoxDecoration(
                      color: const Color(0xFF131D2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: hasLocalVideo
                        ? Stack(
                            children: [
                              Positioned.fill(
                                child: RTCVideoView(
                                  _callService.localRenderer,
                                  mirror: true,
                                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                                ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 14),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_off, color: Colors.white54, size: 24),
                                SizedBox(height: 6),
                                Text('Camera Off', style: TextStyle(color: Colors.white54, fontSize: 10)),
                              ],
                            ),
                          ),
                  ),
                ),
              ),

            // 3. Top Security & Connection Bar
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock, color: Color(0xFF10B981), size: 14),
                        const SizedBox(width: 8),
                        Text(
                          widget.isVideo ? 'WebRTC P2P Video • Coturn Relay' : 'Secure P2P Voice • Coturn Relay',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _callState == CallState.connected ? Icons.network_cell : Icons.network_check,
                          color: _statusColor,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _callState == CallState.connected ? 'HD 1080p' : 'Signaling',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 4. Bottom Controls Bar
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: GlassContainer(
                borderRadius: 32,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute / Unmute Button
                    IconButton(
                      icon: Icon(
                        _isMuted ? Icons.mic_off : Icons.mic,
                        color: _isMuted ? const Color(0xFFEF4444) : Colors.white,
                      ),
                      onPressed: _toggleMic,
                      tooltip: _isMuted ? 'Unmute Microphone' : 'Mute Microphone',
                    ),

                    // Camera On / Off Button (for Video Calls)
                    if (widget.isVideo)
                      IconButton(
                        icon: Icon(
                          _isCameraOff ? Icons.videocam_off : Icons.videocam,
                          color: _isCameraOff ? const Color(0xFFEF4444) : Colors.white,
                        ),
                        onPressed: _toggleCamera,
                        tooltip: _isCameraOff ? 'Turn Camera On' : 'Turn Camera Off',
                      ),

                    // Switch Camera (for Video Calls)
                    if (widget.isVideo)
                      IconButton(
                        icon: const Icon(Icons.switch_camera, color: Colors.white),
                        onPressed: _switchCamera,
                        tooltip: 'Switch Camera',
                      ),

                    // Speakerphone Toggle
                    IconButton(
                      icon: Icon(
                        _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        color: _isSpeakerOn ? const Color(0xFF06B6D4) : Colors.white54,
                      ),
                      onPressed: _toggleSpeaker,
                      tooltip: _isSpeakerOn ? 'Speaker On' : 'Earpiece Mode',
                    ),

                    // End Call Action Button
                    FloatingActionButton(
                      heroTag: 'modal_end_call_btn',
                      backgroundColor: const Color(0xFFEF4444),
                      onPressed: _handleEndCallPressed,
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

  Widget _buildAvatarAndAmbientWave() {
    final bool isCaller = !widget.isIncoming;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF060B14)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _statusColor.withOpacity(0.35),
                      blurRadius: 36,
                      spreadRadius: 6,
                    ),
                  ],
                  border: Border.all(color: _statusColor.withOpacity(0.6), width: 2),
                ),
                child: CircleAvatar(
                  radius: 64,
                  backgroundImage: widget.avatarUrl.isNotEmpty ? NetworkImage(widget.avatarUrl) : null,
                  child: widget.avatarUrl.isEmpty
                      ? Text(
                          widget.title.isNotEmpty ? widget.title[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 36, color: Colors.white),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _statusColor.withOpacity(0.5), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isVideo ? Icons.videocam : Icons.phone,
                    size: 15,
                    color: _statusColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      color: _statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (isCaller && (_callState == CallState.calling || _callState == CallState.ringing)) ...[
              const SizedBox(height: 16),
              const Text(
                'Waiting for recipient to answer...',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
