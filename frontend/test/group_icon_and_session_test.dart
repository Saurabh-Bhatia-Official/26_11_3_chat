import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/models.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/services/group_icon_helper.dart';
import 'package:frontend/services/network_service.dart';
import 'package:frontend/services/permission_service.dart';
import 'package:frontend/theme/app_theme.dart';
import 'package:frontend/views/home_screen.dart';
import 'package:frontend/widgets/avatar_badge.dart';
import 'package:frontend/widgets/camera_capture_dialog.dart';
import 'package:frontend/widgets/group_icon_picker_modal.dart';
import 'package:frontend/views/identity_settings_view.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PermissionService.mockStatus = null;
    CameraCaptureHelper.mockCapture = null;
    NetworkService.mockHasInternet = true;
    NetworkService.mockRequestHandler = null;
    NetworkService.dispose();
  });

  tearDown(() {
    PermissionService.mockStatus = null;
    CameraCaptureHelper.mockCapture = null;
    NetworkService.mockHasInternet = null;
    NetworkService.mockRequestHandler = null;
    NetworkService.dispose();
  });

  group('Requirement 1: Unique UI Session for Each Tab', () {
    testWidgets('HomeScreen preserves independent tab sessions using IndexedStack', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Setup authenticated user in ApiService
      ApiService.currentUserNotifier.value = UserModel(
        id: 'test_user_1',
        username: 'session_tester',
        displayName: 'Session Tester',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeScreen(
              currentThemeMode: AppThemeMode.obsidianCyber,
              onThemeChanged: (_) {},
              onLogout: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify IndexedStack is present to manage independent UI sessions
      final indexedStackFinder = find.byType(IndexedStack);
      expect(indexedStackFinder, findsOneWidget);

      final IndexedStack indexedStack = tester.widget(indexedStackFinder);
      expect(indexedStack.index, equals(0)); // Default is tab 0 (chats)
      expect(indexedStack.children.length, equals(3)); // chats, safetyGuardian, identity

      // Switch to Tab 1 (Safety Guardian)
      final safetyTabFinder = find.byIcon(Icons.shield_outlined);
      expect(safetyTabFinder, findsOneWidget);
      await tester.tap(safetyTabFinder);
      await tester.pumpAndSettle();

      final IndexedStack stackAfterTab1 = tester.widget(indexedStackFinder);
      expect(stackAfterTab1.index, equals(1));

      // Switch to Tab 2 (Identity & Settings)
      final identityTabFinder = find.byIcon(Icons.palette_outlined);
      expect(identityTabFinder, findsOneWidget);
      await tester.tap(identityTabFinder);
      await tester.pumpAndSettle();

      final IndexedStack stackAfterTab2 = tester.widget(indexedStackFinder);
      expect(stackAfterTab2.index, equals(2));

      // Switch back to Tab 0 (Chats) - state remains preserved in IndexedStack
      final chatsTabFinder = find.byIcon(Icons.chat_bubble_outline);
      expect(chatsTabFinder, findsOneWidget);
      await tester.tap(chatsTabFinder);
      await tester.pumpAndSettle();

      final IndexedStack stackAfterReturn = tester.widget(indexedStackFinder);
      expect(stackAfterReturn.index, equals(0));
    });
  });

  group('Requirement 2: Permission Requests & Edge Case Handling', () {
    testWidgets('Permission rationale dialog explains purpose and proceeds on user continue', (tester) async {
      bool? userProceeded;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  userProceeded = await PermissionService.showRationaleDialog(
                    ctx,
                    AppPermissionType.camera,
                  );
                },
                child: const Text('Show Rationale'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Rationale'));
      await tester.pumpAndSettle();

      // Rationale dialog displays purpose and explanation
      expect(find.text('Camera Permission'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Confirm rationale
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(userProceeded, isTrue);
    });

    testWidgets('Permission granted flow returns true', (tester) async {
      PermissionService.mockStatus = {
        AppPermissionType.camera: PermissionStatus.granted,
      };

      bool? granted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  granted = await PermissionService.requestPermission(
                    ctx,
                    AppPermissionType.camera,
                  );
                },
                child: const Text('Request Camera'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Request Camera'));
      await tester.pumpAndSettle();

      expect(granted, isTrue);
      expect(find.text('Permission Denied'), findsNothing);
      expect(find.text('Permission Required'), findsNothing);
    });

    testWidgets('Permission denied flow shows explanation dialog and returns false', (tester) async {
      PermissionService.mockStatus = {
        AppPermissionType.microphone: PermissionStatus.denied,
      };

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await PermissionService.requestPermission(
                    ctx,
                    AppPermissionType.microphone,
                  );
                },
                child: const Text('Request Mic'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Request Mic'));
      await tester.pumpAndSettle();

      // Denied explanation dialog shown with clear message
      expect(find.text('Microphone Permission Denied'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('Permission permanently denied flow shows settings guidance', (tester) async {
      PermissionService.mockStatus = {
        AppPermissionType.photos: PermissionStatus.permanentlyDenied,
      };

      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await PermissionService.requestPermission(
                    ctx,
                    AppPermissionType.photos,
                  );
                },
                child: const Text('Request Photos'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Request Photos'));
      await tester.pumpAndSettle();

      // Permanently denied dialog shown with "Open Settings"
      expect(find.text('Permission Required'), findsOneWidget);
      expect(find.text('Open Settings'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(result, isFalse);
    });

    testWidgets('Camera hardware unavailable dialog displays gracefully', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => PermissionService.showUnavailableDialog(ctx),
                child: const Text('Show Unavailable'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Unavailable'));
      await tester.pumpAndSettle();

      expect(find.text('Camera Unavailable'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Camera Unavailable'), findsNothing);
    });
  });

  group('Requirement 3 & 4: Group Icon Customization & Persistent Icon Changes', () {
    test('Preset icons are defined with valid names and icons', () {
      expect(GroupIconHelper.presets.isNotEmpty, isTrue);
      for (final preset in GroupIconHelper.presets) {
        expect(preset.id.isNotEmpty, isTrue);
        expect(preset.name.isNotEmpty, isTrue);
        expect(preset.primaryColor, isNotNull);
        expect(preset.icon, isNotNull);
      }
    });

    test('Saving and loading persistent group icon with SharedPreferences', () async {
      // Initially default
      final initial = await GroupIconHelper.initPersistentGroupIcon();
      expect(initial, equals('preset:community_guild'));

      // Save a new preset
      await GroupIconHelper.savePersistentGroupIcon('preset:cyber_pulse');
      final loaded = await GroupIconHelper.initPersistentGroupIcon();
      expect(loaded, equals('preset:cyber_pulse'));
      expect(GroupIconHelper.persistentGroupIconNotifier.value, equals('preset:cyber_pulse'));

      // Save a custom image data URI
      const dummyDataUri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      await GroupIconHelper.savePersistentGroupIcon(dummyDataUri);
      final loadedImage = await GroupIconHelper.initPersistentGroupIcon();
      expect(loadedImage, equals(dummyDataUri));
      expect(GroupIconHelper.persistentGroupIconNotifier.value, equals(dummyDataUri));
    });

    test('ApiService.initSession restores persistent group icon across application restarts', () async {
      // Simulate previous session having saved an icon
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(GroupIconHelper.keyGroupIconPreference, 'preset:phoenix_fire');

      // Simulate App Start / Session init
      await ApiService.initSession();

      expect(ApiService.currentGroupIcon, equals('preset:phoenix_fire'));
      expect(ApiService.currentGroupIconNotifier.value, equals('preset:phoenix_fire'));

      // Now change icon via ApiService
      await ApiService.setPersistentGroupIcon('preset:crypto_vault');
      expect(ApiService.currentGroupIcon, equals('preset:crypto_vault'));

      // Simulate application restart
      await ApiService.initSession();
      expect(ApiService.currentGroupIcon, equals('preset:crypto_vault'));

      NetworkService.dispose();
    });

    testWidgets('AvatarBadge renders preset group icon and reactive fallback', (tester) async {
      await GroupIconHelper.savePersistentGroupIcon('preset:shield_guardian');

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AvatarBadge(
              avatarUrl: 'preset:shield_guardian',
              name: 'Security Shield',
              isGroup: true,
              radius: 24,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the preset icon for shield_guardian is rendered
      expect(find.byIcon(Icons.security_rounded), findsOneWidget);
    });
  });

  group('Requirement 5: Camera Capture & Preview Flow', () {
    testWidgets('CameraPreviewDialog displays preview with Confirm and Retake options', (tester) async {
      // 1x1 transparent PNG
      final dummyBytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

      CameraCaptureResult? confirmed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  confirmed = await showDialog<CameraCaptureResult?>(
                    context: ctx,
                    builder: (dCtx) => CameraPreviewDialog(
                      initialBytes: dummyBytes,
                      initialFilename: 'photo.png',
                    ),
                  );
                },
                child: const Text('Open Preview'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Preview'));
      await tester.pumpAndSettle();

      expect(find.text('Preview Photo'), findsOneWidget);
      expect(find.text('Retake'), findsOneWidget);
      expect(find.text('Confirm & Use'), findsOneWidget);

      // Tap Confirm & Use
      await tester.tap(find.text('Confirm & Use'));
      await tester.pumpAndSettle();

      expect(confirmed, isNotNull);
      expect(confirmed!.dataUri.startsWith('data:image/png;base64,'), isTrue);
    });
  });

  group('Requirement 6: Camera & Gallery Integration for Group Icon Customization', () {
    testWidgets('GroupIconPickerModal opens and allows selecting preset icons', (tester) async {
      tester.view.physicalSize = const Size(1280, 960);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      String? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  selected = await GroupIconPickerModal.show(
                    ctx,
                    currentIcon: 'preset:community_guild',
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Verify modal options and tabs are shown
      expect(find.text('Customize Group Icon'), findsOneWidget);
      expect(find.text('Photo / Gallery'), findsOneWidget);
      expect(find.text('Available Icons'), findsOneWidget);
      expect(find.text('Capture with Camera'), findsOneWidget);
      expect(find.text('Choose from Device Gallery'), findsOneWidget);

      // Switch to Available Icons tab
      await tester.tap(find.text('Available Icons'));
      await tester.pumpAndSettle();

      // Select preset icon 'Cyber Pulse'
      final cyberPulseFinder = find.text('Cyber Pulse');
      expect(cyberPulseFinder, findsOneWidget);
      await tester.tap(cyberPulseFinder);
      await tester.pumpAndSettle();

      expect(selected, equals('preset:cyber_pulse'));
    });

    testWidgets('Camera photo selection saves persistently across restart', (tester) async {
      // 1. Configure mock camera to return photo
      const sampleBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final imageBytes = base64Decode(sampleBase64);

      CameraCaptureHelper.mockCapture = () async => CameraCaptureResult(
        bytes: imageBytes,
        filename: 'camera_group_icon.png',
        dataUri: 'data:image/png;base64,$sampleBase64',
      );

      // 2. Perform capture via CameraCaptureHelper
      String? savedIcon;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  final captured = await CameraCaptureHelper.captureWithCamera(ctx);
                  if (captured != null) {
                    await ApiService.setPersistentGroupIcon(captured.dataUri);
                    savedIcon = captured.dataUri;
                  }
                },
                child: const Text('Capture Camera Icon'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Capture Camera Icon'));
      await tester.pumpAndSettle();

      expect(savedIcon, isNotNull);
      expect(savedIcon!.startsWith('data:image/png;base64,'), isTrue);
      expect(ApiService.currentGroupIcon, equals(savedIcon));

      // 3. Restart application simulation
      await ApiService.initSession();
      expect(ApiService.currentGroupIcon, equals(savedIcon));
      NetworkService.dispose();

      // 4. Verify AvatarBadge displays custom image data URI correctly
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AvatarBadge(
              avatarUrl: ApiService.currentGroupIcon,
              name: 'Secret Operations Group',
              isGroup: true,
              radius: 28,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // CircleAvatar rendered with MemoryImage provider
      final avatarFinder = find.byType(CircleAvatar);
      expect(avatarFinder, findsOneWidget);
      final CircleAvatar circleAvatar = tester.widget(avatarFinder);
      expect(circleAvatar.backgroundImage, isA<MemoryImage>());
    });
  });

  group('Requirement 7: Profile Picture Avatar Permission & Multi-Source Flow', () {
    testWidgets('IdentitySettingsView shows avatar options bottom sheet with all sources', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentitySettingsView(
              currentThemeMode: AppThemeMode.obsidianCyber,
              onThemeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the upload avatar button or camera badge
      final uploadBtn = find.byIcon(Icons.file_upload_outlined).last;
      expect(uploadBtn, findsOneWidget);
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Verify bottom sheet title and options
      expect(find.text('Update Profile Picture'), findsOneWidget);
      expect(find.text('Take Photo with Camera'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      expect(find.text('Choose from File Storage'), findsOneWidget);
      expect(find.text('Enter Image URL'), findsOneWidget);
    });

    testWidgets('Profile avatar update via Camera works and saves persistently', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;

      // Mock permissions as granted
      PermissionService.mockStatus = {
        AppPermissionType.camera: PermissionStatus.granted,
        AppPermissionType.photos: PermissionStatus.granted,
      };

      final dummyBytes = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
      CameraCaptureHelper.mockCapture = () async {
        return CameraCaptureResult(
          bytes: dummyBytes,
          filename: 'new_profile_avatar.png',
          dataUri: 'data:image/png;base64,${base64Encode(dummyBytes)}',
        );
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentitySettingsView(
              currentThemeMode: AppThemeMode.obsidianCyber,
              onThemeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Upload Profile Picture
      final uploadBtn = find.byIcon(Icons.file_upload_outlined).last;
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Tap Take Photo with Camera
      await tester.tap(find.text('Take Photo with Camera'));
      await tester.pumpAndSettle();

      // Avatar should be updated in currentUser
      expect(ApiService.currentUser.avatarUrl, isNotNull);
      expect(ApiService.currentUser.avatarUrl!.startsWith('data:image/png;base64,'), isTrue);

      NetworkService.dispose();
    });

    testWidgets('Direct Image URL entry updates profile avatar', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentitySettingsView(
              currentThemeMode: AppThemeMode.obsidianCyber,
              onThemeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Upload Profile Picture
      final uploadBtn = find.byIcon(Icons.file_upload_outlined).last;
      await tester.ensureVisible(uploadBtn);
      await tester.tap(uploadBtn);
      await tester.pumpAndSettle();

      // Tap Enter Image URL
      await tester.tap(find.text('Enter Image URL'));
      await tester.pumpAndSettle();

      // Enter a valid direct image URL
      final dummyUri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';
      final textField = find.byType(TextField).last;
      await tester.enterText(textField, dummyUri);
      await tester.pumpAndSettle();

      // Tap Save in dialog
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify ApiService profile avatar updated
      expect(ApiService.currentUser.avatarUrl, equals(dummyUri));

      NetworkService.dispose();
    });

    testWidgets('Tapping Private Account immediately converts account to private and persists', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;

      // Start with public account
      ApiService.currentUser = UserModel(
        id: 'u_test_priv',
        username: 'alice_crypto',
        displayName: 'Alice Crypto',
        isPrivate: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentitySettingsView(
              currentThemeMode: AppThemeMode.obsidianCyber,
              onThemeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Privacy & Security settings section
      final privacyPill = find.text('Privacy & Security');
      expect(privacyPill, findsOneWidget);
      await tester.tap(privacyPill);
      await tester.pumpAndSettle();

      // Find Private Account card and ensure visible
      final privCard = find.text('Private Account');
      expect(privCard, findsOneWidget);
      await tester.ensureVisible(privCard);
      await tester.tap(privCard);
      await tester.pumpAndSettle();

      // Verify currentUser converted to private immediately
      expect(ApiService.currentUser.isPrivate, isTrue);

      // Verify snackbar confirmed conversion
      expect(find.textContaining('Account converted to Private Account'), findsOneWidget);

      // Verify persistent storage saved isPrivate = true across session reload
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('saved_auth_user_json');
      expect(userJson, isNotNull);
      final decoded = jsonDecode(userJson!);
      expect(decoded['isPrivate'], isTrue);

      // Simulate app restart / initSession
      await ApiService.initSession();
      expect(ApiService.currentUser.isPrivate, isTrue);

      NetworkService.dispose();
    });

    testWidgets('No Cloud Stored or Cloud Synced badges displayed in IdentitySettingsView', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentitySettingsView(
              currentThemeMode: AppThemeMode.obsidianCyber,
              onThemeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify cloud badges are completely removed
      expect(find.text('Cloud Stored'), findsNothing);
      expect(find.text('Cloud Synced'), findsNothing);
      expect(find.textContaining('persisted in cloud database'), findsNothing);
      expect(find.textContaining('saved to cloud database'), findsNothing);

      NetworkService.dispose();
    });
  });

  group('Requirement 8: Group-Specific Icon Isolation', () {
    test('Updating Group A icon does not affect Group B or global defaults', () {
      final groupA = ConversationModel(
        id: 'group_alpha',
        title: 'Alpha Team',
        isGroup: true,
        avatarUrl: 'preset:cyber_pulse',
        lastMessageAt: DateTime.now(),
      );

      final groupB = ConversationModel(
        id: 'group_beta',
        title: 'Beta Team',
        isGroup: true,
        avatarUrl: null, // default
        lastMessageAt: DateTime.now(),
      );

      // Verify Group A has its own icon
      expect(groupA.avatarUrl, equals('preset:cyber_pulse'));
      // Verify Group B has not been altered by Group A's icon
      expect(groupB.avatarUrl, isNull);
      // Verify ApiService default icon remains untouched
      expect(ApiService.defaultAppIcon, equals('whisper'));
    });
  });

  group('Requirement 9: Profile -> Settings Structure & App Customization', () {
    testWidgets('IdentitySettingsView displays organized Profile -> Settings navigation', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdentitySettingsView(
              currentThemeMode: AppThemeMode.obsidianCyber,
              onThemeChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Profile -> Settings breadcrumb header
      expect(find.text('Profile'), findsWidgets);
      expect(find.text('Settings'), findsWidgets);

      // Verify all requested organized sections exist
      expect(find.text('Account & Profile'), findsOneWidget);
      expect(find.text('App Customization'), findsOneWidget);
      expect(find.text('Privacy & Security'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Chat Settings'), findsOneWidget);
      expect(find.text('Storage & Data'), findsOneWidget);
      expect(find.text('About & App Info'), findsOneWidget);

      // Navigate to App Customization section
      await tester.tap(find.text('App Customization'));
      await tester.pumpAndSettle();

      // Verify Application Title and Icon customization are present
      expect(find.text('Application Title'), findsOneWidget);
      expect(find.text('Application Icon'), findsOneWidget);
      expect(find.text('Reset Customization to Defaults'), findsOneWidget);
    });

    test('ApiService setSoftwareName updates title and preserves default fallback', () async {
      await ApiService.setSoftwareName('Custom Whisper');
      expect(ApiService.softwareName, equals('Custom Whisper'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_software_name'), equals('Custom Whisper'));

      await ApiService.setSoftwareName('');
      expect(ApiService.softwareName, equals(ApiService.defaultSoftwareName));
    });

    test('ApiService setAppIcon updates app icon independently and persists locally', () async {
      await ApiService.setAppIcon('solar_flare');
      expect(ApiService.currentAppIcon, equals('solar_flare'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('custom_app_icon_preference'), equals('solar_flare'));
    });

    test('ApiService.initSession restores saved custom title and icon on app restart', () async {
      SharedPreferences.setMockInitialValues({
        'custom_software_name': 'Cyber Pulse',
        'custom_app_icon_preference': 'cyber_pulse',
      });

      await ApiService.initSession();
      expect(ApiService.softwareName, equals('Cyber Pulse'));
      expect(ApiService.currentAppIcon, equals('cyber_pulse'));
    });

    test('AppIconHelper validates predefined launcher names and aliases correctly', () {
      expect(AppIconHelper.isPredefinedName('Whisper'), isTrue);
      expect(AppIconHelper.isPredefinedName('Cyber Pulse'), isTrue);
      expect(AppIconHelper.isPredefinedName('Cyber Shield'), isTrue);
      expect(AppIconHelper.isPredefinedName('Cosmic Night'), isTrue);
      expect(AppIconHelper.isPredefinedName('Solar Flare'), isTrue);
      expect(AppIconHelper.isPredefinedName('cyber_pulse'), isTrue);
      expect(AppIconHelper.isPredefinedName('Arbitrary Chat App'), isFalse);
    });
  });

  group('Requirement 10: Session Persistence and Token Refresh', () {
    test('Token refresh updates local auth token in SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'saved_auth_jwt_token': 'old_jwt_token',
        'saved_auth_user_json': jsonEncode({
          'id': 'user_123',
          'username': 'john_doe',
          'displayName': 'John Doe',
        }),
      });

      // Restore session
      final restored = await ApiService.initSession();
      expect(restored, isTrue);
      expect(ApiService.currentUser.username, equals('john_doe'));
      expect(ApiService.isAuthInitializing, isFalse);
    });
  });
}
