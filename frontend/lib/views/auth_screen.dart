import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_container.dart';
import '../widgets/network_status_banner.dart';
import '../widgets/software_logo_widget.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Sign In Controllers
  final TextEditingController _loginUsernameController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  // Sign Up Controllers
  final TextEditingController _signupUsernameController = TextEditingController();
  final TextEditingController _signupNameController = TextEditingController();
  final TextEditingController _signupEmailController = TextEditingController();
  final TextEditingController _signupPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() async {
    final creds = await ApiService.getSavedCredentials();
    if (mounted) {
      setState(() {
        if (creds['username'] != null && creds['username']!.isNotEmpty) {
          _loginUsernameController.text = creds['username']!;
        }
        if (creds['password'] != null && creds['password']!.isNotEmpty) {
          _loginPasswordController.text = creds['password']!;
        }
        _rememberMe = creds['rememberMe'] != 'false';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _signupUsernameController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter your username');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.login(
        username: username,
        password: password,
        rememberMe: _rememberMe,
      );
      if (mounted) {
        widget.onAuthenticated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleSignup() async {
    final username = _signupUsernameController.text.trim();
    final displayName = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text;

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Username is required');
      return;
    }

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Password is required');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.signup(
        username: username,
        displayName: displayName.isNotEmpty ? displayName : username,
        email: email,
        password: password,
      );
      if (mounted) {
        widget.onAuthenticated();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      body: SafeArea(
        child: Column(
          children: [
            const NetworkStatusBanner(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Dynamic App Logo and Software Name
                const SoftwareLogoWidget(size: 68, iconSize: 36, borderRadius: 20),
                const SizedBox(height: 16),
                ValueListenableBuilder<String>(
                  valueListenable: ApiService.softwareNameNotifier,
                  builder: (context, softwareName, _) {
                    return Text(
                      softwareName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                const Text(
                  'Real-time conversations with registered users',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Main Auth Glass Container
                GlassContainer(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Tab Bar (Sign In / Sign Up)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          tabs: const [
                            Tab(text: 'Sign In'),
                            Tab(text: 'Create Account'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),

                      SizedBox(
                        height: 330,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Sign In Tab View
                            _buildSignInTab(),

                            // Sign Up Tab View
                            _buildSignUpTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    ],
    ),
    ),
    );
  }

  Widget _buildSignInTab() {
    return Column(
      children: [
        TextField(
          controller: _loginUsernameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Username',
            hintText: 'Enter your registered username',
            prefixIcon: Icon(Icons.person, color: Colors.white60),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _loginPasswordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock, color: Colors.white60),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: Colors.white60,
                size: 18,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: Checkbox(
                value: _rememberMe,
                activeColor: Theme.of(context).primaryColor,
                checkColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() => _rememberMe = val ?? true);
                },
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              child: const Text(
                'Remember my login on this device',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _handleLogin,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Sign In to Chat', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _signupUsernameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'Choose a unique username',
              prefixIcon: Icon(Icons.person, color: Colors.white60),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _signupNameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'Your name shown to other users',
              prefixIcon: Icon(Icons.badge, color: Colors.white60),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _signupPasswordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock, color: Colors.white60),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _handleSignup,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Create Account & Enter', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
