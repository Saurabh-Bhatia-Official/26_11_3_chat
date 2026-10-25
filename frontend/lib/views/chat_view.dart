import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/file_picker_helper.dart';
import 'package:intl/intl.dart';
import '../constants/game_assets.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/voice_recorder/voice_recorder.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/call_modal.dart';
import '../widgets/glass_container.dart';
import '../widgets/message_bubble.dart';
import '../widgets/network_status_banner.dart';
import '../widgets/camera_capture_dialog.dart';
import '../widgets/group_icon_picker_modal.dart';
import '../services/permission_service.dart';
import 'games/chess_game_view.dart';
import 'games/ludo_game_view.dart';
import 'games/snakes_ladders_view.dart';

class ChatView extends StatefulWidget {
  final ConversationModel conversation;
  final VoidCallback? onActivity;
  final VoidCallback? onDeleteChat;

  const ChatView({
    super.key,
    required this.conversation,
    this.onActivity,
    this.onDeleteChat,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  bool _isPolling = false;

  // Real-time PlayTogether Game State
  String? _activeGame; // CHESS, LUDO, SNAKES_AND_LADDERS, or null
  Map<String, dynamic>? _activeGameState;
  bool _isGameMinimized = false;
  int _lastProcessedGameTimestamp = 0;
  Timer? _pollingTimer;

  bool _isInCall = false;
  bool _isCallVideo = true;
  CallSessionModel? _activeCallSession;
  MessageModel? _editingMessage;
  MessageModel? _selectedMessage;

  // Pending image picker state (without auto-uploading)
  Uint8List? _pendingImageBytes;
  String? _pendingImageName;
  int? _pendingImageSize;

  // Pending document picker state (without auto-uploading)
  Uint8List? _pendingDocumentBytes;
  String? _pendingDocumentName;
  int? _pendingDocumentSize;
  bool _isUploading = false;

  // Real Microphone Voice Recording State
  bool _isRecordingVoice = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  RecordedAudio? _pendingVoiceAudio;
  bool _isPreviewPlaying = false;
  Duration _previewPosition = Duration.zero;
  bool _isSendingVoice = false;

  // Independent UI session draft cache per conversation
  static final Map<String, String> _conversationDrafts = {};

  void _onDraftChanged() {
    _conversationDrafts[widget.conversation.id] = _textController.text;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final savedDraft = _conversationDrafts[widget.conversation.id];
    if (savedDraft != null && savedDraft.isNotEmpty) {
      _textController.text = savedDraft;
    }
    _textController.addListener(_onDraftChanged);
    _loadMessages();
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _pollMessages();
    }
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _conversationDrafts[oldWidget.conversation.id] = _textController.text;
      _textController.text = _conversationDrafts[widget.conversation.id] ?? '';
      _loadMessages();
      _startPolling();
      _activeGame = null;
      _activeGameState = null;
      _lastProcessedGameTimestamp = 0;
      _isGameMinimized = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.removeListener(_onDraftChanged);
    _pollingTimer?.cancel();
    _recordingTimer?.cancel();
    VoiceRecorderService.stopAudio();
    VoiceRecorderService.cancelRecording();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    // Snappy 1000ms polling for instant real-time auto sync
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      _pollMessages();
    });
  }

  void _pollMessages() async {
    if (!mounted || _isPolling) return;
    _isPolling = true;
    try {
      final msgs = await ApiService.getMessages(widget.conversation.id);
      if (!mounted) return;

      _syncGameFromMessages(msgs);

      bool hasChanges = msgs.length != _messages.length;
      if (!hasChanges) {
        for (int i = 0; i < msgs.length; i++) {
          final a = msgs[i];
          final b = _messages[i];
          if (a.id != b.id ||
              a.content != b.content ||
              a.mediaUrl != b.mediaUrl ||
              a.deliveryStatus != b.deliveryStatus ||
              a.isDeleted != b.isDeleted ||
              a.isEdited != b.isEdited) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges) {
        final hadMessagesBefore = _messages.isNotEmpty;
        final lastIdBefore = hadMessagesBefore ? _messages.last.id : '';
        setState(() {
          _messages = List<MessageModel>.from(msgs);
        });

        // Automatically scroll to bottom if new incoming message was received
        if (!hadMessagesBefore || (msgs.isNotEmpty && msgs.last.id != lastIdBefore)) {
          _scrollToBottom();
        }

        widget.onActivity?.call();
      }
    } catch (_) {
      // Ignore background network transient errors
    } finally {
      _isPolling = false;
    }
  }

  String? _messagesError;

  void _loadMessages() async {
    setState(() {
      _isLoading = true;
      _messagesError = null;
    });
    try {
      final msgs = await ApiService.getMessages(widget.conversation.id);
      if (mounted) {
        _syncGameFromMessages(msgs);
        setState(() {
          _messages = List<MessageModel>.from(msgs);
          _messagesError = null;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messagesError = e.toString().replaceAll('Exception: ', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  void _syncGameFromMessages(List<MessageModel> msgs) {
    for (int i = msgs.length - 1; i >= 0; i--) {
      final m = msgs[i];
      final content = m.content;
      const prefix = '[PLAY_TOGETHER:';
      final startIdx = content.indexOf(prefix);
      if (startIdx != -1) {
        final endIdx = content.lastIndexOf(']');
        if (endIdx != -1 && endIdx > startIdx) {
          final jsonStr = content.substring(startIdx + prefix.length, endIdx);
          try {
            final Map<String, dynamic> state = jsonDecode(jsonStr);
            final int timestamp = (state['timestamp'] as num?)?.toInt() ?? 0;
            if (state['status'] == 'STOPPED' || state['winner'] == 'STOPPED') {
              if (timestamp >= _lastProcessedGameTimestamp) {
                _lastProcessedGameTimestamp = timestamp;
                if (mounted) {
                  setState(() {
                    _activeGame = null;
                    _activeGameState = null;
                    _isGameMinimized = false;
                  });
                }
              }
              break;
            }
            if (timestamp >= _lastProcessedGameTimestamp || _activeGameState == null) {
              _lastProcessedGameTimestamp = timestamp;
              final game = state['game'] as String?;
              if (game != null) {
                if (mounted) {
                  setState(() {
                    _activeGame = game;
                    _activeGameState = state;
                  });
                }
              }
            }
            break;
          } catch (e) {
            debugPrint('Error parsing game state: $e');
          }
        }
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<MessageModel> _deduplicateMessages(List<MessageModel> list) {
    final seen = <String>{};
    final res = <MessageModel>[];
    for (final m in list) {
      if (!seen.add(m.id)) continue;
      // Only fuzzy match against temporary optimistic local client messages
      final hasDup = res.any((ex) =>
          (ex.id.startsWith('msg_') || m.id.startsWith('msg_')) &&
          ex.senderId == m.senderId &&
          ex.content == m.content &&
          ex.createdAt.difference(m.createdAt).abs().inSeconds <= 3);
      if (!hasDup) {
        res.add(m);
      }
    }
    return res;
  }

  List<MessageModel> get _displayMessages {
    final dedup = _deduplicateMessages(_messages);
    // Find the latest game message index to collapse all turn-by-turn messages into one single live game card
    int latestGameIdx = -1;
    for (int i = dedup.length - 1; i >= 0; i--) {
      final c = dedup[i].content;
      if (c.contains('[PLAY_TOGETHER:') || dedup[i].type == MessageType.gameInvite) {
        latestGameIdx = i;
        break;
      }
    }

    if (latestGameIdx == -1) return dedup;

    final filtered = <MessageModel>[];
    for (int i = 0; i < dedup.length; i++) {
      final c = dedup[i].content;
      final isGame = c.contains('[PLAY_TOGETHER:') || dedup[i].type == MessageType.gameInvite;
      if (!isGame || i == latestGameIdx) {
        filtered.add(dedup[i]);
      }
    }
    return filtered;
  }

  void _sendMessage({MessageType type = MessageType.text, String? mediaUrl, String? customContent}) async {
    final text = customContent ?? _textController.text.trim();
    if (text.isEmpty && mediaUrl == null) return;

    final content = text.isNotEmpty ? text : (type == MessageType.image ? "Shared an image" : "Shared media");
    if (customContent == null) {
      _textController.clear();
    }

    try {
      final sent = await ApiService.sendMessage(
        widget.conversation.id,
        content,
        type: type,
        mediaUrl: mediaUrl,
      );

      if (mounted) {
        setState(() {
          final exists = _messages.any((m) =>
              m.id == sent.id ||
              ((m.id.startsWith('msg_') || sent.id.startsWith('msg_')) &&
                  m.senderId == sent.senderId &&
                  m.content == sent.content &&
                  m.createdAt.difference(sent.createdAt).abs().inSeconds <= 3));
          if (!exists) {
            _messages.add(sent);
          }
        });
        _scrollToBottom();
        widget.onActivity?.call();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  errorMsg.contains('Internet') ? Icons.wifi_off_rounded : Icons.dns_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMsg)),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onGameMoveMade(Map<String, dynamic> newState) {
    _activeGameState = newState;
    _lastProcessedGameTimestamp = (newState['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch;
    final jsonStr = jsonEncode(newState);
    String summary = 'Move made';
    final g = newState['game'] ?? _activeGame;
    final turnUser = newState['currentTurnUsername'] ?? '';
    final turnSuffix = turnUser.toString().isNotEmpty ? " • Turn: @$turnUser" : "";

    if (g == 'CHESS') {
      summary = 'Chess: ${newState['statusMessage'] ?? 'Move completed'}$turnSuffix';
    } else if (g == 'LUDO') {
      summary = 'Ludo: Rolled ${newState['currentDice']}, ${newState['currentTurn']}\'s turn$turnSuffix';
    } else if (g == 'SNAKES_AND_LADDERS') {
      summary = 'Snakes & Ladders: Rolled ${newState['lastDice']}, ${newState['gameStatus'] ?? newState['status'] ?? 'Move completed'}$turnSuffix';
    }

    _sendMessage(
      type: MessageType.gameInvite,
      customContent: '🎮 [PLAY_TOGETHER:$jsonStr] $summary',
    );
  }

  void _capturePhotoWithCamera() async {
    final result = await CameraCaptureHelper.captureWithCamera(
      context,
      onFallbackGallery: _pickImageFromDevice,
    );
    if (result != null && mounted) {
      setState(() {
        _pendingImageBytes = result.bytes;
        _pendingImageName = result.filename;
        _pendingImageSize = result.bytes.length;
      });
    }
  }

  void _pickImageFromDevice() async {
    final hasPerm = await PermissionService.requestPermission(
      context,
      AppPermissionType.photos,
      showRationale: true,
    );
    if (!hasPerm) return;

    try {
      final picked = await FilePickerHelper.pickImage();
      if (picked != null && mounted) {
        setState(() {
          _pendingImageBytes = picked.bytes;
          _pendingImageName = picked.name;
          _pendingImageSize = picked.size;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _discardPendingImage() {
    setState(() {
      _pendingImageBytes = null;
      _pendingImageName = null;
      _pendingImageSize = null;
    });
  }

  void _pickDocumentFromDevice() async {
    final hasPerm = await PermissionService.requestPermission(
      context,
      AppPermissionType.photos,
      showRationale: true,
    );
    if (!hasPerm) return;

    try {
      final picked = await FilePickerHelper.pickDocument();
      if (picked != null && mounted) {
        setState(() {
          _pendingDocumentBytes = picked.bytes;
          _pendingDocumentName = picked.name;
          _pendingDocumentSize = picked.size;
        });
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick document: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  void _discardPendingDocument() {
    setState(() {
      _pendingDocumentBytes = null;
      _pendingDocumentName = null;
      _pendingDocumentSize = null;
    });
  }

  void _startVoiceRecording() async {
    // Check browser support
    if (!VoiceRecorderService.isSupported && kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone recording is not supported in this browser. Try Chrome, Edge, or Firefox.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    try {
      _discardPendingVoice();
      _discardPendingImage();

      setState(() {
        _isRecordingVoice = true;
        _recordingSeconds = 0;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _isRecordingVoice) {
          setState(() => _recordingSeconds++);
        }
      });

      await VoiceRecorderService.startRecording();
    } catch (e) {
      _recordingTimer?.cancel();
      if (mounted) {
        setState(() => _isRecordingVoice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _stopVoiceRecording() async {
    _recordingTimer?.cancel();
    try {
      final audio = await VoiceRecorderService.stopRecording();
      if (mounted) {
        setState(() {
          _isRecordingVoice = false;
          _pendingVoiceAudio = audio;
        });

        if (audio == null || audio.bytes.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recording was too short or empty. Please try again.'),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRecordingVoice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to finalize voice recording: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await VoiceRecorderService.cancelRecording();
    if (mounted) {
      setState(() {
        _isRecordingVoice = false;
        _recordingSeconds = 0;
      });
    }
  }

  void _togglePreviewPlay() {
    if (_pendingVoiceAudio == null) return;

    if (_isPreviewPlaying) {
      VoiceRecorderService.pauseAudio();
      setState(() => _isPreviewPlaying = false);
    } else {
      final url = _pendingVoiceAudio!.blobUrl ??
          'data:${_pendingVoiceAudio!.mimeType};base64,${base64Encode(_pendingVoiceAudio!.bytes)}';
      setState(() => _isPreviewPlaying = true);
      VoiceRecorderService.playAudio(
        url,
        onEnded: () {
          if (mounted) {
            setState(() {
              _isPreviewPlaying = false;
              _previewPosition = Duration.zero;
            });
          }
        },
        onProgress: (pos, dur) {
          if (mounted) {
            setState(() {
              _previewPosition = pos;
            });
          }
        },
      );
    }
  }

  void _discardPendingVoice() {
    VoiceRecorderService.stopAudio();
    setState(() {
      _pendingVoiceAudio = null;
      _isPreviewPlaying = false;
      _previewPosition = Duration.zero;
    });
  }

  void _pickAudioFileFromDevice() async {
    final hasPerm = await PermissionService.requestPermission(
      context,
      AppPermissionType.photos,
      showRationale: true,
    );
    if (!hasPerm) return;

    try {
      final picked = await FilePickerHelper.pickAudio();
      if (picked != null && picked.bytes.isNotEmpty && mounted) {
        final ext = picked.extension ?? 'webm';
        final mime = ext == 'mp3'
            ? 'audio/mp3'
            : (ext == 'wav'
                ? 'audio/wav'
                : (ext == 'ogg' ? 'audio/ogg' : 'audio/webm'));
        setState(() {
          _pendingVoiceAudio = RecordedAudio(
            bytes: picked.bytes,
            mimeType: mime,
            durationSeconds: 4,
          );
        });
      }
    } catch (e) {
      debugPrint('Error picking audio file: $e');
    }
  }

  void _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _pendingImageBytes == null && _pendingVoiceAudio == null && _pendingDocumentBytes == null) return;

    // Handle Editing Existing Message (Enforces 5-minute limit)
    if (_editingMessage != null) {
      if (text.isEmpty) return;
      final msgToEdit = _editingMessage!;
      if (!msgToEdit.canEdit(ApiService.currentUser.id)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot edit message: 5-minute time limit has expired.'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
        setState(() {
          _editingMessage = null;
          _textController.clear();
        });
        return;
      }

      setState(() => _editingMessage = null);
      _textController.clear();

      try {
        final updated = await ApiService.editMessage(msgToEdit.id, text);
        if (mounted && updated != null) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == updated.id);
            if (idx != -1) {
              _messages[idx] = updated;
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error editing message: $e'), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
      return;
    }

    // 1. Send Actual Voice Message
    if (_pendingVoiceAudio != null) {
      setState(() => _isSendingVoice = true);
      final audio = _pendingVoiceAudio!;
      final caption = text;

      _textController.clear();
      _discardPendingVoice();

      try {
        final ext = audio.mimeType.contains('ogg')
            ? 'ogg'
            : (audio.mimeType.contains('mp4') ? 'mp4' : 'webm');
        final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.$ext';
        String? mediaUrl;
        try {
          mediaUrl = await ApiService.uploadMedia(audio.bytes, filename);
        } catch (e) {
          debugPrint('Upload voice notice (using data URI): $e');
        }
        mediaUrl ??= 'data:${audio.mimeType};base64,${base64Encode(audio.bytes)}';

        _sendMessage(
          type: MessageType.audio,
          mediaUrl: mediaUrl,
          customContent: caption.isNotEmpty ? caption : '🎙️ Voice note (${audio.formattedDuration})',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSendingVoice = false);
        }
      }
      return;
    }

    // 2. Send Image Message
    if (_pendingImageBytes != null) {
      setState(() => _isUploading = true);
      final bytes = _pendingImageBytes!;
      final filename = _pendingImageName ?? 'image.png';
      final caption = text;

      _textController.clear();
      _discardPendingImage();

      try {
        String? mediaUrl;
        try {
          mediaUrl = await ApiService.uploadMedia(bytes, filename);
        } catch (e) {
          debugPrint('Upload image notice (using data URI fallback): $e');
        }

        if (mediaUrl == null || mediaUrl.isEmpty) {
          final ext = filename.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
          mediaUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
        }

        _sendMessage(
          type: MessageType.image,
          mediaUrl: mediaUrl,
          customContent: caption.isNotEmpty ? caption : 'Shared an image',
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
      return;
    }

    // 3. Send Document Message
    if (_pendingDocumentBytes != null) {
      setState(() => _isUploading = true);
      final bytes = _pendingDocumentBytes!;
      final filename = _pendingDocumentName ?? 'document.pdf';
      final caption = text;

      _textController.clear();
      _discardPendingDocument();

      try {
        String? mediaUrl;
        try {
          mediaUrl = await ApiService.uploadMedia(bytes, filename);
        } catch (e) {
          debugPrint('Upload document notice (using data URI fallback): $e');
        }

        if (mediaUrl == null || mediaUrl.isEmpty) {
          final ext = filename.contains('.') ? filename.split('.').last.toLowerCase() : 'pdf';
          final mime = ext == 'pdf' ? 'application/pdf' : 'application/octet-stream';
          mediaUrl = 'data:$mime;name=${Uri.encodeComponent(filename)};base64,${base64Encode(bytes)}';
        }

        _sendMessage(
          type: MessageType.file,
          mediaUrl: mediaUrl,
          customContent: caption.isNotEmpty ? caption : filename,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploading = false);
        }
      }
      return;
    }

    // 4. Send Text Message
    _sendMessage(type: MessageType.text);
  }

  void _handleEndCall(int durationSeconds) async {
    if (_activeCallSession != null) {
      try {
        await ApiService.endCall(_activeCallSession!.id, durationSeconds: durationSeconds);
      } catch (_) {}
      _activeCallSession = null;
    }
    setState(() => _isInCall = false);
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    final durationStr = '$m:$s';
    final callType = _isCallVideo ? '🎥 Video call' : '📞 Voice call';
    _sendMessage(
      type: MessageType.system,
      customContent: '$callType ended • $durationStr',
    );
  }

  void _startEditingMessage(MessageModel msg) {
    if (!msg.canEdit(ApiService.currentUser.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot edit message: 5-minute time limit has expired.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    setState(() {
      _editingMessage = msg;
      _textController.text = msg.content;
    });
  }

  void _cancelEditingMessage() {
    setState(() {
      _editingMessage = null;
      _textController.clear();
    });
  }

  void _deleteMessageForMe(MessageModel message) async {
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
    final ok = await ApiService.deleteMessageForMe(message.id, widget.conversation.id);
    if (!ok && mounted) {
      _loadMessages();
    }
  }

  void _deleteMessageForEveryone(MessageModel message) async {
    setState(() {
      final idx = _messages.indexWhere((m) => m.id == message.id);
      if (idx != -1) {
        final old = _messages[idx];
        _messages[idx] = MessageModel(
          id: old.id,
          conversationId: old.conversationId,
          senderId: old.senderId,
          senderName: old.senderName,
          senderAvatarUrl: old.senderAvatarUrl,
          content: 'This message was deleted',
          type: old.type,
          mediaUrl: null,
          isDeleted: true,
          isEdited: old.isEdited,
          editedAt: old.editedAt,
          deletedForUserIds: old.deletedForUserIds,
          deliveryStatus: old.deliveryStatus,
          createdAt: old.createdAt,
        );
      }
    });
    try {
      await ApiService.deleteMessageForEveryone(message.id, widget.conversation.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting message: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
        _loadMessages();
      }
    }
  }

  void _openGroupInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _GroupInfoDialog(
        conversation: widget.conversation,
        onGroupUpdated: () {
          setState(() {});
          widget.onActivity?.call();
        },
      ),
    );
  }

  void _sendPlayTogetherInvite(String gameType) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastProcessedGameTimestamp = now;
    _activeGame = gameType;
    _isGameMinimized = false;

    final me = ApiService.currentUser;
    final otherUser = widget.conversation.getOtherUsername(me, ApiService.userCache);
    // The player who starts the game is ALWAYS Player 1 and ALWAYS plays first
    final p1User = me.username;
    final p2User = otherUser.isNotEmpty ? otherUser : 'Opponent';

    _activeGameState = {
      'game': gameType,
      'timestamp': now,
      'startedBy': me.id,
      'player1Username': p1User,
      'player2Username': p2User,
      'currentTurnUsername': p1User,
      if (gameType == 'CHESS') 'currentTurn': 'WHITE',
      if (gameType == 'LUDO') 'currentTurn': 'RED',
      if (gameType == 'SNAKES_AND_LADDERS') 'activePlayer': 1,
    };
    final jsonStr = jsonEncode(_activeGameState);
    _sendMessage(
      type: MessageType.gameInvite,
      customContent: '🎮 [PLAY_TOGETHER:$jsonStr] Started a new game of $gameType! Let\'s play together. Turn: @$p1User',
    );
    setState(() {});
  }

  void _confirmStopGame() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.stop_circle, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Stop Game?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to stop and end this game for both players?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.stop, size: 16),
            label: const Text('Stop Game'),
            onPressed: () {
              Navigator.pop(ctx);
              _stopCurrentGame();
            },
          ),
        ],
      ),
    );
  }

  void _stopCurrentGame() {
    if (_activeGame == null) return;
    final me = ApiService.currentUser;
    final gameType = _activeGame!;
    final now = DateTime.now().millisecondsSinceEpoch;
    _lastProcessedGameTimestamp = now;

    final stoppedState = {
      'game': gameType,
      'timestamp': now,
      'status': 'STOPPED',
      'winner': 'STOPPED',
      'stoppedBy': me.username,
      'player1Username': _activeGameState?['player1Username'] ?? me.username,
      'player2Username': _activeGameState?['player2Username'] ?? '',
    };
    final jsonStr = jsonEncode(stoppedState);

    _sendMessage(
      type: MessageType.gameInvite,
      customContent: '🎮 [PLAY_TOGETHER:$jsonStr] ⏹️ $gameType match was stopped by @${me.username}.',
    );

    setState(() {
      _activeGame = null;
      _activeGameState = null;
      _isGameMinimized = false;
    });
  }

  void _startCall(bool isVideo) async {
    final me = ApiService.currentUser;
    final conv = widget.conversation;
    String otherId = '';
    String otherName = _contactName;

    if (conv.participant1Id != null && conv.participant2Id != null) {
      otherId = (conv.participant1Id == me.id) ? conv.participant2Id! : conv.participant1Id!;
    }

    try {
      if (otherId.isNotEmpty) {
        final session = await ApiService.initiateCall(
          conversationId: conv.id,
          receiverId: otherId,
          receiverName: otherName,
          callType: isVideo ? 'VIDEO' : 'AUDIO',
        );
        _activeCallSession = session;
        if (session.status == 'BUSY') {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$otherName is currently busy on another call.'),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isInCall = true;
        _isCallVideo = isVideo;
      });
    }
  }

  bool get _isPlayer1 {
    final me = ApiService.currentUser;
    if (_activeGameState != null) {
      final p1 = _activeGameState!['player1Username'] as String?;
      if (p1 != null && p1.isNotEmpty) {
        return p1.toLowerCase() == me.username.toLowerCase();
      }
      final startedBy = _activeGameState!['startedBy'] as String?;
      if (startedBy != null && startedBy.isNotEmpty) {
        return startedBy == me.id;
      }
    }
    // Whoever starts or launches the game is Player 1
    return true;
  }

  String get _contactName {
    final me = ApiService.currentUser;
    if (!widget.conversation.isGroup) {
      final otherMsg = _messages.cast<MessageModel?>().firstWhere(
        (m) => m != null && m.senderId != me.id && m.senderName.isNotEmpty,
        orElse: () => null,
      );
      if (otherMsg != null) return otherMsg.senderName;
    }
    return widget.conversation.getTitleForUser(me);
  }

  String? get _contactAvatar {
    final me = ApiService.currentUser;
    if (!widget.conversation.isGroup) {
      final otherMsg = _messages.cast<MessageModel?>().firstWhere(
        (m) => m != null && m.senderId != me.id && m.senderAvatarUrl != null && m.senderAvatarUrl!.isNotEmpty,
        orElse: () => null,
      );
      if (otherMsg != null) return otherMsg.senderAvatarUrl;
    }
    return widget.conversation.getAvatarForUser(me);
  }

  @override
  Widget build(BuildContext context) {
    if (_isInCall) {
      return CallModal(
        title: _contactName,
        avatarUrl: _contactAvatar ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        isVideo: _isCallVideo,
        session: _activeCallSession,
        isIncoming: false,
        onEndCallWithDuration: _handleEndCall,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 720;
        final bool hasActiveGame = _activeGame != null;

        return Column(
          children: [
            NetworkStatusBanner(onRetry: _loadMessages),
            // Top Conversation Header Bar
            _buildHeaderBar(),

            // Minimized floating banner (when game is active but minimized)
            if (hasActiveGame && _isGameMinimized)
              _buildMinimizedGameBanner(),

            // Main Viewport: Simultaneous side-by-side on wide screens, responsive stack on narrow
            Expanded(
              child: (hasActiveGame && !_isGameMinimized && isWide)
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Pane: Active Game Board
                        Expanded(
                          flex: 6,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
                            child: _buildActiveGameWidget(),
                          ),
                        ),
                        // Sleek vertical divider
                        Container(
                          width: 1,
                          color: Colors.white.withOpacity(0.08),
                        ),
                        // Right Pane: Simultaneous Live Chat Stream & Composer
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              Expanded(child: _buildMessageList()),
                              if (_selectedMessage != null)
                                _buildSelectedMessageInfoBanner(_selectedMessage!),
                              if (_pendingImageBytes != null)
                                _buildPendingImageBar(),
                              if (_pendingDocumentBytes != null)
                                _buildPendingDocumentBar(),
                              if (_pendingVoiceAudio != null)
                                _buildPendingVoiceBar(),
                              if (_editingMessage != null)
                                _buildEditingMessageBar(),
                              _isRecordingVoice
                                  ? _buildActiveRecordingBar()
                                  : _buildComposerBar(),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // On narrow screens or mobile view: Top interactive game block
                        if (hasActiveGame && !_isGameMinimized)
                          Container(
                            height: 330,
                            margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                            child: _buildActiveGameWidget(),
                          ),
                        // Message feed directly accessible while playing
                        Expanded(child: _buildMessageList()),
                        if (_selectedMessage != null)
                          _buildSelectedMessageInfoBanner(_selectedMessage!),
                        if (_pendingImageBytes != null)
                          _buildPendingImageBar(),
                        if (_pendingDocumentBytes != null)
                          _buildPendingDocumentBar(),
                        if (_pendingVoiceAudio != null)
                          _buildPendingVoiceBar(),
                        if (_editingMessage != null)
                          _buildEditingMessageBar(),
                        _isRecordingVoice
                            ? _buildActiveRecordingBar()
                            : _buildComposerBar(),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderBar() {
    return GlassContainer(
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          AvatarBadge(
            avatarUrl: _contactAvatar,
            name: _contactName,
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: widget.conversation.isGroup ? _openGroupInfoDialog : null,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _contactName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          ),
                        ),
                        if (widget.conversation.isGroup) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Group', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            widget.conversation.isGroup ? 'Tap to view group details & members' : 'Protected by Smart Safety Guardian',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (widget.conversation.isGroup)
            IconButton(
              icon: const Icon(Icons.group_outlined, color: Color(0xFF8B5CF6)),
              tooltip: 'Group Information & Members',
              onPressed: _openGroupInfoDialog,
            ),

          // Game Launcher Action: Open Cloud Game Chooser Dialog
          IconButton(
            icon: const Icon(Icons.sports_esports, color: Color(0xFF8B5CF6)),
            tooltip: 'PlayTogether Games',
            onPressed: _showPlayTogetherChooserDialog,
          ),

          // Voice Call
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white70),
            tooltip: 'Start Voice Call',
            onPressed: () => _startCall(false),
          ),

          // Video Call
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white70),
            tooltip: 'Start Video Call',
            onPressed: () => _startCall(true),
          ),

          // Delete Chat Action
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
            tooltip: 'Delete Chat',
            onPressed: _confirmDeleteChat,
          ),
        ],
      ),
    );
  }

  void _confirmDeleteChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 10),
            Text('Delete Chat?', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this chat with $_contactName? All messages and attachments will be permanently removed for you.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.delete_forever, size: 16),
            label: const Text('Delete Chat'),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.deleteConversation(widget.conversation.id);
              if (ok) {
                widget.onDeleteChat?.call();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPlayTogetherChooserDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_esports, color: Color(0xFF8B5CF6), size: 22),
                const SizedBox(width: 8),
                const Text(
                  'PlayTogether Games 🎮',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildGameChooserCard(
                  title: 'Chess ♟️',
                  desc: 'Classic strategy',
                  gameType: 'CHESS',
                  imageUrl: GameCloudAssets.chessThumb,
                  accentColor: const Color(0xFF8B5CF6),
                ),
                const SizedBox(width: 10),
                _buildGameChooserCard(
                  title: 'Ludo 🎲',
                  desc: 'Roll 6 to race home',
                  gameType: 'LUDO',
                  imageUrl: GameCloudAssets.ludoThumb,
                  accentColor: const Color(0xFF10B981),
                ),
                const SizedBox(width: 10),
                _buildGameChooserCard(
                  title: 'Snakes 🪜',
                  desc: 'Climb or slide to 100',
                  gameType: 'SNAKES_AND_LADDERS',
                  imageUrl: GameCloudAssets.snakesLaddersThumb,
                  accentColor: const Color(0xFFF59E0B),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGameChooserCard({
    required String title,
    required String desc,
    required String gameType,
    required String imageUrl,
    required Color accentColor,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          _sendPlayTogetherInvite(gameType);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withOpacity(0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: CloudGameImage(
                  imageUrl: imageUrl,
                  height: 70,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  fallbackColor: accentColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(color: Colors.white54, fontSize: 9.5),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMinimizedGameBanner() {
    final gameName = _activeGame == 'CHESS'
        ? 'Chess ♟️'
        : (_activeGame == 'LUDO' ? 'Ludo 🎲' : 'Snakes & Ladders 🪜');
    final gameIcon = _activeGame == 'CHESS'
        ? Icons.grid_4x4
        : (_activeGame == 'LUDO' ? Icons.casino : Icons.stairs);
    final color = _activeGame == 'CHESS'
        ? const Color(0xFF8B5CF6)
        : (_activeGame == 'LUDO' ? const Color(0xFF10B981) : const Color(0xFFF59E0B));

    String turnStatus = "Game active in chat";
    if (_activeGameState != null) {
      if (_activeGame == 'CHESS') {
        final turn = _activeGameState!['currentTurn'] ?? 'WHITE';
        final myColor = _isPlayer1 ? 'WHITE' : 'BLACK';
        turnStatus = (turn == myColor) ? "Your turn ($turn)!" : "$_contactName's turn ($turn)";
      } else if (_activeGame == 'LUDO') {
        final turn = _activeGameState!['currentTurn'] ?? 'RED';
        final myColor = _isPlayer1 ? 'RED' : 'GREEN';
        turnStatus = (turn == myColor) ? "Your turn ($turn)!" : "$_contactName's turn ($turn)";
      } else if (_activeGame == 'SNAKES_AND_LADDERS') {
        final turn = _activeGameState!['activePlayer'] ?? 1;
        final myNum = _isPlayer1 ? 1 : 2;
        turnStatus = (turn == myNum) ? "Your turn to roll!" : "$_contactName's turn";
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, spreadRadius: 1),
        ],
      ),
      child: Row(
        children: [
          CloudGameImage(
            imageUrl: GameCloudAssets.getThumbnail(_activeGame!),
            width: 32,
            height: 32,
            borderRadius: BorderRadius.circular(8),
            fallbackIcon: gameIcon,
            fallbackColor: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Playing $gameName',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  turnStatus,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.fullscreen, size: 15),
            label: const Text('Open Board', style: TextStyle(fontSize: 11)),
            onPressed: () => setState(() => _isGameMinimized = false),
          ),
          const SizedBox(width: 6),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF06B6D4),
              side: const BorderSide(color: Color(0xFF06B6D4)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.swap_horiz, size: 15),
            label: const Text('Change Game', style: TextStyle(fontSize: 11)),
            onPressed: _showPlayTogetherChooserDialog,
          ),
          const SizedBox(width: 6),
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: Color(0xFFEF4444), size: 20),
            tooltip: 'Stop Game',
            onPressed: _confirmStopGame,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messagesError != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _messagesError!.contains('internet') ? Icons.wifi_off_rounded : Icons.dns_outlined,
                size: 40,
                color: _messagesError!.contains('internet') ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 12),
              Text(
                _messagesError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Try Again'),
                onPressed: _loadMessages,
              ),
            ],
          ),
        ),
      );
    }
    final displayList = _displayMessages;
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final msg = displayList[index];
        final isMe = msg.senderId == ApiService.currentUser.id;
        return MessageBubble(
          key: ValueKey(msg.id),
          message: msg,
          isMe: isMe,
          isSelected: _selectedMessage?.id == msg.id,
          onSelect: () {
            setState(() {
              _selectedMessage = (_selectedMessage?.id == msg.id) ? null : msg;
            });
          },
          onLaunchGame: (gameType) {
            _syncGameFromMessages(_messages);
            if (_activeGameState == null || _activeGameState!['game'] != gameType) {
              _sendPlayTogetherInvite(gameType);
            } else {
              setState(() {
                _activeGame = gameType;
                _isGameMinimized = false;
              });
            }
          },
          canDeleteEveryone: widget.conversation.isAdmin(ApiService.currentUser.id),
          onEdit: _startEditingMessage,
          onDeleteForMe: _deleteMessageForMe,
          onDeleteForEveryone: _deleteMessageForEveryone,
        );
      },
    );
  }

  Widget _buildPendingImageBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _pendingImageBytes!,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _pendingImageName ?? 'Selected image',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (_pendingImageSize != null)
                      Text(
                        '${(_pendingImageSize! / 1024).toStringAsFixed(1)} KB • ',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    const Text(
                      'Ready to send (Tap Send to upload)',
                      style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: 'Discard image',
            onPressed: _discardPendingImage,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingDocumentBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        border: Border(top: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description, color: Color(0xFF8B5CF6), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _pendingDocumentName ?? 'Selected Document',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (_pendingDocumentSize != null)
                      Text(
                        '${(_pendingDocumentSize! / 1024).toStringAsFixed(1)} KB • ',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    const Text(
                      'Document attached (Tap Send to upload)',
                      style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: 'Discard document',
            onPressed: _discardPendingDocument,
          ),
        ],
      ),
    );
  }

  Widget _buildPendingVoiceBar() {
    final audio = _pendingVoiceAudio!;
    final posSec = _previewPosition.inSeconds;
    final posStr = '${(posSec ~/ 60).toString().padLeft(2, '0')}:${(posSec % 60).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        border: Border(top: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                _isPreviewPlaying ? Icons.pause : Icons.play_arrow,
                color: const Color(0xFF10B981),
                size: 22,
              ),
              tooltip: _isPreviewPlaying ? 'Pause preview' : 'Listen to preview',
              onPressed: _togglePreviewPlay,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Voice Note Recorded',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        audio.formattedSize,
                        style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      _isPreviewPlaying
                          ? '$posStr / ${audio.formattedDuration}'
                          : 'Duration: ${audio.formattedDuration}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '• Tap Send to send this voice message',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            tooltip: 'Discard voice note',
            onPressed: _discardPendingVoice,
          ),
        ],
      ),
    );
  }

  Widget _buildEditingMessageBar() {
    if (_editingMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D2E),
        border: Border(top: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Text(
                      'Editing Message',
                      style: TextStyle(color: Color(0xFFF59E0B), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '(Within 5-min limit)',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _editingMessage!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 18),
            tooltip: 'Cancel Edit',
            onPressed: _cancelEditingMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRecordingBar() {
    final m = (_recordingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_recordingSeconds % 60).toString().padLeft(2, '0');
    final timerText = '$m:$s';

    return GlassContainer(
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Red Pulsing REC Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'REC',
                  style: TextStyle(color: Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Live Timer
          Text(
            timerText,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(width: 14),

          // Animated Audio Visualizer wave bars
          Expanded(
            child: SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(16, (i) {
                  final height = ((i + _recordingSeconds) % 5 + 1) * 3.8 + 4;
                  return Container(
                    width: 3,
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Discard Button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 22),
            tooltip: 'Discard recording',
            onPressed: _cancelVoiceRecording,
          ),

          // Stop & Review Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            icon: const Icon(Icons.stop, size: 18),
            label: const Text('Stop & Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: _stopVoiceRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildComposerBar() {
    return GlassContainer(
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Camera Photo Capture Button
          IconButton(
            icon: const Icon(Icons.photo_camera_outlined, color: Color(0xFF06B6D4)),
            tooltip: 'Capture Photo with Camera',
            onPressed: _capturePhotoWithCamera,
          ),

          // Device Image Picker Button (No auto-upload)
          IconButton(
            icon: const Icon(Icons.image_outlined, color: Color(0xFF38BDF8)),
            tooltip: 'Choose Image from Gallery',
            onPressed: _pickImageFromDevice,
          ),

          // Real Microphone Voice Recording Button
          IconButton(
            icon: const Icon(Icons.mic, color: Color(0xFF10B981)),
            tooltip: 'Record Voice Note (Browser MediaRecorder)',
            onPressed: _startVoiceRecording,
          ),

          // Attach Options Menu (Real files, documents, audio)
          PopupMenuButton<String>(
            icon: const Icon(Icons.attach_file, color: Colors.white70),
            tooltip: 'Attach Media from Device',
            color: const Color(0xFF1E293B),
            onSelected: (val) {
              if (val == 'CAPTURE_CAMERA') _capturePhotoWithCamera();
              if (val == 'PICK_DOC') _pickDocumentFromDevice();
              if (val == 'PICK_IMAGE') _pickImageFromDevice();
              if (val == 'PICK_AUDIO') _pickAudioFileFromDevice();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'CAPTURE_CAMERA',
                child: Row(children: [Icon(Icons.photo_camera, color: Color(0xFF06B6D4), size: 18), SizedBox(width: 8), Text('Capture with Camera', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'PICK_DOC',
                child: Row(children: [Icon(Icons.description, color: Color(0xFF8B5CF6), size: 18), SizedBox(width: 8), Text('Attach Document / File', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'PICK_IMAGE',
                child: Row(children: [Icon(Icons.photo_library, color: Color(0xFF38BDF8), size: 18), SizedBox(width: 8), Text('Choose Image from Gallery', style: TextStyle(color: Colors.white))]),
              ),
              const PopupMenuItem(
                value: 'PICK_AUDIO',
                child: Row(children: [Icon(Icons.audio_file, color: Color(0xFF10B981), size: 18), SizedBox(width: 8), Text('Attach Audio File', style: TextStyle(color: Colors.white))]),
              ),
            ],
          ),

          // Text Field
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: _pendingVoiceAudio != null
                    ? 'Add an optional note with this voice message...'
                    : (_pendingImageBytes != null
                        ? 'Add a caption for this image...'
                        : (_pendingDocumentBytes != null
                            ? 'Add a caption for this document...'
                            : 'Type a message... (Try typing links to test Safety Guardian)')),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).primaryColor,
            child: (_isUploading || _isSendingVoice)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _handleSend,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveGameWidget() {
    final isP1 = _isPlayer1;
    final me = ApiService.currentUser;
    final otherUser = widget.conversation.getOtherUsername(me, ApiService.userCache);

    final p1User = (_activeGameState?['player1Username'] as String?)?.isNotEmpty == true
        ? _activeGameState!['player1Username'] as String
        : (_isPlayer1 ? me.username : otherUser);
    final p2User = (_activeGameState?['player2Username'] as String?)?.isNotEmpty == true
        ? _activeGameState!['player2Username'] as String
        : (_isPlayer1 ? otherUser : me.username);

    switch (_activeGame) {
      case 'CHESS':
        return ChessGameView(
          onClose: () => setState(() {
            _activeGame = null;
            _activeGameState = null;
          }),
          onMinimize: () => setState(() => _isGameMinimized = true),
          onChangeGame: _showPlayTogetherChooserDialog,
          onStopGame: _confirmStopGame,
          initialGameState: _activeGameState,
          onGameStateChanged: _onGameMoveMade,
          playerColor: isP1 ? 'WHITE' : 'BLACK',
          opponentName: _contactName,
          myUsername: me.username,
          player1Username: p1User,
          player2Username: p2User,
        );
      case 'LUDO':
        return LudoGameView(
          onClose: () => setState(() {
            _activeGame = null;
            _activeGameState = null;
          }),
          onMinimize: () => setState(() => _isGameMinimized = true),
          onChangeGame: _showPlayTogetherChooserDialog,
          onStopGame: _confirmStopGame,
          initialGameState: _activeGameState,
          onGameStateChanged: _onGameMoveMade,
          myPlayer: isP1 ? 'RED' : 'GREEN',
          opponentName: _contactName,
          myUsername: me.username,
          player1Username: p1User,
          player2Username: p2User,
        );
      case 'SNAKES_AND_LADDERS':
      default:
        return SnakesLaddersView(
          onClose: () => setState(() {
            _activeGame = null;
            _activeGameState = null;
          }),
          onMinimize: () => setState(() => _isGameMinimized = true),
          onChangeGame: _showPlayTogetherChooserDialog,
          onStopGame: _confirmStopGame,
          initialGameState: _activeGameState,
          onGameStateChanged: _onGameMoveMade,
          myPlayerNumber: isP1 ? 1 : 2,
          opponentName: _contactName,
          myUsername: me.username,
          player1Username: p1User,
          player2Username: p2User,
        );
    }
  }

  Widget _buildSelectedMessageInfoBanner(MessageModel msg) {
    final isMe = msg.senderId == ApiService.currentUser.id;
    final effectiveAvatarUrl = msg.senderAvatarUrl ?? (isMe ? ApiService.currentUser.avatarUrl : null);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(color: const Color(0xFF06B6D4).withValues(alpha: 0.5), width: 1.5),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Sender Profile Photo
          GestureDetector(
            onTap: () => _showSenderProfileModal(msg),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.25),
              backgroundImage: (effectiveAvatarUrl != null && effectiveAvatarUrl.isNotEmpty)
                  ? NetworkImage(effectiveAvatarUrl)
                  : null,
              child: (effectiveAvatarUrl == null || effectiveAvatarUrl.isEmpty)
                  ? Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor, fontSize: 14),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          // Sender Name and Message Snippet
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isMe ? 'You (${msg.senderName})' : msg.senderName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        DateFormat.jm().format(msg.createdAt),
                        style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  msg.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // View Profile Button
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF06B6D4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            icon: const Icon(Icons.account_circle_outlined, size: 16),
            label: const Text('Sender Info', style: TextStyle(fontSize: 11)),
            onPressed: () => _showSenderProfileModal(msg),
          ),
          // Deselect Action
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.white54),
            tooltip: 'Deselect Message',
            onPressed: () => setState(() => _selectedMessage = null),
          ),
        ],
      ),
    );
  }

  void _showSenderProfileModal(MessageModel msg) {
    final isMe = msg.senderId == ApiService.currentUser.id;
    final effectiveAvatarUrl = msg.senderAvatarUrl ?? (isMe ? ApiService.currentUser.avatarUrl : null);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: theme.primaryColor.withValues(alpha: 0.25),
              backgroundImage: (effectiveAvatarUrl != null && effectiveAvatarUrl.isNotEmpty)
                  ? NetworkImage(effectiveAvatarUrl)
                  : null,
              child: (effectiveAvatarUrl == null || effectiveAvatarUrl.isEmpty)
                  ? Text(
                      msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor, fontSize: 36),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              isMe ? '${msg.senderName} (You)' : msg.senderName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Color(0xFF10B981), size: 14),
                  SizedBox(width: 4),
                  Text('Active User Profile', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sender Account ID', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(msg.senderId, style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'monospace')),
                  const SizedBox(height: 10),
                  const Text('Selected Message', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(msg.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    'Timestamp: ${DateFormat.yMMMd().add_jm().format(msg.createdAt)} • ${msg.deliveryStatus}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupInfoDialog extends StatefulWidget {
  final ConversationModel conversation;
  final VoidCallback onGroupUpdated;

  const _GroupInfoDialog({
    required this.conversation,
    required this.onGroupUpdated,
  });

  @override
  State<_GroupInfoDialog> createState() => _GroupInfoDialogState();
}

class _GroupInfoDialogState extends State<_GroupInfoDialog> {
  List<GroupMemberModel> _members = [];
  bool _isLoading = true;
  bool _showAddMember = false;
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  String? _statusMessage;
  bool _isStatusError = false;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.conversation.avatarUrl;
    _loadMembers();
  }

  void _customizeGroupIcon() async {
    final chosen = await GroupIconPickerModal.show(
      context,
      currentIcon: _currentAvatarUrl ?? ApiService.currentGroupIcon,
      title: 'Customize Group Icon',
    );
    if (chosen != null && mounted) {
      setState(() => _currentAvatarUrl = chosen);
      try {
        await ApiService.updateGroupInfo(widget.conversation.id, avatarUrl: chosen);
        widget.onGroupUpdated();
      } catch (e) {
        debugPrint('Error updating group icon: $e');
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    final list = await ApiService.getGroupMembers(widget.conversation.id);
    if (mounted) {
      setState(() {
        _members = list;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) async {
    final q = query.trim().replaceAll('@', '');
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await ApiService.searchUsers(q);
    if (mounted) {
      // Filter out users who are already in the group
      final existingIds = _members.map((m) => m.userId).toSet();
      setState(() {
        _searchResults = results.where((u) => !existingIds.contains(u.id)).toList();
        _isSearching = false;
      });
    }
  }

  Future<void> _addMember(UserModel user) async {
    setState(() {
      _statusMessage = null;
    });
    try {
      final success = await ApiService.addGroupMember(widget.conversation.id, user.id);
      if (success) {
        setState(() {
          _statusMessage = 'Added @${user.username} to the group';
          _isStatusError = false;
          _searchResults.removeWhere((u) => u.id == user.id);
        });
        await _loadMembers();
        widget.onGroupUpdated();
      } else {
        setState(() {
          _statusMessage = 'Failed to add user';
          _isStatusError = true;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isStatusError = true;
      });
    }
  }

  void _confirmRemoveMember(GroupMemberModel member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_remove, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text('Remove Member?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${member.displayName} (@${member.username}) from this group?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.removeGroupMember(widget.conversation.id, member.userId);
              if (ok) {
                _loadMembers();
                widget.onGroupUpdated();
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmLeaveGroup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app, color: Color(0xFFEF4444), size: 20),
            SizedBox(width: 8),
            Text('Leave Group?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to leave this group? You will no longer receive messages.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Leave Group'),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ApiService.leaveGroup(widget.conversation.id);
              if (ok && mounted) {
                Navigator.pop(context); // Close info modal
                widget.onGroupUpdated();
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = ApiService.currentUser;
    final isMeAdmin = widget.conversation.isAdmin(me.id);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 650),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: isMeAdmin ? _customizeGroupIcon : null,
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        AvatarBadge(
                          avatarUrl: _currentAvatarUrl,
                          name: widget.conversation.title,
                          radius: 28,
                          isGroup: true,
                        ),
                        if (isMeAdmin)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF0F172A), width: 1.5),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.conversation.title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.conversation.description?.isNotEmpty == true
                              ? widget.conversation.description!
                              : 'Group Chat • ${_members.length} member${_members.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isMeAdmin)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: InkWell(
                              onTap: _customizeGroupIcon,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.palette_outlined, size: 13, color: Color(0xFF06B6D4)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Change Group Icon',
                                    style: TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Status notification bar
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: _isStatusError
                    ? const Color(0xFFEF4444).withOpacity(0.15)
                    : const Color(0xFF10B981).withOpacity(0.15),
                child: Row(
                  children: [
                    Icon(
                      _isStatusError ? Icons.error_outline : Icons.check_circle_outline,
                      color: _isStatusError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isStatusError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Members Header & Action
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Members (${_members.length})',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (isMeAdmin)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8B5CF6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      ),
                      icon: Icon(_showAddMember ? Icons.close : Icons.person_add, size: 16),
                      label: Text(_showAddMember ? 'Cancel' : 'Add Member', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        setState(() {
                          _showAddMember = !_showAddMember;
                          if (!_showAddMember) {
                            _searchController.clear();
                            _searchResults = [];
                            _statusMessage = null;
                          }
                        });
                      },
                    ),
                ],
              ),
            ),

            // Add Member Panel
            if (_showAddMember)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search username or name to add...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF8B5CF6), size: 18),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 140),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          itemBuilder: (ctx, idx) {
                            final user = _searchResults[idx];
                            return ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              leading: AvatarBadge(avatarUrl: user.avatarUrl, name: user.displayName, radius: 14),
                              title: Text(user.displayName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text('@${user.username}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8B5CF6),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: () => _addMember(user),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Members List
            Flexible(
              child: _isLoading
                  ? const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                  : _members.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No members found', style: TextStyle(color: Colors.white54)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          itemCount: _members.length,
                          itemBuilder: (ctx, idx) {
                            final m = _members[idx];
                            final isThisAdmin = m.isAdmin || widget.conversation.isAdmin(m.userId);
                            final isMe = m.userId == me.id;

                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.03),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  AvatarBadge(avatarUrl: m.avatarUrl, name: m.displayName, radius: 18),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                isMe ? '${m.displayName} (You)' : m.displayName,
                                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isThisAdmin) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF8B5CF6).withOpacity(0.25),
                                                  borderRadius: BorderRadius.circular(4),
                                                  border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.6), width: 0.8),
                                                ),
                                                child: const Text('ADMIN', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 9.5, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text('@${m.username}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  // Remove Member Action (Admin only, cannot remove self or other admin)
                                  if (isMeAdmin && !isMe && !isThisAdmin)
                                    IconButton(
                                      icon: const Icon(Icons.person_remove_outlined, color: Color(0xFFEF4444), size: 18),
                                      tooltip: 'Remove from Group',
                                      onPressed: () => _confirmRemoveMember(m),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),

            const Divider(color: Colors.white12, height: 1),

            // Footer Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                    icon: const Icon(Icons.exit_to_app, size: 18),
                    label: const Text('Leave Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: _confirmLeaveGroup,
                  ),
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

