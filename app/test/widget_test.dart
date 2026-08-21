import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keyflow_app/features/auth/auth_screen.dart';
import 'package:keyflow_app/main.dart';

void main() {
  testWidgets('KeyFlowApp renders without crashing', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KeyFlowApp()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Unauthenticated startup redirects to AuthScreen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KeyFlowApp()));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('KeyFlow'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
