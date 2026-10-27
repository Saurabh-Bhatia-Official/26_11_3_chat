import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import 'app_branding/app_branding.dart';
import 'network_service.dart';
import 'connectivity/connectivity_platform.dart';
import 'group_icon_helper.dart';

class ApiService {
  // Configurable backend URL (reads from frontend/.env or defaults to Render backend)
  static String baseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://whisper-7a0e.onrender.com/api',
  );

  // Preference Storage Keys
  static const String _keyUser = 'saved_auth_user_json';
  static const String _keyToken = 'saved_auth_jwt_token';
  static const String _keySavedUsername = 'saved_auth_username';
  static const String _keySavedPassword = 'saved_auth_password';
  static const String _keyRememberMe = 'saved_auth_remember_me';
  static const String _keySoftwareName = 'custom_software_name';
  static const String _keyCustomLogo = 'custom_software_logo_data';

  // Default branding applied when not logged in or after logout
  static const String defaultSoftwareName = 'Whisper';
  static const String defaultAppIcon = 'whisper';

  // Dynamic Software Name & Logo State across entire software
  static final ValueNotifier<String> softwareNameNotifier = ValueNotifier<String>(defaultSoftwareName);
  static String get softwareName => softwareNameNotifier.value;

  static final ValueNotifier<String?> customLogoDataNotifier = ValueNotifier<String?>(null);
  static String? get customLogoData => customLogoDataNotifier.value;

  // Dynamic Auth State (null = not logged in)
  static final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier<UserModel?>(null);

  // Auth Session Initialization State (prevents flashing login screen on app start)
  static final ValueNotifier<bool> isAuthInitializingNotifier = ValueNotifier<bool>(true);
  static bool get isAuthInitializing => isAuthInitializingNotifier.value;

  // JWT Token Management
  static String? _authToken;
  static String? get authToken => _authToken;

  static Map<String, String> get authHeaders {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
      'Pragma': 'no-cache',
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_authToken';
    }
    return headers;
  }

  // Dynamic App Icon State across entire software
  static final ValueNotifier<String> currentAppIconNotifier = ValueNotifier<String>(defaultAppIcon);
  static String get currentAppIcon => currentAppIconNotifier.value;

  // Persistent Group Icon State across entire software
  static ValueNotifier<String> get currentGroupIconNotifier => GroupIconHelper.persistentGroupIconNotifier;
  static String get currentGroupIcon => GroupIconHelper.currentGroupIcon;
  static Future<void> setPersistentGroupIcon(String iconValue) async => GroupIconHelper.savePersistentGroupIcon(iconValue);

  static UserModel get currentUser => currentUserNotifier.value ?? UserModel(id: 'u_default', username: 'guest', displayName: 'Guest User');
  static set currentUser(UserModel user) {
    currentUserNotifier.value = user;

    // After login only: Change the icon and title of the software, app, and website as per the account data
    if (user.softwareName != null && user.softwareName!.trim().isNotEmpty) {
      softwareNameNotifier.value = user.softwareName!.trim();
    } else {
      softwareNameNotifier.value = defaultSoftwareName;
    }

    if (user.customLogoUrl != null && user.customLogoUrl!.trim().isNotEmpty) {
      customLogoDataNotifier.value = user.customLogoUrl!.trim();
    } else {
      customLogoDataNotifier.value = null;
    }

    if (user.appIconPreference.isNotEmpty) {
      currentAppIconNotifier.value = user.appIconPreference;
    } else {
      currentAppIconNotifier.value = defaultAppIcon;
    }

    if (user.themePreference.isNotEmpty) {
      AppTheme.currentThemeNotifier.value = AppTheme.fromString(user.themePreference);
    }

    // Sync to website browser tab title and favicon
    syncBrandingToPlatform();
  }

  /// Resets title, app logo, and website favicon back to defaults when logged out
  static void resetBrandingToDefault() {
    softwareNameNotifier.value = defaultSoftwareName;
    customLogoDataNotifier.value = null;
    currentAppIconNotifier.value = defaultAppIcon;
    syncBrandingToPlatform();
  }

  // Local caching to support offline UI resilience
  static final List<ConversationModel> _localConversations = [];
  static final Map<String, List<MessageModel>> _localMessages = {};

  // ==========================================
  // AUTHENTICATION & CLOUD PERSISTENCE
  // ==========================================

  /// Synchronizes dynamic title and favicon to the web page/platform and native Android launcher icon
  static void syncBrandingToPlatform() {
    try {
      final iconUrl = customLogoData ?? AppIconHelper.getPresetSvgFaviconDataUri(currentAppIcon);
      AppBrandingPlatform.updateWebBranding(
        title: softwareName,
        iconDataUrl: iconUrl,
      );
      AppBrandingPlatform.updateAndroidLauncherIcon(currentAppIcon);
    } catch (e) {
      debugPrint('Error syncing branding to platform: $e');
    }
  }

  /// Fetches system branding (software name, system logo, color theme, appearance) from cloud database
  static Future<void> fetchCloudBranding() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/system/branding')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();

        if (data['softwareName'] != null && (data['softwareName'] as String).trim().isNotEmpty) {
          final name = (data['softwareName'] as String).trim();
          softwareNameNotifier.value = name;
          await prefs.setString(_keySoftwareName, name);
        }

        if (data['customLogoUrl'] != null && (data['customLogoUrl'] as String).isNotEmpty) {
          final logo = data['customLogoUrl'] as String;
          customLogoDataNotifier.value = logo;
          await prefs.setString(_keyCustomLogo, logo);
        }

        if (data['themePreference'] != null && (data['themePreference'] as String).isNotEmpty) {
          final themeStr = data['themePreference'] as String;
          final mode = AppTheme.fromString(themeStr);
          AppTheme.currentThemeNotifier.value = mode;
          await prefs.setString('theme_preference', mode.name);
        }

        if (data['appIconPreference'] != null && (data['appIconPreference'] as String).isNotEmpty) {
          final icon = data['appIconPreference'] as String;
          currentAppIconNotifier.value = icon;
          await prefs.setString('app_icon_preference', icon);
        }

        syncBrandingToPlatform();
      }
    } catch (e) {
      debugPrint('Cloud branding fetch notice: $e');
    }
  }

  /// Pushes branding, logo, theme, and appearance preferences to cloud database
  static Future<void> syncBrandingToCloud({
    String? softwareName,
    String? customLogoUrl,
    String? themePreference,
    String? appIconPreference,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (softwareName != null) 'softwareName': softwareName,
        if (customLogoUrl != null) 'customLogoUrl': customLogoUrl,
        if (themePreference != null) 'themePreference': themePreference,
        if (appIconPreference != null) 'appIconPreference': appIconPreference,
      };

      if (payload.isNotEmpty) {
        http.post(
          Uri.parse('$baseUrl/system/branding'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).catchError((_) => http.Response('{}', 500));
      }
    } catch (e) {
      debugPrint('Cloud branding sync notice: $e');
    }
  }

  /// Initializes saved session from SharedPreferences and syncs with cloud database
  static Future<bool> initSession() async {
    try {
      AppTheme.onThemeChanged = (mode) {
        if (currentUserNotifier.value != null) {
          updateProfile(themePreference: mode.name);
        }
      };

      // Ensure we start with default software name, app icon, and website branding before login
      resetBrandingToDefault();

      // Initialize network and connectivity monitoring
      NetworkService.initialize(baseUrl: baseUrl);

      // Initialize and load persistent group icon from storage
      await GroupIconHelper.initPersistentGroupIcon();

      final prefs = await SharedPreferences.getInstance();

      final savedToken = prefs.getString(_keyToken);
      if (savedToken != null && savedToken.isNotEmpty) {
        _authToken = savedToken;
      }

      final userJson = prefs.getString(_keyUser);
      if (userJson != null && userJson.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(userJson);
        final user = UserModel.fromJson(data);
        // ONLY apply account-specific title and icon when a logged-in user exists
        currentUser = user;
        userCache[user.id] = user;

        // Refresh latest account information from server in background if token exists
        if (_authToken != null && _authToken!.isNotEmpty) {
          fetchAccount().catchError((_) => user);
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error restoring saved session: $e');
    } finally {
      isAuthInitializingNotifier.value = false;
    }
    return false;
  }

  /// Attempts to refresh the JWT auth token using the backend refresh endpoint
  static Future<bool> refreshToken() async {
    if (_authToken == null || _authToken!.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final newToken = data['token']?.toString();
        if (newToken != null && newToken.isNotEmpty) {
          _authToken = newToken;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyToken, newToken);
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
    }
    return false;
  }

  /// Fetches the currently authenticated account from backend using JWT token
  static Future<UserModel?> fetchAccount() async {
    if (_authToken == null || _authToken!.isEmpty) return null;
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/auth/account'),
        headers: authHeaders,
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final user = UserModel.fromJson(data['user'] ?? data);
        currentUser = user;
        userCache[user.id] = user;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonEncode(user.toJson()));
        return user;
      } else if (res.statusCode == 401) {
        // Attempt token refresh first
        final refreshed = await refreshToken();
        if (refreshed) {
          final retryRes = await http.get(
            Uri.parse('$baseUrl/auth/account'),
            headers: authHeaders,
          ).timeout(const Duration(seconds: 5));

          if (retryRes.statusCode == 200) {
            final data = jsonDecode(retryRes.body);
            final user = UserModel.fromJson(data['user'] ?? data);
            currentUser = user;
            userCache[user.id] = user;

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_keyUser, jsonEncode(user.toJson()));
            return user;
          }
        }

        // If refresh fails, try re-authenticating with remembered credentials
        final creds = await getSavedCredentials();
        if (creds['rememberMe'] == 'true' &&
            creds['username'] != null &&
            creds['username']!.isNotEmpty &&
            creds['password'] != null &&
            creds['password']!.isNotEmpty) {
          try {
            final reLoggedInUser = await login(
              username: creds['username']!,
              password: creds['password']!,
              rememberMe: true,
            );
            return reLoggedInUser;
          } catch (e) {
            debugPrint('Auto re-login with remembered credentials failed: $e');
          }
        }

        // Only logout when session is permanently invalid
        await logout();
        return null;
      }
    } catch (e) {
      // Retain offline cached user on network failures or temporary timeouts
      debugPrint('Notice on fetching account via JWT (offline/network): $e');
    }
    return currentUserNotifier.value;
  }

  /// Sets custom software name across app, browser tab, and account data
  static Future<void> setSoftwareName(String name) async {
    final trimmed = name.trim().isEmpty ? defaultSoftwareName : name.trim();
    softwareNameNotifier.value = trimmed;
    syncBrandingToPlatform();
    if (currentUserNotifier.value != null) {
      await updateProfile(softwareName: trimmed);
    }
  }

  /// Sets custom software logo URL across app, browser favicon, and account data
  static Future<void> setCustomLogo(String? logoDataUrl) async {
    final cleanLogo = (logoDataUrl != null && logoDataUrl.trim().isNotEmpty) ? logoDataUrl.trim() : null;
    customLogoDataNotifier.value = cleanLogo;
    syncBrandingToPlatform();
    if (currentUserNotifier.value != null) {
      await updateProfile(customLogoUrl: cleanLogo ?? '');
    }
  }

  /// Resets to default preset icons
  static Future<void> resetCustomLogo() async {
    await setCustomLogo(null);
  }

  /// Sets active app icon preference for the logged in account
  static Future<void> setAppIcon(String iconId) async {
    currentAppIconNotifier.value = iconId;
    syncBrandingToPlatform();
    if (currentUserNotifier.value != null) {
      await updateProfile(appIconPreference: iconId);
    }
  }

  /// Sets active theme mode globally across the entire software and cloud
  static Future<void> setThemeMode(AppThemeMode mode) async {
    await AppTheme.setTheme(mode);
  }

  /// Retrieves remembered credentials for auto-fill
  static Future<Map<String, String>> getSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_keySavedUsername) ?? '';
      final password = prefs.getString(_keySavedPassword) ?? '';
      final rememberMe = (prefs.getBool(_keyRememberMe) ?? true).toString();
      return {
        'username': username,
        'password': password,
        'rememberMe': rememberMe,
      };
    } catch (_) {
      return {'username': '', 'password': '', 'rememberMe': 'true'};
    }
  }

  static Future<UserModel> login({
    required String username,
    required String password,
    bool rememberMe = true,
  }) async {
    return NetworkService.execute<UserModel>(
      request: () => http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username.trim(), 'password': password}),
      ).timeout(const Duration(seconds: 5)),
      onSuccess: (res) async {
        final data = jsonDecode(res.body);
        final token = data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          _authToken = token;
        }

        final user = UserModel.fromJson(data['user'] ?? data);

        // Clear previous account's cached state
        _localConversations.clear();
        _localMessages.clear();

        // Dynamically switch current account state and theme across software
        currentUser = user;
        userCache[user.id] = user;

        // Persist session & credentials
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonEncode(user.toJson()));
        if (token != null && token.isNotEmpty) {
          await prefs.setString(_keyToken, token);
        }
        await prefs.setBool(_keyRememberMe, rememberMe);
        if (rememberMe) {
          await prefs.setString(_keySavedUsername, username.trim());
          await prefs.setString(_keySavedPassword, password);
        } else {
          await prefs.remove(_keySavedUsername);
          await prefs.remove(_keySavedPassword);
        }

        syncBrandingToPlatform();
        return user;
      },
      defaultErrorMessage: 'Login failed',
    );
  }

  static Future<UserModel> signup({
    required String username,
    required String displayName,
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    return NetworkService.execute<UserModel>(
      request: () => http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'displayName': displayName.trim().isNotEmpty ? displayName.trim() : username.trim(),
          'email': email.trim().isNotEmpty ? email.trim() : '${username.trim()}@chat.io',
          'password': password,
        }),
      ).timeout(const Duration(seconds: 5)),
      onSuccess: (res) async {
        final data = jsonDecode(res.body);
        final token = data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          _authToken = token;
        }

        final user = UserModel.fromJson(data['user'] ?? data);

        // Clear previous account's cached state
        _localConversations.clear();
        _localMessages.clear();

        currentUser = user;
        userCache[user.id] = user;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUser, jsonEncode(user.toJson()));
        if (token != null && token.isNotEmpty) {
          await prefs.setString(_keyToken, token);
        }
        await prefs.setBool(_keyRememberMe, rememberMe);
        if (rememberMe) {
          await prefs.setString(_keySavedUsername, username.trim());
          await prefs.setString(_keySavedPassword, password);
        }

        syncBrandingToPlatform();
        return user;
      },
      defaultErrorMessage: 'Sign up failed',
    );
  }

  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyUser);
      await prefs.remove(_keyToken);
    } catch (e) {
      debugPrint('Error clearing saved session: $e');
    }
    _authToken = null;
    currentUserNotifier.value = null;
    _localConversations.clear();
    _localMessages.clear();
    // After logout: Immediately reset software name, icon, and website branding back to default
    resetBrandingToDefault();
  }

  /// Uploads media bytes (images, voice, audio, documents) to Cloudinary cloud storage.
  /// Returns the secure Cloudinary HTTPS CDN URL or null on failure.
  static Future<String?> uploadMedia(Uint8List bytes, String filename) async {
    try {
      final uri = Uri.parse('$baseUrl/media/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['url'] != null) {
          return data['url'] as String;
        }
      } else {
        final err = await NetworkService.getErrorMessage(null, response: response);
        throw BackendApplicationException(err, statusCode: response.statusCode);
      }
    } catch (e) {
      if (e is AppException) rethrow;
      final hasInternet = await ConnectivityPlatform.isInternetConnected();
      if (!hasInternet) {
        throw NoInternetException();
      } else {
        throw ServerUnavailableException();
      }
    }
    return null;
  }

  // ==========================================
  // USERS & CONVERSATIONS
  // ==========================================

  static final Map<String, UserModel> userCache = {};

  static Future<List<UserModel>> getUsers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/auth/users')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        final users = list.map((item) => UserModel.fromJson(item)).toList();
        for (final u in users) {
          userCache[u.id] = u;
        }
        return users;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<UserModel>> searchUsers(String query) async {
    final cleanQuery = query.trim().replaceAll('@', '');
    if (cleanQuery.isEmpty) return [];
    try {
      final me = currentUser;
      final uri = Uri.parse('$baseUrl/auth/search?query=${Uri.encodeComponent(cleanQuery)}&currentUserId=${me.id}');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        final users = list.map((item) => UserModel.fromJson(item)).toList();
        for (final u in users) {
          userCache[u.id] = u;
        }
        return users;
      }
    } catch (_) {}
    return [];
  }

  static Future<List<ConversationModel>> getConversations({bool throwOnError = false}) async {
    try {
      return await NetworkService.execute<List<ConversationModel>>(
        request: () {
          final user = currentUser;
          final userId = user.id;
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final uri = Uri.parse('$baseUrl/chat/conversations?userId=$userId&_t=$timestamp');

          return http.get(
            uri,
            headers: {
              ...authHeaders,
              'Cache-Control': 'no-cache, no-store, must-revalidate',
              'Pragma': 'no-cache',
              'Expires': '0',
            },
          ).timeout(const Duration(seconds: 8));
        },
        onSuccess: (res) {
          final List list = jsonDecode(res.body);
          final convs = list.map((item) => ConversationModel.fromJson(item)).toList();
          _localConversations.clear();
          _localConversations.addAll(convs);
          return convs;
        },
      );
    } catch (e) {
      if (throwOnError || _localConversations.isEmpty) {
        rethrow;
      }
      return List<ConversationModel>.from(_localConversations);
    }
  }

  static Future<ConversationModel> createConversation({
    required UserModel targetUser,
  }) async {
    final me = currentUser;
    final payload = {
      'title': targetUser.displayName,
      'isGroup': false,
      'avatarUrl': targetUser.avatarUrl,
      'createdBy': me.id,
      'participant1Id': me.id,
      'participant1Name': me.displayName,
      'participant1Avatar': me.avatarUrl,
      'participant2Id': targetUser.id,
      'participant2Name': targetUser.displayName,
      'participant2Avatar': targetUser.avatarUrl,
    };

    return NetworkService.execute<ConversationModel>(
      request: () => http.post(
        Uri.parse('$baseUrl/chat/conversations'),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8)),
      onSuccess: (res) {
        final conv = ConversationModel.fromJson(jsonDecode(res.body));
        _localConversations.removeWhere((c) => c.id == conv.id);
        _localConversations.insert(0, conv);
        return conv;
      },
      defaultErrorMessage: 'Failed to create conversation',
    );
  }

  static Future<bool> deleteConversation(String conversationId) async {
    final me = currentUser;
    _localConversations.removeWhere((c) => c.id == conversationId);
    _localMessages.remove(conversationId);
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/chat/conversations/$conversationId?userId=${me.id}'),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // MESSAGES
  // ==========================================

  static List<MessageModel> _mergeAndDeduplicate(List<MessageModel> serverMsgs, List<MessageModel> localMsgs) {
    final result = <MessageModel>[];
    final seenIds = <String>{};

    for (final m in serverMsgs) {
      if (seenIds.add(m.id)) {
        result.add(m);
      }
    }

    for (final m in localMsgs) {
      if (m.id.startsWith('msg_')) {
        final alreadyCommitted = result.any((s) =>
            s.senderId == m.senderId &&
            s.content == m.content &&
            s.createdAt.difference(m.createdAt).abs().inSeconds <= 4);
        if (!alreadyCommitted && seenIds.add(m.id)) {
          result.add(m);
        }
      }
    }

    result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  static Future<List<MessageModel>> getMessages(String conversationId) async {
    final me = currentUser;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uri = Uri.parse('$baseUrl/chat/conversations/$conversationId/messages?userId=${me.id}&_t=$timestamp');
      final res = await http.get(
        uri,
        headers: {
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
        },
      ).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        final msgs = list
            .map((item) => MessageModel.fromJson(item))
            .where((m) => !m.isDeletedForMe(me.id))
            .toList();
        final localExisting = _localMessages[conversationId] ?? [];
        _localMessages[conversationId] = _mergeAndDeduplicate(msgs, localExisting);
        return List<MessageModel>.from(_localMessages[conversationId]!);
      }
    } catch (_) {}
    final local = _localMessages[conversationId] ?? [];
    return List<MessageModel>.from(local.where((m) => !m.isDeletedForMe(me.id)));
  }

  static Future<MessageModel> sendMessage(
    String conversationId,
    String content, {
    MessageType type = MessageType.text,
    String? mediaUrl,
  }) async {
    final me = currentUser;
    final tempId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    MessageModel finalMsg = MessageModel(
      id: tempId,
      conversationId: conversationId,
      senderId: me.id,
      senderName: me.displayName,
      senderAvatarUrl: me.avatarUrl,
      content: content,
      type: type,
      mediaUrl: mediaUrl,
      safetyFlagged: content.contains('fake') || content.contains('phish') || content.contains('paypa1'),
      createdAt: DateTime.now(),
    );

    // Save locally immediately for optimistic UI response
    _localMessages.putIfAbsent(conversationId, () => []);
    _localMessages[conversationId]!.add(finalMsg);

    // Post to Spring Boot backend
    finalMsg = await NetworkService.execute<MessageModel>(
      request: () => http.post(
        Uri.parse('$baseUrl/chat/conversations/$conversationId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
        },
        body: jsonEncode({
          'senderId': me.id,
          'senderName': me.displayName,
          'senderAvatarUrl': me.avatarUrl,
          'content': content,
          'type': type == MessageType.gameInvite ? 'GAME_INVITE' : type.name.toUpperCase(),
          'mediaUrl': mediaUrl,
        }),
      ).timeout(const Duration(seconds: 8)),
      onSuccess: (res) {
        final serverMsg = MessageModel.fromJson(jsonDecode(res.body));
        _localMessages[conversationId]!.removeWhere((m) => m.id == tempId || m.id == serverMsg.id);
        _localMessages[conversationId]!.add(serverMsg);
        _localMessages[conversationId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return serverMsg;
      },
    );

    // Update conversation preview
    final convIndex = _localConversations.indexWhere((c) => c.id == conversationId);
    if (convIndex != -1) {
      final c = _localConversations[convIndex];
      _localConversations[convIndex] = ConversationModel(
        id: c.id,
        title: c.title,
        description: c.description,
        isGroup: c.isGroup,
        avatarUrl: c.avatarUrl,
        participant1Id: c.participant1Id,
        participant2Id: c.participant2Id,
        groupAdminIds: c.groupAdminIds,
        participantIds: c.participantIds,
        lastMessagePreview: content,
        lastMessageAt: DateTime.now(),
      );
    }

    return finalMsg;
  }

  // ==========================================
  // MESSAGE EDIT & DELETE
  // ==========================================

  static Future<MessageModel?> editMessage(String messageId, String newContent) async {
    final me = currentUser;
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/chat/messages/$messageId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderId': me.id,
          'content': newContent,
        }),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final updatedMsg = MessageModel.fromJson(jsonDecode(res.body));
        _updateMessageInLocalCache(updatedMsg);
        return updatedMsg;
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Failed to edit message');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> deleteMessageForMe(String messageId, String conversationId) async {
    final me = currentUser;
    if (_localMessages.containsKey(conversationId)) {
      _localMessages[conversationId]!.removeWhere((m) => m.id == messageId);
    }
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/chat/messages/$messageId/me?userId=${me.id}'),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteMessageForEveryone(String messageId, String conversationId) async {
    final me = currentUser;
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/chat/messages/$messageId/everyone?userId=${me.id}'),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        if (_localMessages.containsKey(conversationId)) {
          final list = _localMessages[conversationId]!;
          final idx = list.indexWhere((m) => m.id == messageId);
          if (idx != -1) {
            final old = list[idx];
            list[idx] = MessageModel(
              id: old.id,
              conversationId: old.conversationId,
              senderId: old.senderId,
              senderName: old.senderName,
              senderAvatarUrl: old.senderAvatarUrl,
              content: 'This message was deleted',
              type: old.type,
              mediaUrl: null,
              isDeleted: true,
              isEdited: old.isEdited,
              editedAt: old.editedAt,
              deletedForUserIds: old.deletedForUserIds,
              deliveryStatus: old.deliveryStatus,
              createdAt: old.createdAt,
            );
          }
        }
        return true;
      } else {
        final err = jsonDecode(res.body);
        throw Exception(err['error'] ?? 'Could not delete for everyone');
      }
    } catch (e) {
      rethrow;
    }
  }

  static void _updateMessageInLocalCache(MessageModel updated) {
    if (_localMessages.containsKey(updated.conversationId)) {
      final list = _localMessages[updated.conversationId]!;
      final idx = list.indexWhere((m) => m.id == updated.id);
      if (idx != -1) {
        list[idx] = updated;
      }
    }
  }

  // ==========================================
  // GROUP MANAGEMENT
  // ==========================================

  static Future<ConversationModel> createGroup({
    required String title,
    String? description,
    String? avatarUrl,
    required List<String> memberIds,
  }) async {
    final me = currentUser;
    final allMembers = {me.id, ...memberIds}.toList();
    final cleanTitle = title.trim().isNotEmpty ? title.trim() : 'New Group';
    final cleanDesc = (description != null && description.trim().isNotEmpty) ? description.trim() : null;
    final cleanAvatar = (avatarUrl != null && avatarUrl.trim().isNotEmpty) ? avatarUrl.trim() : null;

    final payload = {
      'title': cleanTitle,
      'description': cleanDesc,
      'avatarUrl': cleanAvatar,
      'adminId': me.id,
      'requesterId': me.id,
      'memberIds': allMembers,
    };

    return NetworkService.execute<ConversationModel>(
      request: () => http.post(
        Uri.parse('$baseUrl/chat/groups'),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 8)),
      onSuccess: (res) {
        final conv = ConversationModel.fromJson(jsonDecode(res.body));
        _localConversations.removeWhere((c) => c.id == conv.id);
        _localConversations.insert(0, conv);
        return conv;
      },
      defaultErrorMessage: 'Failed to create group',
    );
  }

  static Future<List<GroupMemberModel>> getGroupMembers(String conversationId) async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/chat/groups/$conversationId/members'),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => GroupMemberModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> addGroupMember(String conversationId, String targetUserId) async {
    final me = currentUser;
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/chat/groups/$conversationId/members'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'adminId': me.id,
          'requesterId': me.id,
          'userId': targetUserId,
        }),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> removeGroupMember(String conversationId, String targetUserId) async {
    final me = currentUser;
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/chat/groups/$conversationId/members/$targetUserId?adminId=${me.id}&requesterId=${me.id}'),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> leaveGroup(String conversationId) async {
    final me = currentUser;
    try {
      final res = await http.delete(
        Uri.parse('$baseUrl/chat/groups/$conversationId/members/${me.id}?adminId=${me.id}&requesterId=${me.id}'),
      ).timeout(const Duration(seconds: 5));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<ConversationModel> updateGroupInfo(
    String conversationId, {
    String? title,
    String? description,
    String? avatarUrl,
  }) async {
    final me = currentUser;
    try {
      final res = await http.put(
        Uri.parse('$baseUrl/chat/groups/$conversationId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'adminId': me.id,
          'requesterId': me.id,
          if (title != null) 'title': title,
          if (description != null) 'description': description,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
        }),
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final updated = ConversationModel.fromJson(jsonDecode(res.body));
        final idx = _localConversations.indexWhere((c) => c.id == conversationId);
        if (idx != -1) {
          _localConversations[idx] = updated;
        }
        return updated;
      }
    } catch (_) {}

    final idx = _localConversations.indexWhere((c) => c.id == conversationId);
    if (idx != -1) {
      final existing = _localConversations[idx];
      final updated = ConversationModel(
        id: existing.id,
        title: title ?? existing.title,
        description: description ?? existing.description,
        isGroup: true,
        avatarUrl: avatarUrl ?? existing.avatarUrl,
        participant1Id: existing.participant1Id,
        participant1Name: existing.participant1Name,
        participant1Avatar: existing.participant1Avatar,
        groupAdminIds: existing.groupAdminIds,
        participantIds: existing.participantIds,
        lastMessagePreview: existing.lastMessagePreview,
        lastMessageAt: existing.lastMessageAt,
      );
      _localConversations[idx] = updated;
      return updated;
    }
    throw Exception('Failed to update group');
  }

  // ==========================================
  // AUDIO & VIDEO CALLING
  // ==========================================

  static Future<CallSessionModel> initiateCall({
    required String conversationId,
    required String receiverId,
    required String receiverName,
    required String callType,
  }) async {
    final me = currentUser;
    final payload = {
      'conversationId': conversationId,
      'callerId': me.id,
      'callerName': me.displayName,
      'callerAvatarUrl': me.avatarUrl,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'callType': callType,
    };
    final res = await http.post(
      Uri.parse('$baseUrl/calls'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 6));

    if (res.statusCode == 200) {
      return CallSessionModel.fromJson(jsonDecode(res.body));
    } else if (res.statusCode == 409) {
      // Recipient is busy
      return CallSessionModel.fromJson(jsonDecode(res.body));
    } else {
      final err = jsonDecode(res.body);
      throw Exception(err['error'] ?? 'Could not initiate call');
    }
  }

  static Future<CallSessionModel?> acceptCall(String callId) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/calls/$callId/accept')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return CallSessionModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<CallSessionModel?> rejectCall(String callId) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/calls/$callId/reject')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return CallSessionModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<CallSessionModel?> cancelCall(String callId) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/calls/$callId/cancel')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return CallSessionModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<CallSessionModel?> timeoutCall(String callId) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/calls/$callId/timeout')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return CallSessionModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<CallSessionModel?> endCall(String callId, {int durationSeconds = 0}) async {
    try {
      final res = await http.post(Uri.parse('$baseUrl/calls/$callId/end?durationSeconds=$durationSeconds')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return CallSessionModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<CallSessionModel?> getCallSession(String callId) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/calls/$callId')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        return CallSessionModel.fromJson(jsonDecode(res.body));
      }
    } catch (_) {}
    return null;
  }

  static Future<CallSessionModel?> getActiveCallForUser() async {
    final me = currentUser;
    try {
      final res = await http.get(Uri.parse('$baseUrl/calls/active?userId=${me.id}')).timeout(const Duration(seconds: 3));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data != null && data['id'] != null) {
          return CallSessionModel.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<List<CallSessionModel>> getCallHistory({String? userId}) async {
    final uid = userId ?? currentUser.id;
    try {
      final res = await http.get(Uri.parse('$baseUrl/calls/history?userId=$uid')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => CallSessionModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Map<String, dynamic>>> getIceServers() async {
    final me = currentUser;
    try {
      final res = await http.get(Uri.parse('$baseUrl/calls/turn-credentials?userId=${me.id}')).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    return [
      {'urls': 'stun:stun.l.google.com:19302'}
    ];
  }

  // ==========================================
  // SAFETY & MEDIA
  // ==========================================

  static Future<Map<String, dynamic>> scanUrl(String url) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/safety/scan-link'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url}),
      ).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}

    int score = 0;
    List<String> warnings = [];
    if (url.contains('paypa1') || url.contains('fake') || url.contains('phish')) {
      score = 85;
      warnings.add('Detected deceptive brand impersonation pattern');
      warnings.add('Domain uses high-risk untrusted TLD');
    } else if (RegExp(r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}').hasMatch(url)) {
      score = 60;
      warnings.add('Numeric IP address used instead of reputable domain');
    } else {
      score = 5;
    }

    return {
      'url': url,
      'riskScore': score,
      'isSuspicious': score >= 40,
      'warnings': warnings,
    };
  }

  static final List<SafetyEventModel> _localSafetyEvents = [];

  static Future<List<SafetyEventModel>> getSafetyEvents() async {
    final me = currentUser;
    try {
      final res = await http.get(Uri.parse('$baseUrl/safety/events/${me.id}')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _localSafetyEvents.clear();
        _localSafetyEvents.addAll(list.map((e) => SafetyEventModel.fromJson(e)));
        return _localSafetyEvents;
      }
    } catch (_) {}
    return _localSafetyEvents;
  }

  static Future<void> terminateSession(String device) async {
    final me = currentUser;
    final newEvt = SafetyEventModel(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      eventType: 'SESSION_TERMINATED',
      severity: 'LOW',
      description: 'Remote kill switch activated. Session revoked for $device',
      ipAddress: '127.0.0.1',
      createdAt: DateTime.now(),
    );
    _localSafetyEvents.insert(0, newEvt);
    try {
      await http.post(
        Uri.parse('$baseUrl/safety/terminate-session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': me.id, 'deviceName': device}),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  static Future<void> triggerEmergencyCheckin(String status, String note) async {
    final me = currentUser;
    final newEvt = SafetyEventModel(
      id: 'evt_${DateTime.now().millisecondsSinceEpoch}',
      eventType: 'EMERGENCY_CHECKIN',
      severity: 'LOW',
      description: 'Emergency Check-in: [$status] $note',
      ipAddress: '127.0.0.1',
      createdAt: DateTime.now(),
    );
    _localSafetyEvents.insert(0, newEvt);
    try {
      await http.post(
        Uri.parse('$baseUrl/safety/emergency-checkin'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': me.id, 'status': status, 'note': note}),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  // ==========================================
  // PROFILE MANAGEMENT (EDIT EVERYTHING)
  // ==========================================

  static Future<UserModel> updateProfile({
    String? displayName,
    String? username,
    String? email,
    String? phone,
    String? bio,
    String? avatarUrl,
    String? statusMessage,
    String? themePreference,
    String? appIconPreference,
    String? softwareName,
    String? customLogoUrl,
    bool? isPrivate,
  }) async {
    final me = currentUser;
    final updated = UserModel(
      id: me.id,
      username: (username != null && username.isNotEmpty) ? username : me.username,
      displayName: (displayName != null && displayName.isNotEmpty) ? displayName : me.displayName,
      email: email ?? me.email,
      phone: phone ?? me.phone,
      bio: bio ?? me.bio,
      avatarUrl: avatarUrl ?? me.avatarUrl,
      statusMessage: statusMessage ?? me.statusMessage,
      safetyScore: me.safetyScore,
      isVerified: me.isVerified,
      isOnline: me.isOnline,
      isPrivate: isPrivate ?? me.isPrivate,
      appIconPreference: appIconPreference ?? me.appIconPreference,
      themePreference: themePreference ?? me.themePreference,
      softwareName: softwareName ?? me.softwareName,
      customLogoUrl: customLogoUrl ?? me.customLogoUrl,
    );

    currentUser = updated;
    if (appIconPreference != null && appIconPreference.isNotEmpty) {
      currentAppIconNotifier.value = appIconPreference;
    }
    if (themePreference != null && themePreference.isNotEmpty) {
      AppTheme.currentThemeNotifier.value = AppTheme.fromString(themePreference);
    }
    if (softwareName != null && softwareName.isNotEmpty) {
      softwareNameNotifier.value = softwareName;
    }
    if (customLogoUrl != null && customLogoUrl.isNotEmpty) {
      customLogoDataNotifier.value = customLogoUrl;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, jsonEncode(updated.toJson()));
    } catch (_) {}

    try {
      final res = await http.put(
        Uri.parse('$baseUrl/auth/profile/${me.id}'),
        headers: authHeaders,
        body: jsonEncode({
          if (displayName != null) 'displayName': displayName,
          if (username != null) 'username': username,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
          if (bio != null) 'bio': bio,
          if (avatarUrl != null) 'avatarUrl': avatarUrl,
          if (statusMessage != null) 'statusMessage': statusMessage,
          if (themePreference != null) 'themePreference': themePreference,
          if (appIconPreference != null) 'appIconPreference': appIconPreference,
          if (softwareName != null) 'softwareName': softwareName,
          if (customLogoUrl != null) 'customLogoUrl': customLogoUrl,
          if (isPrivate != null) 'isPrivate': isPrivate,
          if (isPrivate != null) 'private': isPrivate,
        }),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final serverUser = UserModel.fromJson(jsonDecode(res.body));
        currentUser = serverUser;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_keyUser, jsonEncode(serverUser.toJson()));
        } catch (_) {}
        return serverUser;
      }
    } catch (_) {}

    return updated;
  }

  /// Immediately converts the user account privacy mode (public or private) and persists it
  static Future<UserModel> setPrivacyMode(bool isPrivate) async {
    return await updateProfile(isPrivate: isPrivate);
  }

  // ==========================================
  // EMERGENCY CONTACT ACCOUNTS
  // ==========================================

  static final List<EmergencyContactModel> _localEmergencyContacts = [
    EmergencyContactModel(
      id: 'em_default_1',
      name: 'Security Ops Guild',
      accountOrEmail: 'secops@whisper.io',
      relationship: 'Security Team Account',
      phone: '+1 (555) 019-2834',
      notifyOnAlert: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  static Future<List<EmergencyContactModel>> getEmergencyContacts() async {
    return List<EmergencyContactModel>.from(_localEmergencyContacts);
  }

  static Future<EmergencyContactModel> addEmergencyContact({
    required String name,
    required String accountOrEmail,
    required String relationship,
    String? phone,
    bool notifyOnAlert = true,
  }) async {
    final contact = EmergencyContactModel(
      id: 'em_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      accountOrEmail: accountOrEmail,
      relationship: relationship,
      phone: phone,
      notifyOnAlert: notifyOnAlert,
      createdAt: DateTime.now(),
    );
    _localEmergencyContacts.add(contact);
    return contact;
  }

  static Future<void> removeEmergencyContact(String id) async {
    _localEmergencyContacts.removeWhere((c) => c.id == id);
  }
}

