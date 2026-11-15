import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/models/user_model.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/profile/profile_modal.dart';

void main() {
  // ProfileModal's session list is loaded via AuthService, which now reads
  // the real device name/OS from device_info_plus instead of a hardcoded
  // string. Mock its platform channel so that read resolves immediately in
  // this widget test instead of leaving a real, unmockable platform-channel
  // call pending (which pumpAndSettle can never settle on its own).
  const deviceInfoChannel = MethodChannel(
    'dev.fluttercommunity.plus/device_info',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceInfoChannel, (call) async {
          if (call.method == 'getDeviceInfo') {
            return {
              'version': <String, dynamic>{
                'codename': 'REL',
                'incremental': '1',
                'previewSdkInt': 0,
                'release': '15',
                'sdkInt': 34,
              },
              'board': 'board',
              'bootloader': 'bootloader',
              'brand': 'brand',
              'device': 'device',
              'display': 'display',
              'fingerprint': 'fingerprint',
              'hardware': 'hardware',
              'host': 'host',
              'id': 'id',
              'manufacturer': 'manufacturer',
              'model': 'Test Device',
              'product': 'product',
              'name': 'name',
              'supported32BitAbis': <String>[],
              'supported64BitAbis': <String>[],
              'supportedAbis': <String>[],
              'tags': 'tags',
              'type': 'type',
              'isPhysicalDevice': true,
              'freeDiskSize': 0,
              'totalDiskSize': 0,
              'systemFeatures': <String>[],
              'isLowRamDevice': false,
              'physicalRamSize': 0,
              'availableRamSize': 0,
            };
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceInfoChannel, null);
  });

  testWidgets(
    'ProfileModal displays user profile, security with Encrypted Cloud Sync, and sessions',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const testUser = UserModel(
        id: 'test_user_1',
        email: 'alex.morgan@keyflow.dev',
        fullName: 'Alex Morgan',
        role: 'admin',
        mfaEnabled: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserProvider.overrideWithValue(testUser)],
          child: const MaterialApp(home: Scaffold(body: ProfileModal())),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify User Header
      expect(find.text('User Profile & Security'), findsOneWidget);
      expect(find.text('Alex Morgan'), findsOneWidget);
      expect(find.text('alex.morgan@keyflow.dev'), findsOneWidget);
      expect(find.text('Administrator'), findsOneWidget);
      expect(
        find.text('Re-verification required if email address is updated.'),
        findsOneWidget,
      );

      // 2. Verify Security Section & Encrypted Cloud Sync label
      expect(find.text('SECURITY & CLOUD SYNC'), findsOneWidget);
      expect(find.text('Two-Factor Authentication (2FA)'), findsOneWidget);
      expect(find.text('Encrypted Cloud Sync'), findsOneWidget);
      expect(
        find.text('Sync typing history encrypted at rest via AES-256-GCM'),
        findsOneWidget,
      );

      // 3. Verify Active Sessions & Account Actions
      expect(find.text('ACTIVE SESSIONS'), findsOneWidget);

      // Scroll to Account Actions to ensure visibility
      await tester.scrollUntilVisible(find.text('ACCOUNT ACTIONS'), 200);
      expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);
      expect(find.text('Switch Account'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    },
  );
}
