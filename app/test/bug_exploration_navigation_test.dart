import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keyflow_app/core/router/supabase_auth_notifier.dart';
import 'package:keyflow_app/main.dart';

/// **Validates: Requirements 1.1, 1.7, 2.1, 2.2**
///
/// Responsive Navigation Test Suite
/// Validates that:
/// - Screen widths > 600px render [NavigationRail] (Desktop / Tablet)
/// - Screen widths <= 600px render [BottomNavigationBar] (Mobile)
void main() {
  setUp(() {
    SupabaseAuthNotifier.debugAuthenticatedOverride = true;
  });

  tearDown(() {
    SupabaseAuthNotifier.debugAuthenticatedOverride = null;
  });

  group('Responsive Navigation Validation: Desktop & Mobile', () {
    // Test case 1: Windows platform with desktop width
    testWidgets(
      'Windows platform with 1200px width should use NavigationRail, not BottomNavigationBar',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const ProviderScope(child: KeyFlowApp()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byType(NavigationRail),
          findsOneWidget,
          reason: 'Windows with 1200px width must show NavigationRail.',
        );
        expect(
          find.byType(BottomNavigationBar),
          findsNothing,
          reason:
              'Windows with 1200px width must not show BottomNavigationBar.',
        );
      },
    );

    // Test case 2: macOS platform with desktop width
    testWidgets(
      'macOS platform with 1400px width should use NavigationRail, not BottomNavigationBar',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const ProviderScope(child: KeyFlowApp()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byType(NavigationRail),
          findsOneWidget,
          reason: 'macOS with 1400px width must show NavigationRail.',
        );
        expect(
          find.byType(BottomNavigationBar),
          findsNothing,
          reason: 'macOS with 1400px width must not show BottomNavigationBar.',
        );
      },
    );

    // Test case 3: Web platform with desktop width
    testWidgets(
      'Web platform with 800px width should use NavigationRail, not BottomNavigationBar',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const ProviderScope(child: KeyFlowApp()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byType(NavigationRail),
          findsOneWidget,
          reason: 'Web with 800px width must show NavigationRail.',
        );
        expect(
          find.byType(BottomNavigationBar),
          findsNothing,
          reason: 'Web with 800px width must not show BottomNavigationBar.',
        );
      },
    );

    // Test case 4: Mobile width preservation check (should use BottomNavigationBar)
    testWidgets('Mobile width (375px) should use BottomNavigationBar', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: KeyFlowApp()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byType(BottomNavigationBar),
        findsOneWidget,
        reason: 'Mobile width (375px) must show BottomNavigationBar.',
      );
      expect(
        find.byType(NavigationRail),
        findsNothing,
        reason: 'Mobile width (375px) must not show NavigationRail.',
      );
    });

    // Test case 5: Small phone width check (320px)
    testWidgets(
      'Small phone width (320px) should render BottomNavigationBar without clipping',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const ProviderScope(child: KeyFlowApp()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byType(BottomNavigationBar),
          findsOneWidget,
          reason: 'Small phone width (320px) must show BottomNavigationBar.',
        );
      },
    );

    // Test case 6: Edge case - exactly 600px width (borderline case)
    testWidgets('Exactly 600px width uses BottomNavigationBar', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(const ProviderScope(child: KeyFlowApp()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('Property-Based Validation: Screen Width > 600px', () {
    const desktopWidths = [601, 800, 1024, 1200, 1440, 1920];

    for (final width in desktopWidths) {
      testWidgets('Width $width px renders NavigationRail for wide screen', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = Size(width.toDouble(), 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(const ProviderScope(child: KeyFlowApp()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(
          find.byType(NavigationRail),
          findsOneWidget,
          reason:
              'Screen width $width px (> 600px) must render NavigationRail.',
        );
        expect(
          find.byType(BottomNavigationBar),
          findsNothing,
          reason:
              'Screen width $width px (> 600px) must not render BottomNavigationBar.',
        );
      });
    }
  });
}
