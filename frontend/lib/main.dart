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
              home: ValueListenableBuilder<UserModel?>(
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
              ),
            );
          },
        );
      },
    );
  }
}
