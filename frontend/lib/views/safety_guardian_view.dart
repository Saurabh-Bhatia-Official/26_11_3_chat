import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/glass_container.dart';

class SafetyGuardianView extends StatefulWidget {
  const SafetyGuardianView({super.key});

  @override
  State<SafetyGuardianView> createState() => _SafetyGuardianViewState();
}

class _SafetyGuardianViewState extends State<SafetyGuardianView> {
  final TextEditingController _urlController = TextEditingController(text: 'http://paypa1-security-check.fake/login');
  Map<String, dynamic>? _scanResult;
  bool _isScanning = false;
  List<SafetyEventModel> _events = [];
  List<EmergencyContactModel> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadContacts();
  }

  void _loadEvents() async {
    final events = await ApiService.getSafetyEvents();
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  void _loadContacts() async {
    final contacts = await ApiService.getEmergencyContacts();
    if (mounted) {
      setState(() {
        _contacts = contacts;
      });
    }
  }

  void _runLinkScan() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isScanning = true);
    final res = await ApiService.scanUrl(url);
    if (mounted) {
      setState(() {
        _scanResult = res;
        _isScanning = false;
      });
    }
  }

  void _terminateDeviceSession(String device) async {
    await ApiService.terminateSession(device);
    _loadEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kill switch triggered. Session for $device revoked.'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  void _triggerEmergencyBroadcast() async {
    await ApiService.triggerEmergencyCheckin('SAFE', 'Safety check-in verified by user');
    _loadEvents();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency check-in broadcasted to ${_contacts.length} trusted contact account(s).'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner & Safety Score
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;
              final infoWidget = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield, color: Color(0xFF10B981), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Smart Safety Guardian',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Transparent, disclosed in-app activity monitoring & risk mitigation',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actionBtn = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                icon: const Icon(Icons.verified_user, size: 18),
                label: const Text('Emergency Check-in'),
                onPressed: _triggerEmergencyBroadcast,
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoWidget,
                    const SizedBox(height: 14),
                    actionBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: infoWidget),
                  const SizedBox(width: 16),
                  actionBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Security Posture Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 750;
              final postureCard = GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 80,
                          height: 80,
                          child: CircularProgressIndicator(
                            value: 0.98,
                            strokeWidth: 8,
                            color: Color(0xFF10B981),
                            backgroundColor: Colors.white10,
                          ),
                        ),
                        Text(
                          '${ApiService.currentUser.safetyScore}%',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Security Health: Excellent',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '• Multi-factor authentication active\n• 0 unacknowledged critical alerts\n• Cloudinary signed uploads enabled',
                            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );

              final sessionsCard = GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Active Sessions',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Windows Desktop (Active)',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.power_settings_new, color: Color(0xFFEF4444), size: 18),
                          onPressed: () => _terminateDeviceSession('Windows Chrome'),
                          tooltip: 'Kill Session',
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'iPhone 15 Pro (Safari)',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.power_settings_new, color: Color(0xFFEF4444), size: 18),
                          onPressed: () => _terminateDeviceSession('iPhone 15 Pro'),
                          tooltip: 'Kill Session',
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (isStacked) {
                return Column(
                  children: [
                    postureCard,
                    const SizedBox(height: 16),
                    sessionsCard,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: postureCard),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: sessionsCard),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Link Scanner Tool Card
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.link, color: Color(0xFF06B6D4)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Live Phishing & Malicious Link Interceptor',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Test any URL to see how the Smart Safety Guardian detects homograph attacks, brand spoofing, and risky TLDs.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Enter URL (e.g. http://paypa1-security-check.fake)',
                          prefixIcon: Icon(Icons.search, color: Colors.white38),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                      onPressed: _isScanning ? null : _runLinkScan,
                      child: _isScanning
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Scan Link'),
                    ),
                  ],
                ),
                if (_scanResult != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: (_scanResult!['isSuspicious'] as bool)
                          ? const Color(0xFFEF4444).withOpacity(0.15)
                          : const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (_scanResult!['isSuspicious'] as bool)
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              (_scanResult!['isSuspicious'] as bool) ? Icons.warning : Icons.check_circle,
                              color: (_scanResult!['isSuspicious'] as bool) ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Risk Score: ${_scanResult!['riskScore']}/100 — ${(_scanResult!['isSuspicious'] as bool) ? 'HIGH THREAT DETECTED' : 'CLEAN & SAFE'}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: (_scanResult!['isSuspicious'] as bool) ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...((_scanResult!['warnings'] as List? ?? []).map((w) => Text('• $w', style: const TextStyle(color: Colors.white70, fontSize: 13)))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Emergency Contacts & Trusted Accounts Section
          GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 620;
                    final titleWidget = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.contact_emergency, color: Color(0xFFEF4444), size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Emergency Contacts & Accounts',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    );

                    final addBtn = ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1, size: 16),
                      label: const Text('Add Contact Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _showAddEmergencyContactDialog,
                    );

                    if (isCompact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          titleWidget,
                          const SizedBox(height: 12),
                          addBtn,
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: titleWidget),
                        const SizedBox(width: 12),
                        addBtn,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  'These trusted accounts and contacts receive automatic breach notifications, kill switch broadcast pings, and emergency check-in telemetry.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (_contacts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'No emergency contacts linked yet. Tap "+ Add Contact Account" above.',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _contacts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final c = _contacts[index];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
                              child: const Icon(Icons.security, color: Color(0xFFEF4444), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        c.name,
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          c.relationship,
                                          style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Account: ${c.accountOrEmail}${c.phone != null && c.phone!.isNotEmpty ? " • ${c.phone}" : ""}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                              tooltip: 'Remove Contact Account',
                              onPressed: () async {
                                await ApiService.removeEmergencyContact(c.id);
                                _loadContacts();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Security Timeline
          const Text(
            'Security Activity Timeline',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final ev = _events[index];
                    return GlassContainer(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ev.getSeverityColor().withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.notification_important, color: ev.getSeverityColor(), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      ev.eventType,
                                      style: TextStyle(color: ev.getSeverityColor(), fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    Text(
                                      DateFormat.yMMMd().add_jm().format(ev.createdAt),
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(ev.description, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                if (ev.ipAddress != null) ...[
                                  const SizedBox(height: 4),
                                  Text('Origin IP: ${ev.ipAddress}', style: const TextStyle(color: Colors.white38, fontSize: 11)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  void _showAddEmergencyContactDialog() {
    final nameCtrl = TextEditingController();
    final accountCtrl = TextEditingController();
    final relationCtrl = TextEditingController(text: 'Security Lead');
    final phoneCtrl = TextEditingController();
    bool notify = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_moderator, color: Color(0xFFEF4444)),
              SizedBox(width: 10),
              Text('Add Emergency Account', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Link a trusted contact or security team account to receive emergency check-in notifications and breach telemetry.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Contact / Organization Name',
                    hintText: 'e.g. Sarah Connor / SecOps Guild',
                    prefixIcon: Icon(Icons.person, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: accountCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Account Username or Email',
                    hintText: 'e.g. secops@chatguard.io or @secops',
                    prefixIcon: Icon(Icons.alternate_email, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: relationCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Relationship / Role',
                    hintText: 'e.g. Backup Officer, Family, Lead Admin',
                    prefixIcon: Icon(Icons.badge, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Phone Number (Optional for SMS)',
                    hintText: 'e.g. +1 (555) 019-2834',
                    prefixIcon: Icon(Icons.phone, color: Colors.white70),
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: notify,
                  title: const Text('Send Instant Alerts & Breach Signals', style: TextStyle(color: Colors.white, fontSize: 12)),
                  subtitle: const Text('Dispatches encrypted alerts on suspicious activity', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  activeColor: const Color(0xFFEF4444),
                  onChanged: (val) => setDlgState(() => notify = val ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final account = accountCtrl.text.trim();
                if (name.isEmpty || account.isEmpty) return;

                await ApiService.addEmergencyContact(
                  name: name,
                  accountOrEmail: account,
                  relationship: relationCtrl.text.trim().isNotEmpty ? relationCtrl.text.trim() : 'Trusted Contact',
                  phone: phoneCtrl.text.trim(),
                  notifyOnAlert: notify,
                );

                if (context.mounted) {
                  Navigator.pop(ctx);
                  _loadContacts();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Emergency contact account "$name" linked successfully.'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              },
              child: const Text('Add Account'),
            ),
          ],
        ),
      ),
    );
  }
}
