import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';

class CallSignalingService {
  static final CallSignalingService _instance = CallSignalingService._internal();
  factory CallSignalingService() => _instance;
  CallSignalingService._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  final _signalStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onSignal => _signalStreamController.stream;

  String? _currentUserId;
  String? _activeConversationId;

  bool get isConnected => _isConnected;

  void init(String userId, {String? conversationId}) {
    _currentUserId = userId;
    _activeConversationId = conversationId;
    _connect();
  }

  void updateConversation(String? conversationId) {
    _activeConversationId = conversationId;
    if (_isConnected && conversationId != null) {
      _subscribe('/topic/call.$conversationId');
    }
  }

  void _connect() {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      final wsUrl = _getWebSocketUrl();
      debugPrint('[CallSignaling] Connecting to $wsUrl');

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _channelSub = _channel!.stream.listen(
        _onMessageReceived,
        onDone: _onDisconnected,
        onError: (err) {
          debugPrint('[CallSignaling] WebSocket error: $err');
          _onDisconnected();
        },
        cancelOnError: true,
      );

      // Send STOMP CONNECT frame
      _sendStompFrame('CONNECT', {
        'accept-version': '1.1,1.2',
        'heart-beat': '10000,10000',
      });
    } catch (e) {
      debugPrint('[CallSignaling] Connect exception: $e');
      _onDisconnected();
    }
  }

  String _getWebSocketUrl() {
    final base = ApiService.baseUrl;
    String hostUrl;
    if (base.startsWith('https://')) {
      hostUrl = base.replaceFirst('https://', 'wss://');
    } else if (base.startsWith('http://')) {
      hostUrl = base.replaceFirst('http://', 'ws://');
    } else {
      hostUrl = 'ws://$base';
    }

    if (hostUrl.endsWith('/api')) {
      hostUrl = hostUrl.substring(0, hostUrl.length - 4);
    }
    return '$hostUrl/ws-raw';
  }

  void _onMessageReceived(dynamic raw) {
    final message = raw.toString();

    if (message.startsWith('CONNECTED')) {
      debugPrint('[CallSignaling] STOMP connected');
      _isConnected = true;
      _isConnecting = false;

      // Start keep-alive heartbeat
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (_isConnected && _channel != null) {
          try {
            _channel!.sink.add('\n');
          } catch (_) {}
        }
      });

      // Subscribe to user's personal calling topic
      if (_currentUserId != null) {
        _subscribe('/topic/call.user.$_currentUserId');
      }

      // Subscribe to active conversation topic
      if (_activeConversationId != null) {
        _subscribe('/topic/call.$_activeConversationId');
      }
    } else if (message.startsWith('MESSAGE')) {
      final bodyIndex = message.indexOf('\n\n');
      if (bodyIndex != -1) {
        var body = message.substring(bodyIndex + 2);
        if (body.endsWith('\x00')) {
          body = body.substring(0, body.length - 1);
        }
        try {
          final json = jsonDecode(body.trim());
          if (json is Map<String, dynamic>) {
            _signalStreamController.add(json);
          }
        } catch (e) {
          debugPrint('[CallSignaling] JSON parse error: $e');
        }
      }
    }
  }

  void _subscribe(String destination) {
    final subId = 'sub-${destination.hashCode}';
    _sendStompFrame('SUBSCRIBE', {
      'id': subId,
      'destination': destination,
    });
  }

  void _sendStompFrame(String command, Map<String, String> headers, [String body = '']) {
    final buffer = StringBuffer();
    buffer.write('$command\n');
    for (final entry in headers.entries) {
      buffer.write('${entry.key}:${entry.value}\n');
    }
    buffer.write('\n');
    buffer.write(body);
    buffer.write('\x00');

    try {
      _channel?.sink.add(buffer.toString());
    } catch (e) {
      debugPrint('[CallSignaling] Error sending STOMP frame: $e');
    }
  }

  void sendSignal(Map<String, dynamic> signal) {
    if (_isConnected) {
      final jsonBody = jsonEncode(signal);
      _sendStompFrame('SEND', {
        'destination': '/app/call.signal',
        'content-type': 'application/json',
      }, jsonBody);
    }
  }

  void _onDisconnected() {
    _isConnected = false;
    _isConnecting = false;
    _heartbeatTimer?.cancel();
    _channelSub?.cancel();
    _channel = null;

    // Retry connection after 3 seconds
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (_currentUserId != null && !_isConnected) {
        _connect();
      }
    });
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channelSub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }
}
