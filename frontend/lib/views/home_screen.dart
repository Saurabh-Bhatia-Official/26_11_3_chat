import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/call_modal.dart';
import '../widgets/network_status_banner.dart';
import '../widgets/software_logo_widget.dart';
import '../widgets/group_icon_picker_modal.dart';
import '../widgets/call_history_modal.dart';
import '../services/call_signaling_service.dart';
import '../services/group_icon_helper.dart';
import 'chat_view.dart';
import 'identity_settings_view.dart';
import 'safety_guardian_view.dart';

enum MainNavigationTab { chats, safetyGuardian, identity }

class HomeScreen extends StatefulWidget {
  final AppThemeMode currentThemeMode;
  final Function(AppThemeMode) onThemeChanged;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MainNavigationTab _currentTab = MainNavigationTab.chats;
  List<ConversationModel> _conversations = [];
  ConversationModel? _selectedConversation;
  bool _isLoading = true;
  String? _conversationsError;
  String _searchQuery = '';
  Timer? _conversationsSyncTimer;
  bool _isSyncingConversations = false;
  StreamSubscription? _callSignalSub;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _startConversationsSync();
    _initCallSignaling();
  }

  void _initCallSignaling() {
    final me = ApiService.currentUser;
    CallSignalingService().init(me.id);
    _callSignalSub?.cancel();
    _callSignalSub = CallSignalingService().onSignal.listen((signal) {
      final type = signal['type'] as String?;
      if (type == 'CALL_INCOMING' || type == 'CALL_INITIATE') {
        final sessionMap = signal['callSession'] as Map<String, dynamic>?;
        if (sessionMap != null) {
          final call = CallSessionModel.fromJson(sessionMap);
          if (call.receiverId == me.id && _handledCallId != call.id) {
            _handledCallId = call.id;
            _showIncomingCallDialog(call);
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _conversationsSyncTimer?.cancel();
    _callSignalSub?.cancel();
    super.dispose();
  }

  void _startConversationsSync() {
    _conversationsSyncTimer?.cancel();
    _conversationsSyncTimer = Timer.periodic(const Duration(milliseconds: 2000), (_) {
      _syncConversationsSilently();
      _checkForIncomingCalls();
    });
  }

  String? _handledCallId;
  void _checkForIncomingCalls() async {
    if (!mounted) return;
    try {
      final activeCall = await ApiService.getActiveCallForUser();
      if (!mounted || activeCall == null) return;
      final me = ApiService.currentUser;
      if (activeCall.receiverId == me.id && activeCall.status == 'RINGING') {
        if (_handledCallId == activeCall.id) return;
        _handledCallId = activeCall.id;
        _showIncomingCallDialog(activeCall);
      }
    } catch (_) {}
  }

  void _showIncomingCallDialog(CallSessionModel call) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: (call.callerAvatarUrl != null && call.callerAvatarUrl!.isNotEmpty)
                  ? NetworkImage(call.callerAvatarUrl!)
                  : null,
              child: (call.callerAvatarUrl == null || call.callerAvatarUrl!.isEmpty)
                  ? Text(call.callerName.isNotEmpty ? call.callerName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 28, color: Colors.white))
                  : null,
            ),
            const SizedBox(height: 16),
            Text(call.callerName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            Text(
              'Incoming ${call.callType == "VIDEO" ? "Video" : "Audio"} Call...',
              style: const TextStyle(fontSize: 14, color: Color(0xFF06B6D4)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'reject_call_${call.id}',
                  backgroundColor: const Color(0xFFEF4444),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await ApiService.rejectCall(call.id);
                  },
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
                FloatingActionButton(
                  heroTag: 'accept_call_${call.id}',
                  backgroundColor: const Color(0xFF10B981),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await ApiService.acceptCall(call.id);
                    if (mounted) {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => CallModal(
                          title: call.callerName,
                          avatarUrl: call.callerAvatarUrl ?? '',
                          isVideo: call.callType == 'VIDEO',
                          session: call,
                          isIncoming: true,
                          onEndCallWithDuration: (dur) {
                            ApiService.endCall(call.id, durationSeconds: dur);
                            Navigator.of(context, rootNavigator: true).pop();
                          },
                        ),
                      );
                    }
                  },
                  child: const Icon(Icons.call, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _syncConversationsSilently() async {
    if (!mounted || _isSyncingConversations) return;
    _isSyncingConversations = true;
    try {
      final list = await ApiService.getConversations();
      if (!mounted) return;

      bool hasChanges = list.length != _conversations.length;
      if (!hasChanges) {
        for (int i = 0; i < list.length; i++) {
          final a = list[i];
          final b = _conversations[i];
          if (a.id != b.id ||
              a.lastMessagePreview != b.lastMessagePreview ||
              a.lastMessageAt != b.lastMessageAt ||
              a.unreadCount != b.unreadCount) {
            hasChanges = true;
            break;
          }
        }
      }

      if (hasChanges) {
        setState(() {
          _conversations = list;
          if (_selectedConversation != null) {
            final match = list.cast<ConversationModel?>().firstWhere(
              (c) => c?.id == _selectedConversation!.id,
              orElse: () => null,
            );
            if (match != null) {
              _selectedConversation = match;
            }
          } else if (list.isNotEmpty) {
            _selectedConversation = list.first;
          }
        });
      }
    } catch (_) {
    } finally {
      _isSyncingConversations = false;
    }
  }

  void _loadConversations() async {
    setState(() {
      _isLoading = true;
      _conversationsError = null;
    });
    // Populate user cache in background so usernames are available for matching
    ApiService.getUsers();
    try {
      final list = await ApiService.getConversations();
      if (mounted) {
        setState(() {
          _conversations = list;
          _conversationsError = null;
          if (list.isNotEmpty && _selectedConversation == null) {
            _selectedConversation = list.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _conversationsError = e.toString().replaceAll('Exception: ', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  void _openNewChatDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => _NewChatDialog(
        onUserSelected: (selectedUser) async {
          Navigator.of(ctx).pop();
          // Check if conversation already exists with this user
          final me = ApiService.currentUser;
          final existing = _conversations.cast<ConversationModel?>().firstWhere(
            (c) => c != null && !c.isGroup &&
                   ((c.participant1Id == selectedUser.id || c.participant2Id == selectedUser.id) ||
                    c.getOtherUsername(me, ApiService.userCache).toLowerCase() == selectedUser.username.toLowerCase()),
            orElse: () => null,
          );
          if (existing != null) {
            setState(() {
              _selectedConversation = existing;
              _currentTab = MainNavigationTab.chats;
            });
            return;
          }

          final conv = await ApiService.createConversation(targetUser: selectedUser);
          setState(() {
            _selectedConversation = conv;
            _currentTab = MainNavigationTab.chats;
          });
          _loadConversations();
        },
      ),
    );
  }

  void _openCreateGroupDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => _CreateGroupDialog(
        onGroupCreated: (newGroup) {
          setState(() {
            _selectedConversation = newGroup;
            _currentTab = MainNavigationTab.chats;
            if (!_conversations.any((c) => c.id == newGroup.id)) {
              _conversations.insert(0, newGroup);
            }
          });
          _loadConversations();
        },
      ),
    );
  }

  void _openCallHistoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CallHistoryModal(
        onCallBack: (conversationId, otherId, otherName, isVideo) {
          final match = _conversations.cast<ConversationModel?>().firstWhere(
            (c) => c?.id == conversationId,
            orElse: () => null,
          );
          if (match != null) {
            setState(() {
              _selectedConversation = match;
              _currentTab = MainNavigationTab.chats;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 720;

    return PopScope(
      canPop: _selectedConversation == null || isWide,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _selectedConversation != null && !isWide) {
          setState(() => _selectedConversation = null);
        }
      },
      child: Scaffold(
        bottomNavigationBar: (!isWide && (_selectedConversation == null || _currentTab != MainNavigationTab.chats))
            ? Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF070B12),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                ),
                child: BottomNavigationBar(
                  currentIndex: _currentTab.index,
                  backgroundColor: const Color(0xFF070B12),
                  selectedItemColor: const Color(0xFF06B6D4),
                  unselectedItemColor: Colors.white60,
                  type: BottomNavigationBarType.fixed,
                  onTap: (index) {
                    setState(() {
                      _currentTab = MainNavigationTab.values[index];
                      if (_currentTab != MainNavigationTab.chats) {
                        _selectedConversation = null;
                      }
                    });
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.chat_bubble_outline),
                      activeIcon: Icon(Icons.chat_bubble),
                      label: 'Chats',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.shield_outlined),
                      activeIcon: Icon(Icons.shield),
                      label: 'Guardian',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.palette_outlined),
                      activeIcon: Icon(Icons.palette),
                      label: 'Settings',
                    ),
                  ],
                ),
              )
            : null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              NetworkStatusBanner(onRetry: _loadConversations),
              Expanded(
                child: Row(
                  children: [
                    // Left Icon Navigation Rail for Tablet / Desktop
                    if (isWide)
                      ValueListenableBuilder<UserModel?>(
                        valueListenable: ApiService.currentUserNotifier,
                        builder: (context, user, _) {
                          return _buildNavRail(theme, user ?? ApiService.currentUser);
                        },
                      ),

                    // Main Interactive Layout (full width on mobile)
                    Expanded(
                      child: _buildMainContent(theme, isWide),
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

  Widget _buildNavRail(ThemeData theme, UserModel currentUser) {
    return Container(
      width: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF070B12),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 18),
          // Dynamic Software Logo & Home Navigation
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (_currentTab != MainNavigationTab.chats) {
                setState(() => _currentTab = MainNavigationTab.chats);
              }
            },
            child: const Tooltip(
              message: 'Home / Software Logo',
              child: SoftwareLogoWidget(size: 42, iconSize: 22, borderRadius: 14),
            ),
          ),
          const SizedBox(height: 28),

          // Navigation Icons
          ValueListenableBuilder<String>(
            valueListenable: ApiService.currentAppIconNotifier,
            builder: (context, iconId, _) {
              final iconOpt = AppIconHelper.getIcon(iconId);
              return _buildNavRailItem(
                tab: MainNavigationTab.chats,
                icon: Icons.chat_bubble_outline,
                activeIcon: iconOpt['icon'] as IconData,
                tooltip: 'Home & Chats (${iconOpt['name']})',
              );
            },
          ),
          const SizedBox(height: 16),
          _buildNavRailItem(
            tab: MainNavigationTab.safetyGuardian,
            icon: Icons.shield_outlined,
            activeIcon: Icons.shield,
            tooltip: 'Smart Safety Guardian',
          ),
          const SizedBox(height: 16),
          _buildNavRailItem(
            tab: MainNavigationTab.identity,
            icon: Icons.palette_outlined,
            activeIcon: Icons.palette,
            tooltip: 'Appearance & Themes',
          ),

          const Spacer(),

          // Current User Profile Avatar & Logout
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Tooltip(
                  message: '${currentUser.displayName} (@${currentUser.username})',
                  child: AvatarBadge(
                    avatarUrl: currentUser.avatarUrl,
                    name: currentUser.displayName,
                    radius: 18,
                  ),
                ),
                const SizedBox(height: 10),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
                  tooltip: 'Sign Out (@${currentUser.username})',
                  onPressed: widget.onLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRailItem({
    required MainNavigationTab tab,
    required IconData icon,
    required IconData activeIcon,
    required String tooltip,
  }) {
    final isSelected = _currentTab == tab;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _currentTab = tab),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.4)) : null,
          ),
          child: Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? Theme.of(context).primaryColor : Colors.white60,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(ThemeData theme, bool isWide) {
    Widget chatsContent;
    if (isWide) {
      chatsContent = Row(
        children: [
          // Conversation List Sidebar
          Container(
            width: 340,
            decoration: BoxDecoration(
              color: const Color(0xFF0D131F),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.06))),
            ),
            child: _buildConversationListPane(),
          ),

          // Main Chat Area
          Expanded(
            child: _selectedConversation != null
                ? ChatView(
                    key: ValueKey(_selectedConversation!.id),
                    conversation: _selectedConversation!,
                    onActivity: _syncConversationsSilently,
                    onDeleteChat: () => _handleDeleteConversation(_selectedConversation!),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SoftwareLogoWidget(size: 74, iconSize: 40, borderRadius: 22),
                        const SizedBox(height: 18),
                        ValueListenableBuilder<String>(
                          valueListenable: ApiService.softwareNameNotifier,
                          builder: (context, softwareName, _) {
                            return Text(
                              softwareName,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'No conversation selected',
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Select a chat from the left or start a new conversation',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06B6D4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          ),
                          icon: const Icon(Icons.add_comment, size: 18),
                          label: const Text('Start New Chat'),
                          onPressed: _openNewChatDialog,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      );
    } else {
      // Mobile View: Single Pane Navigation
      if (_selectedConversation != null) {
        chatsContent = ChatView(
          key: ValueKey(_selectedConversation!.id),
          conversation: _selectedConversation!,
          onBack: () => setState(() => _selectedConversation = null),
          onActivity: _syncConversationsSilently,
          onDeleteChat: () => _handleDeleteConversation(_selectedConversation!),
        );
      } else {
        chatsContent = _buildConversationListPane();
      }
    }

    return IndexedStack(
      index: _currentTab.index,
      children: [
        // Tab 0: Chats
        chatsContent,

        // Tab 1: Safety Guardian
        const SafetyGuardianView(),

        // Tab 2: Profile & Settings
        IdentitySettingsView(
          currentThemeMode: widget.currentThemeMode,
          onThemeChanged: widget.onThemeChanged,
          onLogout: widget.onLogout,
        ),
      ],
    );
  }


  Widget _buildConversationListPane() {
    final me = ApiService.currentUser;
    final filtered = _conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.trim().toLowerCase().replaceAll('@', '');
      final otherUsername = c.getOtherUsername(me, ApiService.userCache).toLowerCase().replaceAll('@', '');
      return otherUsername.contains(query);
    }).toList();

    return Column(
      children: [
        // Header with "Create Group" and "New Chat" actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: ApiService.softwareNameNotifier,
                  builder: (context, softwareName, _) {
                    return Row(
                      children: [
                        const SoftwareLogoWidget(size: 28, iconSize: 15, borderRadius: 8, showShadow: false),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            softwareName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.group_add_rounded, color: Color(0xFF10B981), size: 22),
                tooltip: 'Create Group',
                onPressed: _openCreateGroupDialog,
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.add_circle, color: Color(0xFF06B6D4), size: 24),
                tooltip: 'Start Chat with User',
                onPressed: _openNewChatDialog,
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.call_outlined, color: Color(0xFF8B5CF6), size: 22),
                tooltip: 'Call History',
                onPressed: _openCallHistoryDialog,
              ),
            ],
          ),
        ),

        // Search Input (Searches strictly by username)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by username (@username)...',
              prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white38),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),

        // Conversation items or Empty Prompt
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (_conversationsError != null && _conversations.isEmpty)
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _conversationsError!.contains('internet')
                                  ? Icons.wifi_off_rounded
                                  : Icons.dns_outlined,
                              size: 38,
                              color: _conversationsError!.contains('internet')
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFFF59E0B),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _conversationsError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF06B6D4),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Try Again'),
                              onPressed: _loadConversations,
                            ),
                          ],
                        ),
                      ),
                    )
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 36, color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No chat with username "@${_searchQuery.replaceAll('@', '')}"'
                                      : 'No chats yet',
                                  style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Tap the + button above to chat with any registered user.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isSelected = _selectedConversation?.id == item.id;
                        final contactName = item.getTitleForUser(me);
                        final contactAvatar = item.getAvatarForUser(me);
                        final contactUsername = item.getOtherUsername(me, ApiService.userCache);

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3)) : null,
                          ),
                          child: Material(
                            color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              leading: AvatarBadge(
                                avatarUrl: contactAvatar,
                                name: contactName,
                                radius: 20,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      contactName,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (contactUsername.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '@$contactUsername',
                                      style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.lastMessagePreview ?? 'No messages yet',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white70 : Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    DateFormat.jm().format(item.lastMessageAt),
                                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 16, color: Colors.white38),
                                color: const Color(0xFF1E293B),
                                tooltip: 'Chat options',
                                onSelected: (val) {
                                  if (val == 'DELETE') {
                                    _confirmDeleteConversation(item);
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'DELETE',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_forever, color: Color(0xFFEF4444), size: 16),
                                        SizedBox(width: 8),
                                        Text('Delete Chat', style: TextStyle(color: Color(0xFFEF4444), fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () => setState(() => _selectedConversation = item),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  void _handleDeleteConversation(ConversationModel conv) {
    setState(() {
      _conversations.removeWhere((c) => c.id == conv.id);
      if (_selectedConversation?.id == conv.id) {
        _selectedConversation = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat deleted successfully'),
        backgroundColor: Color(0xFF10B981),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _confirmDeleteConversation(ConversationModel item) {
    final me = ApiService.currentUser;
    final contactName = item.getTitleForUser(me);

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
          'Are you sure you want to delete this chat with $contactName? All messages and attachments will be permanently removed for you.',
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
              await ApiService.deleteConversation(item.id);
              _handleDeleteConversation(item);
            },
          ),
        ],
      ),
    );
  }
}

class _NewChatDialog extends StatefulWidget {
  final Function(UserModel) onUserSelected;

  const _NewChatDialog({required this.onUserSelected});

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  String _lastSearchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    final query = val.trim().replaceAll('@', '');
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      setState(() {
        _lastSearchQuery = '';
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _isLoading = true;
        _lastSearchQuery = query;
      });
      final results = await ApiService.searchUsers(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    });
  }

  void _handleUserTap(UserModel user) {
    if (user.isPrivate) {
      // Private account confirmation prompt
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF131D2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.lock_outline, color: Color(0xFFFBBF24)),
              SizedBox(width: 8),
              Text('Do you know this person?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            '@${user.username} has set their account to Private. Only proceed if you know them personally.',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(), // "No, Cancel"
              child: const Text('No, Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF06B6D4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop(); // Dismiss confirmation
                widget.onUserSelected(user); // "Yes, Continue"
              },
              child: const Text('Yes, Continue'),
            ),
          ],
        ),
      );
    } else {
      widget.onUserSelected(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = math.min(380.0, screenSize.width - 32);
    final dialogHeight = math.min(420.0, screenSize.height - 80);

    return AlertDialog(
      backgroundColor: const Color(0xFF131D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.person_search, color: Color(0xFF06B6D4)),
          SizedBox(width: 10),
          Text('Search Users', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Username Search Input
            TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search username (e.g. @alice)...',
                prefixIcon: const Icon(Icons.alternate_email, color: Color(0xFF06B6D4), size: 18),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _lastSearchQuery.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 48, color: Colors.white.withOpacity(0.15)),
                              const SizedBox(height: 10),
                              const Text(
                                'Search People by Username',
                                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Enter a username above to find matching accounts and start chatting.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _searchResults.isEmpty
                          ? Center(
                              child: Text(
                                'No users found matching "@$_lastSearchQuery"',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54, fontSize: 13),
                              ),
                            )
                          : ListView.separated(
                              itemCount: _searchResults.length,
                              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                              itemBuilder: (ctx, i) {
                                final u = _searchResults[i];
                                return ListTile(
                                  leading: AvatarBadge(
                                    avatarUrl: u.avatarUrl,
                                    name: u.displayName,
                                    radius: 18,
                                  ),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          u.displayName,
                                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '@${u.username}',
                                        style: const TextStyle(color: Color(0xFF06B6D4), fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  subtitle: Row(
                                    children: [
                                      if (u.isPrivate) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFBBF24).withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock, size: 10, color: Color(0xFFFBBF24)),
                                              SizedBox(width: 3),
                                              Text('Private', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          u.statusMessage.isNotEmpty ? u.statusMessage : 'Available',
                                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chat_bubble_outline, color: Color(0xFF06B6D4), size: 18),
                                  onTap: () => _handleUserTap(u),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
      ],
    );
  }
}

class _CreateGroupDialog extends StatefulWidget {
  final Function(ConversationModel) onGroupCreated;

  const _CreateGroupDialog({required this.onGroupCreated});

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _avatarController = TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();
  String _selectedGroupIcon = GroupIconHelper.defaultIconPreference;

  final List<UserModel> _selectedMembers = [];
  List<UserModel> _searchUsersResult = [];
  bool _isSearching = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _avatarController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  void _openGroupIconPicker() async {
    final chosen = await GroupIconPickerModal.show(
      context,
      currentIcon: _selectedGroupIcon,
      title: 'Customize New Group Icon',
    );
    if (chosen != null && mounted) {
      setState(() {
        _selectedGroupIcon = chosen;
        _avatarController.text = chosen;
      });
    }
  }

  void _searchMembers(String query) async {
    final clean = query.trim().replaceAll('@', '');
    if (clean.isEmpty) {
      setState(() => _searchUsersResult = []);
      return;
    }
    setState(() => _isSearching = true);
    final results = await ApiService.searchUsers(clean);
    if (mounted) {
      setState(() {
        _searchUsersResult = results;
        _isSearching = false;
      });
    }
  }

  void _createGroup() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isCreating = true);
    try {
      final group = await ApiService.createGroup(
        title: title,
        description: _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
        avatarUrl: _selectedGroupIcon.trim().isNotEmpty ? _selectedGroupIcon.trim() : null,
        memberIds: _selectedMembers.map((u) => u.id).toList(),
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onGroupCreated(group);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = math.min(420.0, screenSize.width - 32);
    final dialogHeight = math.min(540.0, screenSize.height - 64);

    return AlertDialog(
      backgroundColor: const Color(0xFF131D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.group_add, color: Color(0xFF10B981)),
          SizedBox(width: 10),
          Text('Create New Group', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Icon Customization
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        AvatarBadge(
                          avatarUrl: _selectedGroupIcon,
                          name: _titleController.text.trim().isNotEmpty ? _titleController.text : 'Group',
                          radius: 36,
                          isGroup: true,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _openGroupIconPicker,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFF131D2E), width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF06B6D4),
                        visualDensity: VisualDensity.compact,
                      ),
                      icon: const Icon(Icons.palette_outlined, size: 14),
                      label: const Text('Customize Group Icon', style: TextStyle(fontSize: 12)),
                      onPressed: _openGroupIconPicker,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Group Name
              const Text('Group Name *', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Cybersec Guild, Project Phoenix...',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Group Description
              const Text('Description (Optional)', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _descController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'What is this group about?',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              // Selected Members Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Selected Members', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                  Text('${_selectedMembers.length} added', style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              if (_selectedMembers.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _selectedMembers.map((u) {
                    return Chip(
                      backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                      label: Text('@${u.username}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                      onDeleted: () => setState(() => _selectedMembers.remove(u)),
                    );
                  }).toList(),
                )
              else
                const Text('No members selected yet.', style: TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
              const SizedBox(height: 12),

              // Member Search to Add
              const Text('Add Participants by Username', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _userSearchController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search username to add...',
                  prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: _searchMembers,
              ),
              const SizedBox(height: 8),

              if (_isSearching)
                const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
              else if (_searchUsersResult.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchUsersResult.length,
                    itemBuilder: (ctx, i) {
                      final u = _searchUsersResult[i];
                      final isSelected = _selectedMembers.any((m) => m.id == u.id);
                      return ListTile(
                        dense: true,
                        leading: AvatarBadge(avatarUrl: u.avatarUrl, name: u.displayName, radius: 14),
                        title: Text(u.displayName, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        subtitle: Text('@${u.username}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                        trailing: Icon(
                          isSelected ? Icons.check_circle : Icons.add_circle_outline,
                          color: isSelected ? const Color(0xFF10B981) : Colors.white38,
                          size: 18,
                        ),
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedMembers.removeWhere((m) => m.id == u.id);
                            } else {
                              _selectedMembers.add(u);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: (_titleController.text.trim().isNotEmpty && !_isCreating) ? _createGroup : null,
          child: _isCreating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Create Group'),
        ),
      ],
    );
  }
}
