import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/glass_container.dart';
import 'admin_view.dart';
import 'chat_view.dart';
import 'identity_settings_view.dart';
import 'safety_guardian_view.dart';

enum MainNavigationTab { chats, safetyGuardian, identity, admin }

class HomeScreen extends StatefulWidget {
  final AppThemeMode currentThemeMode;
  final Function(AppThemeMode) onThemeChanged;

  const HomeScreen({
    super.key,
    required this.currentThemeMode,
    required this.onThemeChanged,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: Row(
        children: [
          // Left Icon Navigation Rail
          _buildNavRail(theme),

          // Main Interactive Layout
          Expanded(
            child: _buildMainContent(theme, isWide),
          ),
        ],
      ),
    );
  }

  Widget _buildNavRail(ThemeData theme) {
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
            tooltip: 'Chats & Games',
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
            tooltip: 'Dynamic App Identity',
          ),
          const SizedBox(height: 16),
          _buildNavRailItem(
            tab: MainNavigationTab.admin,
            icon: Icons.admin_panel_settings_outlined,
            activeIcon: Icons.admin_panel_settings,
            tooltip: 'Admin Console',
          ),

          const Spacer(),

          // Current User Profile Avatar & Online Status
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Tooltip(
              message: '${ApiService.currentUser.displayName} (Safety Score: ${ApiService.currentUser.safetyScore}%)',
              child: AvatarBadge(
                avatarUrl: ApiService.currentUser.avatarUrl,
                name: ApiService.currentUser.displayName,
                radius: 18,
              ),
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
      case MainNavigationTab.admin:
        return const AdminView();
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
                  : const Center(
                      child: Text('Select a conversation to start messaging', style: TextStyle(color: Colors.white54)),
                    ),
            ),
          ],
        );
    }
  }

  Widget _buildConversationListPane() {
    final filtered = _conversations.where((c) {
      if (_searchQuery.isEmpty) return true;
      return c.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Messages',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              TextField(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search conversations or messages...',
                  prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white38),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.04),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ],
          ),
        ),

        // Conversation items
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isSelected = _selectedConversation?.id == item.id;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)) : null,
                      ),
                      child: ListTile(
                        leading: AvatarBadge(
                          avatarUrl: item.avatarUrl,
                          name: item.title,
                          radius: 20,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
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
