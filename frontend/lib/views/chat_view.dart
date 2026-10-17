import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/call_modal.dart';
import '../widgets/glass_container.dart';
import '../widgets/message_bubble.dart';
import 'games/chess_game_view.dart';
import 'games/ludo_game_view.dart';
import 'games/snakes_ladders_view.dart';

class ChatView extends StatefulWidget {
  final ConversationModel conversation;

  const ChatView({super.key, required this.conversation});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  String? _activeGame; // CHESS, LUDO, SNAKES_AND_LADDERS, or null
  bool _isInCall = false;
  bool _isCallVideo = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _loadMessages();
      _activeGame = null;
    }
  }

  void _loadMessages() async {
    setState(() => _isLoading = true);
    final msgs = await ApiService.getMessages(widget.conversation.id);
    if (mounted) {
      setState(() {
        _messages = List<MessageModel>.from(msgs);
        _isLoading = false;
      });
      _scrollToBottom();
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

  List<MessageModel> get _displayMessages {
    final seen = <String>{};
    final list = <MessageModel>[];
    for (final m in _messages) {
      if (seen.add(m.id)) {
        final hasDup = list.any((ex) =>
            ex.senderId == m.senderId &&
            ex.content == m.content &&
            ex.createdAt.difference(m.createdAt).abs().inSeconds <= 2);
        if (!hasDup) {
          list.add(m);
        }
      }
    }
    return list;
  }

  void _sendMessage({MessageType type = MessageType.text, String? mediaUrl}) async {
    final text = _textController.text.trim();
    if (text.isEmpty && mediaUrl == null) return;

    final content = text.isNotEmpty ? text : (type == MessageType.image ? "Shared an image" : "Shared media");
    _textController.clear();

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
            (m.senderId == sent.senderId &&
                m.content == sent.content &&
                m.createdAt.difference(sent.createdAt).abs().inSeconds <= 2));
        if (!exists) {
          _messages.add(sent);
        }
      });
      _scrollToBottom();
    }
  }

  void _sendCloudinaryImageDemo() {
    _sendMessage(
      type: MessageType.image,
      mediaUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800',
    );
  }

  void _sendVoiceNoteDemo() {
    _sendMessage(
      type: MessageType.audio,
      mediaUrl: 'https://actions.google.com/sounds/v1/ambiences/coffee_shop.ogg',
    );
  }

  void _sendPlayTogetherInvite(String gameType) {
    _sendMessage(
      type: MessageType.gameInvite,
      mediaUrl: null,
    );
    setState(() => _activeGame = gameType);
  }

  void _startCall(bool isVideo) {
    setState(() {
      _isInCall = true;
      _isCallVideo = isVideo;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isInCall) {
      return CallModal(
        title: widget.conversation.title,
        avatarUrl: widget.conversation.avatarUrl ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
        isVideo: _isCallVideo,
        onEndCall: () => setState(() => _isInCall = false),
      );
    }

    return Column(
      children: [
        // Conversation Header Bar
        GlassContainer(
          borderRadius: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              AvatarBadge(
                avatarUrl: widget.conversation.avatarUrl,
                name: widget.conversation.title,
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.conversation.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
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
                        Text(
                          'Protected by Smart Safety Guardian',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Game Launcher Action Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.sports_esports, color: Color(0xFF8B5CF6)),
                tooltip: 'PlayTogether In-Chat Games',
                color: const Color(0xFF1E293B),
                onSelected: (game) => _sendPlayTogetherInvite(game),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'CHESS', child: Row(children: [Icon(Icons.grid_4x4, color: Colors.purple, size: 18), SizedBox(width: 8), Text('Chess ♟️', style: TextStyle(color: Colors.white))])),
                  const PopupMenuItem(value: 'LUDO', child: Row(children: [Icon(Icons.casino, color: Colors.green, size: 18), SizedBox(width: 8), Text('Ludo 🎲', style: TextStyle(color: Colors.white))])),
                  const PopupMenuItem(value: 'SNAKES_AND_LADDERS', child: Row(children: [Icon(Icons.stairs, color: Colors.amber, size: 18), SizedBox(width: 8), Text('Snakes & Ladders 🪜', style: TextStyle(color: Colors.white))])),
                ],
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
            ],
          ),
        ),

        // In-Chat Active Game Overlay if open
        if (_activeGame != null)
          Container(
            height: 380,
            margin: const EdgeInsets.all(12),
            child: _buildActiveGameWidget(),
          ),

        // Message Feed
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: _displayMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _displayMessages[index];
                    final isMe = msg.senderId == ApiService.currentUser.id;
                    return MessageBubble(
                      key: ValueKey(msg.id),
                      message: msg,
                      isMe: isMe,
                      onLaunchGame: (gameType) => setState(() => _activeGame = gameType),
                    );
                  },
                ),
        ),

        // Message Composer Bar
        GlassContainer(
          borderRadius: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Cloudinary Media Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.attach_file, color: Colors.white70),
                tooltip: 'Attach Media (Cloudinary)',
                color: const Color(0xFF1E293B),
                onSelected: (val) {
                  if (val == 'IMAGE') _sendCloudinaryImageDemo();
                  if (val == 'AUDIO') _sendVoiceNoteDemo();
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'IMAGE',
                    child: Row(children: [Icon(Icons.image, color: Color(0xFF38BDF8), size: 18), SizedBox(width: 8), Text('Photo (Cloudinary CDN)', style: TextStyle(color: Colors.white))]),
                  ),
                  const PopupMenuItem(
                    value: 'AUDIO',
                    child: Row(children: [Icon(Icons.mic, color: Color(0xFF10B981), size: 18), SizedBox(width: 8), Text('Voice Note', style: TextStyle(color: Colors.white))]),
                  ),
                ],
              ),

              // Text Field
              Expanded(
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type a message... (Try typing links to test Safety Guardian)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),

              // Send Button
              CircleAvatar(
                radius: 20,
                backgroundColor: Theme.of(context).primaryColor,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  onPressed: () => _sendMessage(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveGameWidget() {
    switch (_activeGame) {
      case 'CHESS':
        return ChessGameView(onClose: () => setState(() => _activeGame = null));
      case 'LUDO':
        return LudoGameView(onClose: () => setState(() => _activeGame = null));
      case 'SNAKES_AND_LADDERS':
      default:
        return SnakesLaddersView(onClose: () => setState(() => _activeGame = null));
    }
  }
}
