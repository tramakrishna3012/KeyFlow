import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/features/auth/auth_modal.dart';

void main() {
  testWidgets('AuthModal displays tabbed Sign In and Create Account views', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AuthModal(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title and Tabs
    expect(find.text('KeyFlow Account'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Create Account'), findsOneWidget);

    // Verify Sign In fields
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);

    // Switch to Create Account Tab
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();

    // Verify Create Account fields
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Enable Face ID / Touch ID quick login'), findsOneWidget);
    expect(find.text('I agree to the Terms of Service and Privacy Policy'), findsOneWidget);
  });

  testWidgets('Create Account password strength meter dynamically reflects complexity', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AuthModal(initialIsSignUp: true),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final passwordField = find.widgetWithText(TextFormField, 'At least 8 characters');
    expect(passwordField, findsOneWidget);

    // Weak password (meets length >= 8 only)
    await tester.enterText(passwordField, 'weakpassword');
    await tester.pump();
    expect(find.text('Weak'), findsOneWidget);

    // Moderate password (length >= 8 + numbers)
    await tester.enterText(passwordField, 'weakpassword123');
    await tester.pump();
    expect(find.text('Moderate'), findsOneWidget);

    // Strong password (length >= 8 + upper/lower + numbers + special char)
    await tester.enterText(passwordField, 'StrongPassword123!');
    await tester.pump();
    expect(find.text('Strong'), findsOneWidget);
  });
}
