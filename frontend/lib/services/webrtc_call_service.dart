import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'call_signaling_service.dart';

enum CallState {
  idle,
  calling,
  ringing,
  connecting,
  connected,
  reconnecting,
  busy,
  failed,
  ended,
}

class WebRtcCallService {
  final CallSignalingService _signaling = CallSignalingService();

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  CallSessionModel? _currentSession;
  CallSessionModel? get currentSession => _currentSession;

  CallState _state = CallState.idle;
  CallState get state => _state;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isCameraOff = false;
  bool get isCameraOff => _isCameraOff;

  bool _isSpeakerOn = true;
  bool get isSpeakerOn => _isSpeakerOn;

  int _durationSeconds = 0;
  int get durationSeconds => _durationSeconds;
  Timer? _durationTimer;
  Timer? _callTimeoutTimer;

  StreamSubscription? _signalSubscription;

  final _stateController = StreamController<CallState>.broadcast();
  Stream<CallState> get onStateChanged => _stateController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get onError => _errorController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get hasLocalStream => _isInitialized && _localStream != null;
  bool get hasRemoteStream => _isInitialized && _remoteStream != null;

  Future<void> initializeRenderers() async {
    if (_isInitialized) return;
    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('[WebRtcCallService] Error initializing renderers: $e');
    }
  }

  void _setState(CallState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);

      if (newState == CallState.connected) {
        _startDurationTimer();
      } else if (newState == CallState.ended || newState == CallState.failed || newState == CallState.busy) {
        _stopDurationTimer();
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _durationSeconds++;
      _stateController.add(_state);
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  /// Start an outgoing call (Audio or Video)
  Future<bool> startCall({
    required String conversationId,
    required String receiverId,
    required String receiverName,
    required bool isVideo,
  }) async {
    await initializeRenderers();
    _setState(CallState.calling);

    try {
      // 1. Create CallSession in backend
      final session = await ApiService.initiateCall(
        conversationId: conversationId,
        receiverId: receiverId,
        receiverName: receiverName,
        callType: isVideo ? 'VIDEO' : 'AUDIO',
      );

      _currentSession = session;

      if (session.status == 'BUSY') {
        _setState(CallState.busy);
        return false;
      }

      _setState(CallState.ringing);

      // Start 45s timeout for unanswered call
      _callTimeoutTimer?.cancel();
      _callTimeoutTimer = Timer(const Duration(seconds: 45), () {
        if (_state == CallState.calling || _state == CallState.ringing) {
          handleTimeout();
        }
      });

      // 2. Acquire local media
      await _getUserMedia(isVideo);

      // 3. Create PeerConnection with coturn STUN/TURN servers
      await _createPeerConnection();

      // 4. Create and send SDP Offer
      final offer = await _peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': isVideo ? 1 : 0,
      });
      await _peerConnection!.setLocalDescription(offer);

      _listenToSignaling();

      _signaling.sendSignal({
        'type': 'WEBRTC_OFFER',
        'callId': session.id,
        'conversationId': conversationId,
        'targetUserId': receiverId,
        'senderId': ApiService.currentUser.id,
        'sdp': offer.sdp,
        'sdpType': offer.type,
      });

      return true;
    } catch (e) {
      debugPrint('[WebRtcCallService] startCall failed: $e');
      _errorController.add('Could not initiate call: $e');
      _setState(CallState.failed);
      return false;
    }
  }

  /// Accept an incoming call
  Future<bool> answerCall(CallSessionModel session) async {
    await initializeRenderers();
    _currentSession = session;
    _setState(CallState.connecting);

    try {
      await ApiService.acceptCall(session.id);

      final isVideo = session.callType.toUpperCase() == 'VIDEO';

      // 1. Acquire local media
      await _getUserMedia(isVideo);

      // 2. Create PeerConnection
      await _createPeerConnection();

      _listenToSignaling();

      // Notify caller that we accepted
      _signaling.sendSignal({
        'type': 'CALL_ACCEPT',
        'callId': session.id,
        'conversationId': session.conversationId,
        'targetUserId': session.callerId,
        'senderId': ApiService.currentUser.id,
      });

      return true;
    } catch (e) {
      debugPrint('[WebRtcCallService] answerCall failed: $e');
      _errorController.add('Failed to answer call: $e');
      _setState(CallState.failed);
      return false;
    }
  }

  /// Reject incoming call
  Future<void> rejectCall(String callId) async {
    try {
      await ApiService.rejectCall(callId);
      if (_currentSession != null) {
        _signaling.sendSignal({
          'type': 'CALL_REJECT',
          'callId': callId,
          'targetUserId': _currentSession!.callerId,
          'senderId': ApiService.currentUser.id,
        });
      }
    } catch (_) {}
    _setState(CallState.ended);
    cleanup();
  }

  /// Cancel outgoing call before answer
  Future<void> cancelCall() async {
    if (_currentSession != null) {
      try {
        await ApiService.cancelCall(_currentSession!.id);
        _signaling.sendSignal({
          'type': 'CALL_CANCEL',
          'callId': _currentSession!.id,
          'targetUserId': _currentSession!.receiverId,
          'senderId': ApiService.currentUser.id,
        });
      } catch (_) {}
    }
    _setState(CallState.ended);
    cleanup();
  }

  /// Unanswered call timeout
  Future<void> handleTimeout() async {
    if (_currentSession != null) {
      try {
        await ApiService.timeoutCall(_currentSession!.id);
        _signaling.sendSignal({
          'type': 'CALL_TIMEOUT',
          'callId': _currentSession!.id,
          'targetUserId': _currentSession!.receiverId,
          'senderId': ApiService.currentUser.id,
        });
      } catch (_) {}
    }
    _setState(CallState.failed);
    cleanup();
  }

  /// End an active call
  Future<void> endCall() async {
    if (_currentSession != null) {
      try {
        await ApiService.endCall(_currentSession!.id, durationSeconds: _durationSeconds);
        final targetId = (_currentSession!.callerId == ApiService.currentUser.id)
            ? _currentSession!.receiverId
            : _currentSession!.callerId;

        _signaling.sendSignal({
          'type': 'CALL_END',
          'callId': _currentSession!.id,
          'targetUserId': targetId,
          'senderId': ApiService.currentUser.id,
        });
      } catch (_) {}
    }
    _setState(CallState.ended);
    cleanup();
  }

  Future<void> _getUserMedia(bool isVideo) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': isVideo
          ? {
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': [],
            }
          : false,
    };

    try {
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = _localStream;
    } catch (e) {
      debugPrint('[WebRtcCallService] Error obtaining user media: $e');
      // If video fails due to no camera, try audio only
      if (isVideo) {
        try {
          _localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
          localRenderer.srcObject = _localStream;
        } catch (audioErr) {
          throw Exception('Microphone permission required or hardware unavailable');
        }
      } else {
        throw Exception('Microphone permission required or hardware unavailable');
      }
    }
  }

  Future<void> _createPeerConnection() async {
    final iceServers = await ApiService.getIceServers();

    final Map<String, dynamic> configuration = {
      'iceServers': iceServers,
      'sdpSemantics': 'unified-plan',
    };

    final Map<String, dynamic> loopbackConstraints = {
      'mandatory': {},
      'optional': [
        {'DtlsSrtpKeyAgreement': true},
      ],
    };

    _peerConnection = await createPeerConnection(configuration, loopbackConstraints);

    // Add local tracks to peer connection
    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    // Handle remote track
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteRenderer.srcObject = _remoteStream;
        _setState(CallState.connected);
      }
    };

    // Handle ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_currentSession != null) {
        final targetId = (_currentSession!.callerId == ApiService.currentUser.id)
            ? _currentSession!.receiverId
            : _currentSession!.callerId;

        _signaling.sendSignal({
          'type': 'ICE_CANDIDATE',
          'callId': _currentSession!.id,
          'targetUserId': targetId,
          'candidate': candidate.toMap(),
        });
      }
    };

    // Handle connection state changes
    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('[WebRtcCallService] ConnectionState: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _setState(CallState.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _setState(CallState.reconnecting);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _setState(CallState.failed);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _setState(CallState.ended);
      }
    };
  }

  void _listenToSignaling() {
    _signalSubscription?.cancel();
    _signalSubscription = _signaling.onSignal.listen((signal) async {
      final type = signal['type'] as String?;
      final callId = signal['callId'] as String?;

      if (_currentSession != null && callId != null && callId != _currentSession!.id) {
        return; // Ignore signals for other calls
      }

      switch (type) {
        case 'CALL_ACCEPT':
          _setState(CallState.connecting);
          break;

        case 'CALL_REJECT':
          _setState(CallState.ended);
          _errorController.add('Call was rejected');
          cleanup();
          break;

        case 'CALL_CANCEL':
          _setState(CallState.ended);
          cleanup();
          break;

        case 'CALL_END':
          _setState(CallState.ended);
          cleanup();
          break;

        case 'CALL_BUSY':
          _setState(CallState.busy);
          _errorController.add('Recipient is busy on another call');
          break;

        case 'CALL_TIMEOUT':
          _setState(CallState.failed);
          _errorController.add('Call was not answered');
          cleanup();
          break;

        case 'WEBRTC_OFFER':
          if (_peerConnection != null) {
            final sdp = signal['sdp'] as String?;
            if (sdp != null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(sdp, 'offer'),
              );
              final answer = await _peerConnection!.createAnswer({
                'offerToReceiveAudio': 1,
                'offerToReceiveVideo': (_currentSession?.callType == 'VIDEO') ? 1 : 0,
              });
              await _peerConnection!.setLocalDescription(answer);

              final targetId = signal['senderId'] as String? ?? _currentSession?.callerId;
              if (targetId != null) {
                _signaling.sendSignal({
                  'type': 'WEBRTC_ANSWER',
                  'callId': _currentSession?.id,
                  'targetUserId': targetId,
                  'senderId': ApiService.currentUser.id,
                  'sdp': answer.sdp,
                  'sdpType': answer.type,
                });
              }
            }
          }
          break;

        case 'WEBRTC_ANSWER':
          if (_peerConnection != null) {
            final sdp = signal['sdp'] as String?;
            if (sdp != null) {
              await _peerConnection!.setRemoteDescription(
                RTCSessionDescription(sdp, 'answer'),
              );
              _setState(CallState.connected);
            }
          }
          break;

        case 'ICE_CANDIDATE':
          if (_peerConnection != null) {
            final candMap = signal['candidate'] as Map<String, dynamic>?;
            if (candMap != null) {
              final candidate = RTCIceCandidate(
                candMap['candidate'],
                candMap['sdpMid'],
                candMap['sdpMLineIndex'],
              );
              await _peerConnection!.addCandidate(candidate);
            }
          }
          break;
      }
    });
  }

  void toggleMicrophone() {
    _isMuted = !_isMuted;
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = !_isMuted;
      }
    }
    _stateController.add(_state);
  }

  void toggleCamera() {
    _isCameraOff = !_isCameraOff;
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        track.enabled = !_isCameraOff;
      }
    }
    _stateController.add(_state);
  }

  Future<void> switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        try {
          await Helper.switchCamera(videoTracks[0]);
        } catch (e) {
          debugPrint('[WebRtcCallService] Switch camera error: $e');
        }
      }
    }
  }

  void toggleSpeakerphone() {
    _isSpeakerOn = !_isSpeakerOn;
    if (_localStream != null) {
      try {
        Helper.setSpeakerphoneOn(_isSpeakerOn);
      } catch (_) {}
    }
    _stateController.add(_state);
  }

  void cleanup() {
    _stopDurationTimer();
    _signalSubscription?.cancel();
    _signalSubscription = null;

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        track.stop();
      }
      _localStream!.dispose();
      _localStream = null;
    }

    if (_remoteStream != null) {
      for (final track in _remoteStream!.getTracks()) {
        track.stop();
      }
      _remoteStream!.dispose();
      _remoteStream = null;
    }

    if (_isInitialized) {
      try {
        localRenderer.srcObject = null;
        remoteRenderer.srcObject = null;
      } catch (_) {}
    }

    _peerConnection?.close();
    _peerConnection?.dispose();
    _peerConnection = null;

    _isMuted = false;
    _isCameraOff = false;
    _isSpeakerOn = true;
    _currentSession = null;
  }

  void dispose() {
    cleanup();
    if (_isInitialized) {
      try {
        localRenderer.dispose();
        remoteRenderer.dispose();
      } catch (_) {}
      _isInitialized = false;
    }
    _stateController.close();
    _errorController.close();
  }
}
