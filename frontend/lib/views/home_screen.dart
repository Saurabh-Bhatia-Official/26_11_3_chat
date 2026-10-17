import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/glass_container.dart';
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
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  void _loadConversations() async {
    setState(() => _isLoading = true);
    final list = await ApiService.getConversations();
    if (mounted) {
      setState(() {
        _conversations = list;
        if (list.isNotEmpty && _selectedConversation == null) {
          _selectedConversation = list.first;
        }
        _isLoading = false;
      });
    }
  }

  void _openNewChatDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => _NewChatDialog(
        onUserSelected: (selectedUser) async {
          Navigator.of(ctx).pop();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 800;
    final currentUser = ApiService.currentUser;

    return Scaffold(
      body: Row(
        children: [
          // Left Icon Navigation Rail
          _buildNavRail(theme, currentUser),

          // Main Interactive Layout
          Expanded(
            child: _buildMainContent(theme, isWide),
          ),
        ],
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
          // App Logo / Shield
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [theme.primaryColor, theme.colorScheme.secondary],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.bolt, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 28),

          // Navigation Icons
          _buildNavRailItem(
            tab: MainNavigationTab.chats,
            icon: Icons.chat_bubble_outline,
            activeIcon: Icons.chat_bubble,
            tooltip: 'Conversations & Games',
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
    switch (_currentTab) {
      case MainNavigationTab.safetyGuardian:
        return const SafetyGuardianView();
      case MainNavigationTab.identity:
        return IdentitySettingsView(
          currentThemeMode: widget.currentThemeMode,
          onThemeChanged: widget.onThemeChanged,
        );
      case MainNavigationTab.chats:
      default:
        return Row(
          children: [
            // Conversation List Sidebar
            Container(
              width: isWide ? 340 : 280,
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
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.forum_outlined, size: 64, color: Colors.white.withOpacity(0.15)),
                          const SizedBox(height: 16),
                          const Text(
                            'No conversation selected',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
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
    }
  }

  Widget _buildConversationListPane() {
    final me = ApiService.currentUser;
    final filtered = _conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      final title = c.getTitleForUser(me);
      return title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Header with "New Chat" action
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Messages',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF06B6D4), size: 26),
                tooltip: 'Start Chat with User',
                onPressed: _openNewChatDialog,
              ),
            ],
          ),
        ),

        // Search Input
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search chats...',
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
              : filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 36, color: Colors.white.withOpacity(0.2)),
                            const SizedBox(height: 12),
                            const Text(
                              'No chats yet',
                              style: TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w600),
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

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)) : null,
                          ),
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
                                Text(
                                  DateFormat.jm().format(item.lastMessageAt),
                                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              item.lastMessagePreview ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isSelected ? Colors.white70 : Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () => setState(() => _selectedConversation = item),
                          ),
                        );
                      },
                    ),
        ),
      ],
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
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _fetchUsers() async {
    final list = await ApiService.getUsers();
    final myId = ApiService.currentUser.id;
    if (mounted) {
      setState(() {
        // Exclude current user from the list
        _users = list.where((u) => u.id != myId && u.username != ApiService.currentUser.username).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF131D2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.person_add, color: Color(0xFF06B6D4)),
          SizedBox(width: 10),
          Text('Start Conversation', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 380,
        height: 320,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? const Center(
                    child: Text(
                      'No other registered users found yet.\nSign up another account to chat!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                    itemBuilder: (ctx, i) {
                      final u = _users[i];
                      return ListTile(
                        leading: AvatarBadge(
                          avatarUrl: u.avatarUrl,
                          name: u.displayName,
                          radius: 18,
                        ),
                        title: Text(u.displayName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: Text('@${u.username}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        trailing: const Icon(Icons.chat, color: Color(0xFF06B6D4), size: 18),
                        onTap: () => widget.onUserSelected(u),
                      );
                    },
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
