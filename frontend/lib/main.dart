import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'views/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NextGenChatApp());
}

class NextGenChatApp extends StatefulWidget {
  const NextGenChatApp({super.key});

  @override
  State<NextGenChatApp> createState() => _NextGenChatAppState();
}

class _NextGenChatAppState extends State<NextGenChatApp> {
  AppThemeMode _currentThemeMode = AppThemeMode.obsidianNeon;

  void _updateTheme(AppThemeMode mode) {
    setState(() {
      _currentThemeMode = mode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatGuard Next-Gen Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(_currentThemeMode),
      home: HomeScreen(
        currentThemeMode: _currentThemeMode,
        onThemeChanged: _updateTheme,
      ),
    );
  }
}
