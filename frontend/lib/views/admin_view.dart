import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/glass_container.dart';

class AdminView extends StatefulWidget {
  const AdminView({super.key});

  @override
  State<AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<AdminView> {
  final Map<String, bool> featureFlags = {
    'playtogether_games': true,
    'webrtc_calling': true,
    'smart_safety_guardian': true,
    'dynamic_app_identity': true,
    'cloudinary_media_upload': true,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.admin_panel_settings, color: Color(0xFF3B82F6), size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Administration & Moderation Console',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'System health, feature flags, user management, and safety telemetry',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Metrics Overview Row
          Row(
            children: [
              _buildMetricCard('Total Users', '3 Active', Icons.people, const Color(0xFF06B6D4)),
              const SizedBox(width: 16),
              _buildMetricCard('Conversations', '3 Active', Icons.chat_bubble, const Color(0xFF10B981)),
              const SizedBox(width: 16),
              _buildMetricCard('Threats Intercepted', '4 Flagged', Icons.shield, const Color(0xFFEF4444)),
              const SizedBox(width: 16),
              _buildMetricCard('System Health', '100% Online', Icons.check_circle, const Color(0xFF8B5CF6)),
            ],
          ),
          const SizedBox(height: 24),

          // Feature Flags Switchboard
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.toggle_on, color: Color(0xFF06B6D4)),
                    SizedBox(width: 8),
                    Text(
                      'Feature Flags & Release Controls',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dynamically enable or restrict modules across production clients:',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                ...featureFlags.entries.map((entry) {
                  return SwitchListTile(
                    title: Text(
                      _formatFlagName(entry.key),
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      'Module status: ${entry.value ? "Active & Serving Traffic" : "Disabled"}',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    value: entry.value,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (val) {
                      setState(() => featureFlags[entry.key] = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Updated ${_formatFlagName(entry.key)} to $val'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // User Moderation Table
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'User Management & Verification',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: NetworkImage('https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150'),
                  ),
                  title: const Text('Alex Rivers (@alex_rivers)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Administrator • Safety Score: 98%', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Text('Verified Admin', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: NetworkImage('https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150'),
                  ),
                  title: const Text('Elena Rostova (@elena_rostova)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Member • Safety Score: 94%', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF3B82F6).withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                    child: const Text('Verified User', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
                const Divider(color: Colors.white12),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150'),
                  ),
                  title: const Text('Marcus Vance (@marcus_vance)', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Member • Safety Score: 89%', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                    child: const Text('Active', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: GlassContainer(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _formatFlagName(String flag) {
    return flag.split('_').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
  }
}
