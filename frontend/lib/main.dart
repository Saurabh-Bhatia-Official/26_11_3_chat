import 'package:flutter/material.dart';
import 'models/models.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'views/auth_screen.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initSession();
  runApp(const NextGenChatApp());
}

class NextGenChatApp extends StatelessWidget {
  const NextGenChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ApiService.softwareNameNotifier,
      builder: (context, currentSoftwareName, _) {
        return ValueListenableBuilder<AppThemeMode>(
          valueListenable: AppTheme.currentThemeNotifier,
          builder: (context, currentThemeMode, _) {
            return MaterialApp(
              title: currentSoftwareName,
              debugShowCheckedModeBanner: false,
              theme: AppTheme.getTheme(currentThemeMode),
              home: ValueListenableBuilder<bool>(
                valueListenable: ApiService.isAuthInitializingNotifier,
                builder: (context, isInitializing, _) {
                  if (isInitializing) {
                    return Scaffold(
                      backgroundColor: const Color(0xFF070B12),
                      body: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: const Color(0xFF06B6D4).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: Color(0xFF06B6D4),
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 24),
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Color(0xFF06B6D4),
                                strokeWidth: 2.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ValueListenableBuilder<UserModel?>(
                    valueListenable: ApiService.currentUserNotifier,
                    builder: (context, user, _) {
                      if (user == null) {
                        return AuthScreen(
                          onAuthenticated: () {},
                        );
                      }
                      return HomeScreen(
                        currentThemeMode: currentThemeMode,
                        onThemeChanged: (mode) => AppTheme.setTheme(mode),
                        onLogout: () {
                          ApiService.logout();
                        },
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
