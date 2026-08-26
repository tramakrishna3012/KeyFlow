import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/data/models/user_model.dart';
import 'package:keyflow_app/data/providers.dart';
import 'package:keyflow_app/features/profile/profile_modal.dart';

void main() {
  testWidgets('ProfileModal displays user profile, security with Encrypted Cloud Sync, and sessions', (tester) async {
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
        overrides: [
          currentUserProvider.overrideWithValue(testUser),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProfileModal(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify User Header
    expect(find.text('User Profile & Security'), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('alex.morgan@keyflow.dev'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Re-verification required if email address is updated.'), findsOneWidget);

    // 2. Verify Security Section & Encrypted Cloud Sync label
    expect(find.text('SECURITY & CLOUD SYNC'), findsOneWidget);
    expect(find.text('Two-Factor Authentication (2FA)'), findsOneWidget);
    expect(find.text('Encrypted Cloud Sync'), findsOneWidget);
    expect(find.text('Sync typing history encrypted at rest via AES-256-GCM'), findsOneWidget);

    // 3. Verify Active Sessions & Account Actions
    expect(find.text('ACTIVE SESSIONS'), findsOneWidget);

    // Scroll to Account Actions to ensure visibility
    await tester.scrollUntilVisible(find.text('ACCOUNT ACTIONS'), 200);
    expect(find.text('ACCOUNT ACTIONS'), findsOneWidget);
    expect(find.text('Switch Account'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
  });
}
